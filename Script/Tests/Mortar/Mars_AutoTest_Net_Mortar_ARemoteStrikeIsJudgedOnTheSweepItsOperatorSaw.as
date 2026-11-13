// The timing window's pass is 6 s and its half width 0.02. The server seats the subject. Once the client reads the subject
// operating and its own window's centre stands more than 0.3 from the marker, it presses through the station's helper
// with a hit's sweep and releases. The server's strike lands a hit although its own window was off the marker as it
// started; it reports once landed.
// Surface: Ck.Mortar.Net.AS_Mortar_ARemoteStrikeIsJudgedOnTheSweepItsOperatorSaw
class UCk_AutoTest_Net_Mortar_ARemoteStrikeIsJudgedOnTheSweepItsOperatorSaw : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 444000.0;
    private const float32 k_OffMarker = 0.3f;

    protected void Configure_Spec(FMars_Mortar_Spec& InOutSpec) override
    {
        InOutSpec.Timing.SweepSeconds = 6.0f;
        InOutSpec.Timing.WindowHalfWidth = 0.02f;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientReadyToStrike", n"OnClientReadyToStrike", k_SlowPolls); }
    }

    protected void On_ServerStationReady() override
    {
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerLanded", n"OnServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Landings.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Landings[0] == EMars_Mortar_Strike::Hit, f"the server's strike landed a hit ({Describe_Record()})");
        Assert_True(_OnMarkerAtStart.Num() == 1 && _OnMarkerAtStart[0] == false, f"the server's own window was off the marker as the strike started ({Describe_Record()})");
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    UFUNCTION()
    private void Is_ClientReadyToStrike(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindStation() && Get_IsSubjectOperating() && _Mortar.Get_IsEngaged() && Get_WindowOffMarker() > k_OffMarker);
    }

    UFUNCTION()
    private void OnClientReadyToStrike(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Minigame(f"sends frame={utils_time::Get_FrameCounter()} offMarker={Get_WindowOffMarker()}");
        Pestle_For(EMars_Mortar_PestleVerb::Press, Get_HitSweep());
        Pestle_For(EMars_Mortar_PestleVerb::Release, 0.0f);
        Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Assert_True(_Landings.Num() == 1 && _Landings[0] == EMars_Mortar_Strike::Hit, f"the client's copy landed one hit ({Describe_Record()})");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
