// Prey stands 600 from a roosting Cellar Bat on the server, its script ticking: the bat wakes, flies at it, telegraphs
// (Telegraphing, then Screeching), dives once, lands its blow on the prey once and pulls out. The server's swoop runs
// its three stages in order, each clock rising without a rewind, and faces the prey at the end of its telegraph. The
// client's copy shows the same phases from the ledger and the same three stages off them, each timed on its own clock
// with the same bounds and no rewind, and faces the prey as the server's root did; it raises no swoop or target signal
// and keeps no swoop of its own but the stage it shows.
// Surface: Ck.Bat.Net.AS_Bat_ASwoopRunsItsStagesOnBothMachines
class UCk_AutoTest_Net_Bat_ASwoopRunsItsStagesOnBothMachines : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(694000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(600.0, 0.0, 0.0);
    private const float32 k_ServerWatchSeconds = 2.0f;
    private const float64 k_FacingDegrees = 15.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_Floor);
        _WithVisuals = true;
        _Spec.Swoop.Timing.CooldownSeconds = 30.0f;
        _FacingPoint = TOptional<FVector>(Get_PreyPlace(k_PreyOffset));

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerWorld(n"OnServerReady");
    }

    private TArray<EMars_Bat_Phase> Get_SwoopOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Alert);
        Order.Add(EMars_Bat_Phase::Launching);
        Order.Add(EMars_Bat_Phase::Approaching);
        Order.Add(EMars_Bat_Phase::Telegraphing);
        Order.Add(EMars_Bat_Phase::Screeching);
        Order.Add(EMars_Bat_Phase::Swooping);
        Order.Add(EMars_Bat_Phase::Recovering);
        return Order;
    }

    private TArray<EMars_Bat_SwoopStage> Get_StageOrder() const
    {
        auto Order = TArray<EMars_Bat_SwoopStage>();
        Order.Add(EMars_Bat_SwoopStage::Telegraphing);
        Order.Add(EMars_Bat_SwoopStage::Committed);
        Order.Add(EMars_Bat_SwoopStage::Recovering);
        return Order;
    }

    // Alert, Launching, Approaching, then Telegraphing or Screeching, then Swooping, then Recovering, in that order
    // (other phases may come between): a copy may receive the telegraph under either name, or both.
    private bool Get_SawTheSwoopUnderEitherTelegraphName() const
    {
        auto Next = 0;
        for (const auto& Recorded : _BatPhases)
        {
            const auto To = Recorded.To;
            if (Next == 0 && To == EMars_Bat_Phase::Alert)
            { Next = 1; }
            else if (Next == 1 && To == EMars_Bat_Phase::Launching)
            { Next = 2; }
            else if (Next == 2 && To == EMars_Bat_Phase::Approaching)
            { Next = 3; }
            else if (Next == 3 && (To == EMars_Bat_Phase::Telegraphing || To == EMars_Bat_Phase::Screeching))
            { Next = 4; }
            else if (Next == 4 && To == EMars_Bat_Phase::Swooping)
            { Next = 5; }
            else if (Next == 5 && To == EMars_Bat_Phase::Recovering)
            { Next = 6; }
        }

        return Next == 6;
    }

    // A phase change was recorded out of Recovering.
    private bool Get_HasLeftRecovering() const
    {
        for (const auto& Recorded : _BatPhases)
        {
            if (Recorded.From == EMars_Bat_Phase::Recovering)
            { return true; }
        }

        return false;
    }

    private FString Describe_Telegraph() const
    {
        return f"telegraphNames=[telegraphing {Count_PhaseArrivals(EMars_Bat_Phase::Telegraphing)} screeching {Count_PhaseArrivals(EMars_Bat_Phase::Screeching)}] facingSamples={_BatSwoop.FacingSamples}";
    }

    // The stage, progress, rewind and facing asserts both machines make on their own samples.
    private void Assert_TheSwoopAsSampled()
    {
        Assert_True(Get_SampledStagesInOrder(Get_StageOrder()),
            f"the {Get_MachineName()} sampled Telegraphing, Committed, Recovering in that order (sampled {Describe_Stages()})");
        Assert_True(Get_LastSampledStage() == EMars_Bat_SwoopStage::None,
            f"the {Get_MachineName()}'s last sampled stage reads None (reads {Get_LastSampledStage() :n})");
        Assert_True(_BatSwoop.Telegraph.Highest >= 0.5f,
            f"the {Get_MachineName()}'s telegraph progress reached 0.5 (highest {_BatSwoop.Telegraph.Highest})");
        Assert_True(_BatSwoop.Dive.Highest > 0.1f,
            f"the {Get_MachineName()}'s dive progress passed 0.1 (highest {_BatSwoop.Dive.Highest})");
        Assert_True(_BatSwoop.Recover.Highest >= 0.5f,
            f"the {Get_MachineName()}'s pull-out progress reached 0.5 (highest {_BatSwoop.Recover.Highest})");
        Assert_Equals_Int(_BatSwoop.Rewinds, 0, f"the {Get_MachineName()}'s stage clock never rewound");
        Assert_FacedTheFacingPoint(k_FacingDegrees);
    }

    UFUNCTION()
    private void Is_SwoopedAndLeftRecovering(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _BatSwoopsLanded > 0 && Get_HasLeftRecovering());
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_SwoopedAndLeftRecovering", n"OnServerSwooped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSwooped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BatRow("ASwoopRunsItsStagesOnBothMachines", Describe_Telegraph());
        Assert_True(Get_SawPhasesInOrder(Get_SwoopOrder()),
            f"the server recorded Alert, Launching, Approaching, Telegraphing, Screeching, Swooping, Recovering (saw {Describe_BatPhases()})");
        Assert_TheSwoopAsSampled();
        Assert_Equals_Int(_BatSwoopsLanded, 1, "the server raised OnSwoopLanded exactly once");
        Assert_True(_BatLandedZones.Num() == 1 && _BatLandedZones[0] == _PreyZone, "the server's blow landed on the prey's zone");
        Assert_Equals_Int(_BatSwoopsCancelled, 0, "the server raised no OnSwoopCancelled");
        Assert_Equals_Int(_PreyDamaged, 1, "the prey's Health raised OnDamaged exactly once");
        Assert_True(_PreyHealth.Get_Current() < 100.0f, f"the prey's Health fell (reads {_PreyHealth.Get_Current()})");
        const auto Ledger = _Bat.Get_SwoopLedger();
        Assert_Equals_Int(Ledger.Generation, 1, "the server's swoop ledger reads generation 1");
        Assert_Equals_Int(Ledger.Landed, 1, "the server's swoop ledger landed once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void Is_CopyLeftRecovering(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && Get_HasLeftRecovering());
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting, "the client found its copy roosting");
        WaitUntil(n"Is_CopyLeftRecovering", n"OnClientLeftRecovering", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLeftRecovering(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsBatGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        Log_BatRow("ASwoopRunsItsStagesOnBothMachines", Describe_Telegraph());
        Assert_True(Get_SawTheSwoopUnderEitherTelegraphName(),
            f"the client recorded Alert, Launching, Approaching, a telegraph, Swooping, Recovering (saw {Describe_BatPhases()})");
        Assert_TheSwoopAsSampled();
        Assert_True(_BatHighestSpeed > 300.0f, f"the client measured a speed above 300 (highest {_BatHighestSpeed})");
        Assert_True(_BatLargestStep < 150.0, f"the client's root never stepped 150 or more (largest {_BatLargestStep})");
        Assert_CopyKeepsNoSwoopOfItsOwn();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
