// A client fishes. The server reports step 1 and from then on only answers: once the subject operates it seeds its stream,
// applies a remote look and a remote hold of Primary for 0.4 s and its let-go (the reader charges and casts); once Waiting
// it forces a bite; once Bite it applies a remote Primary press, held (the reader strikes and reels); once its tally counts
// one it lets go and reports step 2 with the catch point; once the station is free it reports step 3. As step 1 arrives
// the client reserves the station through the station's act; as step 2 arrives it leaves through the station's act. At
// step 3 both machines' tallies count one and their spots read Idle, exactly one world item lies within 300 cm of the
// catch point on both, and the client's record holds OnCast, OnBite, OnBiteEnded Hooked, OnLanded and OnCollected, once
// each, in that order.
// Surface: Ck.Fishing.Net.AS_Fishing_AClientFishesEndToEnd
class UCk_AutoTest_Net_Fishing_AClientFishesEndToEnd : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 29.0f;

    private const float64 k_X = 471000.0;
    private const float32 k_ChargeSeconds = 0.4f;
    private const float64 k_NearCm = 300.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Immediate); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerStationReady() override
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        Await_OperatingThenSeed(n"OnServerOperated");
    }

    UFUNCTION()
    private void OnServerOperated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Minigame("operated");
        Look_Remote(FVector(5.0, 0.0, 0.0), 0.1f);
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitSeconds(k_ChargeSeconds, n"OnServerCharged");
    }

    UFUNCTION()
    private void OnServerCharged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        LetGo_Remote(GameplayTags::Mars_Intent_Interact_Primary);
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
        Log_Minigame("waiting");
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
        Log_Minigame("bite");
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitUntil(n"Is_ServerTallied", n"OnServerTallied", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTallied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fishing.Get_Tally() == 1);
    }

    UFUNCTION()
    private void OnServerTallied(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        LetGo_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        Report_Point(_Fishing.Get_CatchWorld());
        Report_Step(FMars_TESTONLY_NetMinigameStep(2));
        WaitUntil(n"Is_ServerFree", n"OnServerFree", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFree());
    }

    UFUNCTION()
    private void OnServerFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(3));
        const auto Items = Count_WorldItemsNear(Get_ReportedPoint(), k_NearCm);
        Assert_Equals_Int(_Fishing.Get_Tally(), 1, f"the server's tally counts one ({Describe_Fishing()})");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, f"the server's spot reads Idle ({Describe_Fishing()})");
        Assert_Equals_Int(Items, 1, f"exactly one world item lies near the server's catch point ({Items})");
        End_FishingServer(f"items={Items} {Describe_Record()} {Describe_Fishing()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            utils_station::Request_ActFor(_Station, Get_SubjectEntity(), EMars_Station_Verb::Reserve);
            Await_Step(2, EMars_TESTONLY_NetMinigameArrival::Immediate);
            return;
        }

        if (InStep == 2)
        {
            utils_station::Request_ActFor(_Station, Get_SubjectEntity(), EMars_Station_Verb::Leave);
            Await_Step(3, EMars_TESTONLY_NetMinigameArrival::Settled);
            return;
        }

        // The record's events in order, without the phase and presence changes between them.
        auto Events = TArray<EMars_TESTONLY_NetFishingSignal>();
        for (const auto Signal : _Signals)
        {
            if (Signal != EMars_TESTONLY_NetFishingSignal::OnPhaseChanged && Signal != EMars_TESTONLY_NetFishingSignal::OnPresenceChanged)
            { Events.Add(Signal); }
        }

        const auto IsInOrder = Events.Num() == 5
            && Events[0] == EMars_TESTONLY_NetFishingSignal::OnCast
            && Events[1] == EMars_TESTONLY_NetFishingSignal::OnBite
            && Events[2] == EMars_TESTONLY_NetFishingSignal::OnBiteEnded
            && Events[3] == EMars_TESTONLY_NetFishingSignal::OnLanded
            && Events[4] == EMars_TESTONLY_NetFishingSignal::OnCollected;
        const auto IsHooked = _BiteEnds.Num() == 1 && _BiteEnds[0] == EMars_Fishing_BiteResult::Hooked;
        const auto Items = Count_WorldItemsNear(Get_ReportedPoint(), k_NearCm);
        Assert_Equals_Int(_Fishing.Get_Tally(), 1, f"the client's tally counts one ({Describe_Fishing()})");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, f"the client's spot reads Idle ({Describe_Fishing()})");
        Assert_Equals_Int(Items, 1, f"exactly one world item lies near the client's catch point ({Items})");
        Assert_True(IsInOrder, f"the client raised OnCast, OnBite, OnBiteEnded, OnLanded and OnCollected once each, in order ({Describe_Record()})");
        Assert_True(IsHooked, f"the client's bite ended Hooked ({Describe_Record()})");
        End_FishingClient(f"items={Items} {Describe_Record()} {Describe_Fishing()}");
    }
}
