// A Cellar Bat born diving 300 from its spawn place: the server holds its ledger at Swooping and the roost's anchor
// from the spawn frame on (its own requests dropped) and moves its root as it composes. The client's copy takes that
// state as it stands at its ledger's first application: it reads Swooping and shows the dive from zero on its own
// clock, stopped at the dive's length, raises no OnPhaseChanged, stands at the moved place, and reads no speed from
// its first arrival there.
// Surface: Ck.Bat.Net.AS_Bat_ACopyBornIntoADiveShowsItAsItStands
class UCk_AutoTest_Net_Bat_ACopyBornIntoADiveShowsItAsItStands : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(699000.0, 0.0, 5000.0);
    private const FVector k_RootOffset = FVector(300.0, 0.0, 0.0);
    private const float32 k_HoldSeconds = 4.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const float32 k_MinClockSeconds = 1.3f;
    private const float32 k_MaxClockSeconds = 3.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_Floor);
        _Spec.Swoop.Timing.CooldownSeconds = 30.0f;
        _HeldRootOffset = k_RootOffset;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        _HeldLedger = TOptional<FMars_Fragment_Bat_Net>(Make_HeldBatLedger());
        Begin_ServerWorld(n"OnServerReady");
    }

    // Both machines compute it alike: diving, hanging from the roost's anchor.
    private FMars_Fragment_Bat_Net Make_HeldBatLedger() const
    {
        auto Ledger = FMars_Fragment_Bat_Net();
        Ledger.Phase = EMars_Bat_Phase::Swooping;
        Ledger.PerchAnchor = Get_RoostAnchor();
        return Ledger;
    }

    private float64 Get_BatFromMovedPlace()
    {
        if (Get_IsBatGone())
        { return -1.0; }

        return (_Bat.Get_Location() - (_HangAt + _HeldRootOffset)).Size();
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_HoldSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto FromMoved = Get_BatFromMovedPlace();
        Assert_True(Get_HasBatLedger(), "the server's bat has its ledger");
        Assert_True(Get_BatLedger().Phase == EMars_Bat_Phase::Swooping, f"the server's ledger reads Swooping (reads {Get_BatLedger().Phase :n})");
        Assert_True(Get_BatLedger().PerchAnchor.Equals(Get_RoostAnchor(), 0.01), "the server's ledger reads the roost's anchor");
        Assert_True(FromMoved >= 0.0 && FromMoved <= 1.0, f"the server's root is within 1 of the moved place (reads {FromMoved})");
        Hold_BatServerRow("ACopyBornIntoADiveShowsItAsItStands", f"ownPhase={_Bat.Get_Phase() :n} fromMoved={FromMoved}");
    }

    UFUNCTION()
    private void Is_CopySwooping(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_Phase() == EMars_Bat_Phase::Swooping);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_CopySwooping", n"OnClientSwooping", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSwooping(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ClientWatchSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsBatGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto FromMoved = Get_BatFromMovedPlace();
        const auto Held = Make_HeldBatLedger();
        const auto First = TryGet_BatFirstNotifyLedger();
        const auto PhaseClock = _Bat.Get_PhaseClock();
        const auto Frame = _Bat.Get_SwoopFrame();
        const auto Elapsed = _Bat.Get_SwoopLedger().StageElapsed;
        const auto SwoopSeconds = _Bat.Get_Spec().Swoop.Timing.SwoopSeconds;
        Log_BatRow("ACopyBornIntoADiveShowsItAsItStands", f"fromMoved={FromMoved} firstNotifyFrame={Get_BatFirstNotifyFrame()}");

        auto OnlyCommitted = TArray<EMars_Bat_SwoopStage>();
        OnlyCommitted.Add(EMars_Bat_SwoopStage::Committed);
        auto NoneThenCommitted = TArray<EMars_Bat_SwoopStage>();
        NoneThenCommitted.Add(EMars_Bat_SwoopStage::None);
        NoneThenCommitted.Add(EMars_Bat_SwoopStage::Committed);

        Assert_True(Get_BatInitialState() == EMars_Net_InitialState::Taken, "the client's copy has taken the state it was born into");
        Assert_True(_BatInitialAtFind == EMars_Net_InitialState::Awaited, "the client found its copy before it took that state");
        Assert_True(First.IsSet(), "the client recorded its ledger's first rep-notify");
        if (First.IsSet())
        {
            Assert_True(First.GetValue().Phase == EMars_Bat_Phase::Swooping, f"the first notify carried Swooping (got {First.GetValue().Phase :n})");
            Assert_True(First.GetValue().PerchAnchor.Equals(Held.PerchAnchor, 0.01), "the first notify carried the held anchor");
        }

        Assert_Equals_Int(_BatPhases.Num(), 0, f"the client raised no OnPhaseChanged (got [{Describe_BatPhases()}])");
        Assert_True(_Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::Committed, f"the client's swoop stage reads Committed (reads {_Bat.Get_SwoopStage() :n})");
        Assert_True(_Bat.Get_IsSwoopCommitted(), "the client's copy reads its swoop committed");
        Assert_True(Get_SampledStagesAre(OnlyCommitted) || Get_SampledStagesAre(NoneThenCommitted),
            f"the client sampled Committed alone, or None then Committed (sampled {Describe_Stages()})");
        Assert_True(_BatSwoop.Dive.Samples > 0 && _BatSwoop.Dive.Lowest < 0.2f,
            f"the client's dive progress started from zero on its clock (lowest {_BatSwoop.Dive.Lowest})");
        Assert_True(Frame.Alpha == 1.0f, f"the client's dive progress reads 1 (reads {Frame.Alpha})");
        Assert_True(Math::Abs(Elapsed - SwoopSeconds) <= 0.001f,
            f"the client's dive clock stopped at the dive's length {SwoopSeconds} (reads {Elapsed})");
        Assert_Equals_Int(_BatSwoop.Rewinds, 0, "the client's stage clock never rewound");
        Assert_True(PhaseClock >= k_MinClockSeconds && PhaseClock <= k_MaxClockSeconds,
            f"the copy's phase clock runs from its first notify (reads {PhaseClock})");
        Assert_True(FromMoved >= 0.0 && FromMoved <= 1.0, f"the client's root is within 1 of the moved place (reads {FromMoved})");
        Assert_True(_BatHighestSpeed < 1.0f, f"the client read no speed from its first arrival (highest {_BatHighestSpeed})");
        Assert_CopyKeepsNoSwoopOfItsOwn();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
