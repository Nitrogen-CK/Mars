// With a line that snaps within a second of holding, the server seats the subject and casts directly; once Waiting it
// forces a bite and, once Bite, strikes and holds the reel; once its spot has read Snapped and then Idle again (the station's beat
// re-rigged it) it reports. The client's phase read Snapped, then Idle, and it has no line out.
// Surface: Ck.Fishing.Net.AS_Fishing_ASnappedLineIsReRiggedOnBothMachines
class UCk_AutoTest_Net_Fishing_ASnappedLineIsReRiggedOnBothMachines : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 465000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    // From the hook's 0.3 the tension reaches 1.0 in 0.7 s of holding; the line is far from running out by then.
    protected void Configure_Spec(FMars_Fishing_Spec& InOutSpec) override
    {
        InOutSpec.Reel.TensionGainPerS = 1.0f;
        InOutSpec.Reel.ReelSpeedCmPerS = 100.0f;
    }

    protected void On_ServerStationReady() override
    {
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_Engaged(n"OnServerEngaged");
    }

    UFUNCTION()
    private void OnServerEngaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
        Await_Phase(EMars_Fishing_Phase::Waiting, n"OnServerWaiting");
    }

    // The station's phase machine steps one phase a poll: a bite forced in the frame the bait lands would leave it in
    // Casting, so it is given a few frames to read Waiting.
    UFUNCTION()
    private void OnServerWaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_SmSettleFrames, n"OnServerWaitingSettled");
    }

    UFUNCTION()
    private void OnServerWaitingSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_ForceBite(FMars_Request_Fishing_ForceBite());
        Await_Phase(EMars_Fishing_Phase::Bite, n"OnServerBite");
    }

    // As with Waiting: the strike waits until the station's phase machine has read the bite.
    UFUNCTION()
    private void OnServerBite(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_SmSettleFrames, n"OnServerBiteSettled");
    }

    UFUNCTION()
    private void OnServerBiteSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_Hook(FMars_Request_Fishing_Hook());
        _Fishing.Request_ReelHold(FMars_Request_Fishing_ReelHold());
        Await_Phase(EMars_Fishing_Phase::Snapped, n"OnServerSnapped");
    }

    UFUNCTION()
    private void OnServerSnapped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_Phase(EMars_Fishing_Phase::Idle, n"OnServerIdle");
    }

    UFUNCTION()
    private void OnServerIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto SnappedAt = Find_Phase(EMars_Fishing_Phase::Snapped, 0);
        Log_Minigame(f"{Describe_Record()} {Describe_Fishing()}");
        Assert_True(SnappedAt >= 0, f"the client's phase read Snapped ({Describe_Record()})");
        Assert_True(Find_Phase(EMars_Fishing_Phase::Idle, SnappedAt + 1) > SnappedAt, f"the client's phase read Idle after Snapped ({Describe_Record()})");
        Assert_True(_Fishing.Get_HasLineOut() == false, f"the client has no line out ({Describe_Fishing()})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
