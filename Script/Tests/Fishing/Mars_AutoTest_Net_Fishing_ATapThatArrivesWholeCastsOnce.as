// The server seats the subject and applies one remote sample whose Primary press serial is one more and whose hold is
// released (a tap that arrived whole); 2 s later it reports step 1. Once Waiting it forces a bite; once Bite, in one frame,
// it releases the subject from the station and applies a remote Primary press; 1.5 s later it reports step 2. After step 1
// both machines' ledgers count one cast. After step 2, on both machines, the spot reads Idle and not engaged with no line
// out, and the station is free.
// Surface: Ck.Fishing.Net.AS_Fishing_ATapThatArrivesWholeCastsOnce
class UCk_AutoTest_Net_Fishing_ATapThatArrivesWholeCastsOnce : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 467000.0;
    private const float32 k_AfterTapSeconds = 2.0f;
    private const float32 k_AfterLeaveSeconds = 1.5f;

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
        Press_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitSeconds(k_AfterTapSeconds, n"OnServerTapped");
    }

    UFUNCTION()
    private void OnServerTapped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Casts = _Fishing.Get_Ledger().CastSerial;
        Assert_Equals_Int(Casts, 1, f"the server cast once on the tap ({Describe_Fishing()})");
        auto Step = FMars_TESTONLY_NetMinigameStep(1);
        Step.Count = Casts;
        Report_Step(Step);
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

    UFUNCTION()
    private void OnServerBite(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Release_Subject();
        Press_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitSeconds(k_AfterLeaveSeconds, n"OnServerLeft");
    }

    UFUNCTION()
    private void OnServerLeft(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(2));
        Assert_Left("server");
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    private void Assert_Left(FString InMachine)
    {
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, f"the {InMachine}'s spot reads Idle ({Describe_Fishing()})");
        Assert_True(_Fishing.Get_IsEngaged() == false, f"the {InMachine}'s spot is not engaged ({Describe_Fishing()})");
        Assert_True(_Fishing.Get_HasLineOut() == false, f"the {InMachine} has no line out ({Describe_Fishing()})");
        Assert_True(Get_IsStationFree(), f"the {InMachine}'s station is free");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Assert_Equals_Int(_Fishing.Get_Ledger().CastSerial, 1, f"the client's ledger counts one cast ({Describe_Fishing()})");
            Await_Step(2, EMars_TESTONLY_NetMinigameArrival::Settled);
            return;
        }

        Assert_Left("client");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
