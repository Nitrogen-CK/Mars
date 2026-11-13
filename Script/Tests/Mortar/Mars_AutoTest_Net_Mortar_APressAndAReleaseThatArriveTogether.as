// One hit cracks the batch and the grind takes 2 s. The server seats the subject and strikes a hit directly; once the
// phase is Grind it reports step 1, holds 1 s, reports step 2, holds 3 s and reports step 3. As step 1 arrives the client
// presses and releases through the station's helper in one frame; as step 2 arrives it releases and presses in one frame.
// The server at step 2: its pestle rests and its grind is under 0.2 (the tap ended released); at step 3 the batch is Done
// (the press after the release held).
// Surface: Ck.Mortar.Net.AS_Mortar_APressAndAReleaseThatArriveTogether
class UCk_AutoTest_Net_Mortar_APressAndAReleaseThatArriveTogether : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 446000.0;
    private const float32 k_TapGrindCeiling = 0.2f;

    protected void Configure_Spec(FMars_Mortar_Spec& InOutSpec) override
    {
        InOutSpec.CrushesNeeded = 1;
        InOutSpec.GrindSeconds = 2.0f;
    }

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
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hit_Directly();
        WaitUntil(n"Is_ServerGrindPhase", n"OnServerGrindPhase", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGrindPhase(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Grind);
    }

    UFUNCTION()
    private void OnServerGrindPhase(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        WaitSeconds(1.0f, n"OnServerTapHeld");
    }

    UFUNCTION()
    private void OnServerTapHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Progress = _Mortar.Get_Batch().GrindProgress;
        Assert_True(_Mortar.Get_Pestle() == EMars_Mortar_Pestle::Resting, f"the server's pestle rests after the tap ({Describe_Mortar()})");
        Assert_True(Progress < k_TapGrindCeiling, f"the server's grind is under {k_TapGrindCeiling} after the tap ({Progress})");
        Log_Minigame(f"at step 2: {Describe_Mortar()}");
        Report_Step(FMars_TESTONLY_NetMinigameStep(2));
        WaitSeconds(3.0f, n"OnServerHoldHeld");
    }

    UFUNCTION()
    private void OnServerHoldHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Done, f"the server's batch is Done after the held press ({Describe_Mortar()})");
        Report_Step(FMars_TESTONLY_NetMinigameStep(3));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Log_Minigame(f"tap frame={utils_time::Get_FrameCounter()}");
            Pestle_For(EMars_Mortar_PestleVerb::Press, _Mortar.Get_SweepSeconds());
            Pestle_For(EMars_Mortar_PestleVerb::Release, 0.0f);
            Await_Step(2, EMars_TESTONLY_NetMinigameArrival::Immediate);
            return;
        }

        if (InStep == 2)
        {
            Log_Minigame(f"release and press frame={utils_time::Get_FrameCounter()}");
            Pestle_For(EMars_Mortar_PestleVerb::Release, 0.0f);
            Pestle_For(EMars_Mortar_PestleVerb::Press, _Mortar.Get_SweepSeconds());
            Await_Step(3, EMars_TESTONLY_NetMinigameArrival::Settled);
            return;
        }

        Assert_True(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Done, f"the client's batch is Done ({Describe_Mortar()})");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
