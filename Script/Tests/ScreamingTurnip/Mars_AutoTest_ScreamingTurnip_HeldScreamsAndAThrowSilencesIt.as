// A root picked up into empty hands is Held and screams. Thrown during a later Inhale (WorldItem.Request_Release with a
// throw's velocity, the call HeldItemUse's throw ends in) it leaves Held within a few frames: the warning is dropped (phase
// Dormant, WarningElapsed 0), it is Loose in flight and nothing commits until it settles again; once LooseSettled, the
// next scream comes a FULL fresh warning after settling and no sooner than the cooldown from the last commit allows.
class UMars_AutoTest_ScreamingTurnip_HeldScreamsAndAThrowSilencesIt : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 3000.0, -30000.0);

    // Frames from the release request to Loose: the release drain, the transfer back to the holder, the World commit and the
    // kernel's next tick.
    private const int32 k_MaxFramesToLoose = 4;

    private FMars_ScreamingTurnip_Vocal _Vocal;
    private int32 _SequenceAtThrow = 0;
    private float32 _LastCommitAtThrow = 0.0f;
    private float32 _ThrownAt = 0.0f;
    private int64 _ThrowFrame = -1;
    private int64 _LooseFrame = -1;
    private bool _SawDormantWhenLoose = false;
    private float32 _SettledAgainAt = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Vocal = Make_ShortVocal();
        Build_Floor(InHandle);
        Build_Carrier(InHandle);
        Spawn_Turnip(InHandle, FVector(0.0, 0.0, 10.0), _Vocal);

        Add_Step_WaitUntil("the root is constructed and seeded", n"Check_TurnipsReady");
        Add_Step("pick it up into the empty hands", n"Step_PickUp");
        Add_Step_WaitUntil("it is Held", n"Check_FirstHeld", k_SlowPolls);
        Add_Step_WaitUntil("it screams in the hands", n"Check_OneScream", k_SlowPolls);
        Add_Step_WaitUntil("the next warning reaches its Inhale", n"Check_FirstInhaling", k_SlowPolls);
        Add_Step("throw it", n"Step_Throw");
        Add_Step_WaitUntil("it is Loose", n"Check_Loose", k_SlowPolls);
        Add_Step("Loose within a few frames, the warning dropped", n"Step_AssertLoose");
        Add_Step_WaitUntil("it settles on the slab", n"Check_FirstSettled", k_SlowPolls);
        Add_Step("silent through the flight", n"Step_AssertSilentFlight");
        Add_Step_WaitUntil("it screams again", n"Check_ScreamAfterThrow", k_SlowPolls);
        Add_Step("a full fresh warning after settling, the cooldown honoured", n"Step_AssertFreshWarning");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Stow(_WorldItems[0]);
    }

    UFUNCTION()
    private void Check_OneScream(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Commits.Num() >= 1);
    }

    UFUNCTION()
    private void Step_Throw(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        Assert_True(Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::Held, "thrown from the hands");
        _SequenceAtThrow = Turnip.Get_ScreamSequence();
        _LastCommitAtThrow = Turnip.Get_LastScreamCommittedAt().Get(0.0f);
        _ThrownAt = Turnip.Get_Clock();
        _ThrowFrame = utils_time::Get_FrameCounter();

        auto WorldItem = _WorldItems[0];
        WorldItem.Request_Release(FMars_Request_WorldItem_Release(FVector(250.0, 0.0, 200.0), FVector(0.0, 0.0, 180.0)));
    }

    UFUNCTION()
    private void Check_Loose(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        const auto Turnip = _Turnips[0];
        const auto IsLoose = Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::Loose;
        if (IsLoose && _LooseFrame < 0)
        {
            _LooseFrame = utils_time::Get_FrameCounter();
            _SawDormantWhenLoose = Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Dormant && Turnip.Get_WarningElapsed() == 0.0f;
        }

        auto Res = OutResult;
        Res.Set(IsLoose);
    }

    UFUNCTION()
    private void Step_AssertLoose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Frames = _LooseFrame - _ThrowFrame;
        Log(f"[ScreamingTurnip] Loose {Frames} frame(s) after the release request");
        Assert_True(Frames <= k_MaxFramesToLoose, f"Loose within {k_MaxFramesToLoose} frames of the throw (took {Frames})");
        Assert_True(_SawDormantWhenLoose, "Loose drops the warning: phase Dormant, WarningElapsed 0");
        Assert_False(_Turnips[0].Get_HasSupport(), "in flight it reads unsupported (the airborne look)");
    }

    UFUNCTION()
    private void Step_AssertSilentFlight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), _SequenceAtThrow, "nothing committed between the throw and the settle");
        Assert_Equals_Int(_Commits.Num(), _SequenceAtThrow, "no broadcast in flight");
        const auto SettledAt = TryGet_EnteredAt(Turnip, EMars_ScreamingTurnip_Placement::LooseSettled, _ThrownAt);
        Assert_True(SettledAt.IsSet(), "OnPlacementChanged reported the settle");
        _SettledAgainAt = SettledAt.Get(0.0f);
    }

    UFUNCTION()
    private void Check_ScreamAfterThrow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Commits.Num() > _SequenceAtThrow);
    }

    UFUNCTION()
    private void Step_AssertFreshWarning(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Next = _Commits[_SequenceAtThrow];
        Assert_Equals_Int(Next.Sequence, _SequenceAtThrow + 1, "the sequence continues from the throw");

        const auto Warning = _Vocal.AnticipateSeconds + _Vocal.InhaleSeconds;
        const auto FromSettle = Next.At - _SettledAgainAt;
        Assert_True(FromSettle >= Warning - 0.001f, f"a full fresh warning after the settle ({FromSettle :.3} s >= {Warning :.3} s)");
        const auto FromLastCommit = Next.At - _LastCommitAtThrow;
        Assert_True(FromLastCommit >= Get_Period(_Vocal) - 0.001f,
            f"the cooldown from the last commit held ({FromLastCommit :.3} s >= {Get_Period(_Vocal) :.3} s)");
    }
}
