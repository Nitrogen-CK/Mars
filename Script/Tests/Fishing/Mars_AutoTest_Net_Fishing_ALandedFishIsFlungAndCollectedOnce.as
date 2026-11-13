// The server seats the subject (the station's state machine engages the spot and runs the landing) and casts directly; once
// Waiting it forces a bite and, once Bite, strikes and holds the reel; once Reeling it forces the landing; once its tally
// counts one and its spot reads Idle it reports the catch point. The client raised OnLanded once, its fling rose to 1, it raised OnCollected
// once and its tally counts one. On both machines exactly one world item lies within 300 cm of the catch point.
// Surface: Ck.Fishing.Net.AS_Fishing_ALandedFishIsFlungAndCollectedOnce
class UCk_AutoTest_Net_Fishing_ALandedFishIsFlungAndCollectedOnce : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 464000.0;
    private const float64 k_NearCm = 300.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
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
        Await_Phase(EMars_Fishing_Phase::Reeling, n"OnServerReeling");
    }

    UFUNCTION()
    private void OnServerReeling(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_ForceLand(FMars_Request_Fishing_ForceLand());
        WaitUntil(n"Is_ServerCollected", n"OnServerCollected", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCollected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fishing.Get_Tally() == 1 && _Fishing.Get_Phase() == EMars_Fishing_Phase::Idle);
    }

    UFUNCTION()
    private void OnServerCollected(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Point(_Fishing.Get_CatchWorld());
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Items = Count_WorldItemsNear(Get_ReportedPoint(), k_NearCm);
        Assert_Equals_Int(Items, 1, f"exactly one world item lies near the server's catch point ({Items})");
        End_FishingServer(f"items={Items} {Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        auto MaxFling = 0.0f;
        for (const auto& Sample : _Samples)
        { MaxFling = Math::Max(MaxFling, Sample.FlingAlpha); }

        const auto Items = Count_WorldItemsNear(Get_ReportedPoint(), k_NearCm);
        Log_Minigame(f"maxFling={MaxFling} items={Items} {Describe_Record()} {Describe_Fishing()}");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnLanded), 1, f"the client raised OnLanded once ({Describe_Record()})");
        Assert_True(MaxFling >= 1.0f, f"the client's fling rose to 1 ({MaxFling})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnCollected), 1, f"the client raised OnCollected once ({Describe_Record()})");
        Assert_Equals_Int(_Fishing.Get_Tally(), 1, f"the client's tally counts one ({Describe_Fishing()})");
        Assert_Equals_Int(Items, 1, f"exactly one world item lies near the client's catch point ({Items})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
