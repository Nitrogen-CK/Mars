// The server reports step 1 with the station free, waits 1.5 s, seats the subject and releases it; once the station is
// free again it reports step 2, waits 1.5 s and reports step 3. As step 1 and as step 2 arrive the client presses through
// the station's helper with a hit's sweep. At the end the server's mortar started no strike, its pestle is released, and
// no ensure fired.
// Surface: Ck.Mortar.Net.AS_Mortar_APestleFromSomeoneNotOperatingIsRefused
class UCk_AutoTest_Net_Mortar_APestleFromSomeoneNotOperatingIsRefused : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 447000.0;
    private const float32 k_WaitSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Immediate); }
    }

    protected void On_ServerStationReady() override
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        WaitSeconds(k_WaitSeconds, n"OnServerWaitedFree");
    }

    UFUNCTION()
    private void OnServerWaitedFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Release_Subject();
        WaitUntil(n"Is_ServerFree", n"OnServerFree", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFree() && _Mortar.Get_IsEngaged() == false);
    }

    UFUNCTION()
    private void OnServerFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(2));
        WaitSeconds(k_WaitSeconds, n"OnServerWaitedAfter");
    }

    UFUNCTION()
    private void OnServerWaitedAfter(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Press = _Mortar.Get_Fragment(FMars_Fragment_Mortar).Pestle.Press;
        Assert_Equals_Int(_Mortar.Get_Ledger().StrikeSerial, 0, f"the server's mortar started no strike ({Describe_Mortar()})");
        Assert_True(Press == EMars_Mortar_Press::Released, "the server's pestle is released");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::StrikeStarted), 0, f"the server raised no strike ({Describe_Record()})");
        Report_Step(FMars_TESTONLY_NetMinigameStep(3));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep < 3)
        {
            Log_Minigame(f"press at step {InStep} operating={Get_IsSubjectOperating()}");
            Pestle_For(EMars_Mortar_PestleVerb::Press, Get_HitSweep());
            Await_Step(InStep + 1, InStep == 1 ? EMars_TESTONLY_NetMinigameArrival::Immediate : EMars_TESTONLY_NetMinigameArrival::Settled);
            return;
        }

        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::StrikeStarted), 0, f"the client raised no strike ({Describe_Record()})");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
