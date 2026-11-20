// A passive armed crawler whose ledger the server holds at a jab of generation 7 in Strike from its construct on, so
// the client's copy is born into that attack. For the three seconds of the hold the copy starts nothing, raises no
// OnAttackCue and has taken generation 7 as it stood. Once the hold is released the server runs one real attack, of a
// generation other than 7, back to Idle: the copy starts exactly one action, for that generation, which Completes with
// its Admitted and Completed cues once each.
// Surface: Ck.Crawler.Net.AS_Crawler_ACopyBornIntoAnAttackShowsOnlyTheNext
class UCk_AutoTest_Net_Crawler_ACopyBornIntoAnAttackShowsOnlyTheNext : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 32.0f;

    private const FVector k_Base = FVector(841000.0, 0.0, 5000.0);
    private const FString k_Row = "ACopyBornIntoAnAttackShowsOnlyTheNext";
    private const int32 k_HeldGeneration = 7;
    private const float32 k_HoldSeconds = 3.0f;

    // The client while its ledger reads the held generation: the samples, the most actions it had started, the cues
    // it raised and whether it had taken the held generation as it stood at every sample.
    private int32 _HoldSamples = 0;
    private int32 _HoldStartedMost = 0;
    private int32 _HoldCues = 0;
    private bool _HoldStoodAtHeld = true;
    private float64 _HoldSince = -1.0;
    private FString _HeldFrames = "";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerSettled", n"OnClientSettled", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCrawlerOfClass(Make_ArmedRowSpec(k_StaysPut, ECk_EnableDisable::Disable), UMars_TESTONLY_NetCrawler_HeldLedger_EntityScript);
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_AttackRecord();
        Spawn_Prey();
        WaitSampling(k_HoldSeconds, n"OnServerHoldDone");
    }

    UFUNCTION()
    private void OnServerHoldDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_CrawlerRoot.Has_Fragment(FMars_TESTONLY_Fragment_Crawler_HeldLedger) == false)
        {
            FinishFailure("the server's crawler holds no ledger");
            return;
        }

        auto& Held = _CrawlerRoot.Get_Fragment(FMars_TESTONLY_Fragment_Crawler_HeldLedger);
        _HeldFrames = f"construct {Held.ConstructFrame} firstHold {Held.FirstHoldFrame} release {utils_time::Get_FrameCounter()}";
        Held.Holding = false;
        WaitSampling(1.0f, n"OnServerReleased");
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Run_ServerAttack(n"OnServerAttackDone");
    }

    UFUNCTION()
    private void OnServerAttackDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(1.0f, n"OnServerSampled");
    }

    UFUNCTION()
    private void OnServerSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerAttacks(0, -1.0f, TArray<float32>());
        const auto Index = Find_LastStartedAttack();
        Assert_True(Index >= 0, "the server's real attack was admitted");
        if (Index >= 0)
        {
            const auto Record = _Attacks[Index];
            Assert_True(Record.Generation != k_HeldGeneration, f"the server's real attack is not generation 7 ({Record.Generation})");
            Assert_True(Describe_Phases(Record.Phases) == "Windup,Strike,Recover,Cooldown,Idle,",
                f"the server's real attack ran Windup, Strike, Recover, Cooldown, Idle ({Describe_Phases(Record.Phases)})");
        }

        Hold_CrawlerServerRow(k_Row, f"held=[{_HeldFrames}] {Describe_AttackState()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_AttackRecord();
        Spawn_Prey();
        _HoldSince = Get_WorldSeconds();
        WaitUntil(n"Is_ClientHoldOver", n"OnClientHoldOver", k_SlowPolls);
    }

    // Samples while the ledger reads the held generation; over once it read it and then something else (or after the
    // readout ceiling without it).
    UFUNCTION()
    private void Is_ClientHoldOver(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Held = Get_IsCrawlerGone() == false && Get_CopyLedger().AttackGeneration == k_HeldGeneration;
        if (Held)
        {
            _HoldSamples += 1;
            _HoldStartedMost = Math::Max(_HoldStartedMost, Get_CopyStarted());
            _HoldCues = _AttackCues;
            _HoldStoodAtHeld = _HoldStoodAtHeld && Get_CopyStoodGeneration() == k_HeldGeneration;
        }

        auto Result = OutResult;
        Result.Set((Held == false && _HoldSamples > 0) || Get_WorldSeconds() - _HoldSince >= k_ReadoutCeilingSeconds);
    }

    UFUNCTION()
    private void OnClientHoldOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_ServerAttacks(n"OnClientArrived");
    }

    UFUNCTION()
    private void OnClientArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsCrawlerGone())
        { FinishFailure("the client's copy was gone before it asserted"); return; }

        const auto Path = _LedgerInitialAtFind == EMars_Net_InitialState::Taken ? "stood at compose" : "first notify";
        Assert_CopyKeepsNoAttackOfItsOwn();
        Assert_True(_HoldSamples > 0, "the client's ledger read the held generation");
        Assert_Equals_Int(_HoldStartedMost, 0, "the copy started no action during the hold");
        Assert_Equals_Int(_HoldCues, 0, "the copy raised no OnAttackCue during the hold");
        Assert_True(_HoldStoodAtHeld, "the copy had taken generation 7 as it stood throughout the hold");

        const auto Readout = Get_ServerAttacks();
        Assert_Equals_Int(Readout.Attacks.Num(), 1, "the server's one real attack reached the client");
        Assert_Equals_Int(Get_CopyStarted(), 1, "the copy started exactly one action");
        Assert_Equals_Int(Count_StartedAttacks(), 1, "the copy recorded one started attack");
        const auto Index = Find_LastStartedAttack();
        if (Readout.Attacks.Num() > 0 && Index >= 0)
        {
            const auto Record = _Attacks[Index];
            Assert_Equals_Int(Record.Generation, Readout.Attacks[0].Generation, "the copy's one action is the server's real attack");
            Assert_True(Record.Outcome == ECk_ProceduralAction_Outcome::Completed, f"the copy's action Completed ({Record.Outcome :n})");
            Assert_True(Record.Admitted == 1 && Record.Completed == 1, f"the copy raised Admitted 1, Completed 1 ({Record.Admitted}/{Record.Completed})");
        }

        Assert_DecoyUntouched();
        Finish_CrawlerRow(k_Row, f"path=[{Path}] hold=[samples {_HoldSamples} startedMost {_HoldStartedMost} cues {_HoldCues} stoodAtHeld {_HoldStoodAtHeld}] {Describe_AttackState()} {Describe_ServerAttacks()}");
    }
}
