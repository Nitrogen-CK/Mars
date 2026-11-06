// A held root stowed (another bag slot selected: its slot is no longer the held one) is Carried and Protected: phase
// Dormant, the warning cancelled, nothing commits however long it stays there. Selected again it is Held, and its next
// scream comes a full fresh warning after that and no sooner than the cooldown from its last commit allows (2 s here, so
// it outlasts the one-second stow).
class UMars_AutoTest_ScreamingTurnip_StowSilencesAndUnstowRestartsTheWarning : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 9000.0, -30000.0);

    private FMars_ScreamingTurnip_Vocal _Vocal;
    private int32 _SequenceAtStow = 0;
    private float32 _LastCommitAtStow = 0.0f;
    private float32 _UnstowedAt = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Vocal = Make_ShortVocal();
        _Vocal.CooldownSeconds = 2.0f;

        Build_Floor(InHandle);
        Build_Carrier(InHandle);
        Spawn_Turnip(InHandle, FVector(0.0, 0.0, 10.0), _Vocal);

        Add_Step_WaitUntil("the root is constructed and seeded", n"Check_TurnipsReady");
        Add_Step("pick it up into the empty hands (bag slot 0)", n"Step_PickUp");
        Add_Step_WaitUntil("it is Held", n"Check_FirstHeld", k_SlowPolls);
        Add_Step_WaitUntil("it screams in the hands", n"Check_OneScream", k_SlowPolls);
        Add_Step("stow it: select the empty bag slot 1", n"Step_Stow");
        Add_Step_WaitUntil("it is Protected", n"Check_Protected", k_SlowPolls);
        Add_Step_WaitSeconds("a one-second stow (longer than the 0.3 s warning)", 1.0f);
        Add_Step("silent while stowed", n"Step_AssertSilent");
        Add_Step("unstow it: select bag slot 0", n"Step_Unstow");
        Add_Step_WaitUntil("it is Held again", n"Check_FirstHeld", k_SlowPolls);
        Add_Step("record when it was held again", n"Step_RecordUnstow");
        Add_Step_WaitUntil("it screams again", n"Check_ScreamAfterStow", k_SlowPolls);
        Add_Step("a fresh warning after the unstow, the cooldown honoured", n"Step_AssertFresh");
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
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        _SequenceAtStow = Turnip.Get_ScreamSequence();
        _LastCommitAtStow = Turnip.Get_LastScreamCommittedAt().Get(0.0f);
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    private void Check_Protected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Turnips[0].Get_Placement() == EMars_ScreamingTurnip_Placement::Protected
            && _WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Carried);
    }

    UFUNCTION()
    private void Step_AssertSilent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        Assert_True(Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::Protected, "still Protected");
        Assert_True(Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Dormant, "Dormant while stowed");
        Assert_True(Turnip.Get_WarningElapsed() == 0.0f, "the warning was cancelled");
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), _SequenceAtStow, "nothing committed while stowed");
        Assert_Equals_Int(_Commits.Num(), _SequenceAtStow, "no broadcast while stowed");
        Assert_False(Turnip.Get_SecondsUntilNextWarning().IsSet(), "a stowed root has no next warning");
    }

    UFUNCTION()
    private void Step_Unstow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    private void Step_RecordUnstow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        _UnstowedAt = TryGet_EnteredAt(Turnip, EMars_ScreamingTurnip_Placement::Held, _LastCommitAtStow + 0.001f).Get(Turnip.Get_Clock());
    }

    UFUNCTION()
    private void Check_ScreamAfterStow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Commits.Num() > _SequenceAtStow);
    }

    UFUNCTION()
    private void Step_AssertFresh(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Next = _Commits[_SequenceAtStow];
        Assert_Equals_Int(Next.Sequence, _SequenceAtStow + 1, "the sequence continues from the stow");

        const auto Warning = _Vocal.AnticipateSeconds + _Vocal.InhaleSeconds;
        Assert_True(Next.At - _UnstowedAt >= Warning - 0.001f,
            f"a full fresh warning after the unstow ({Next.At - _UnstowedAt :.3} s >= {Warning :.3} s)");
        const auto FromLastCommit = Next.At - _LastCommitAtStow;
        Assert_True(FromLastCommit >= Get_Period(_Vocal) - 0.001f,
            f"the cooldown from the last commit held ({FromLastCommit :.3} s >= {Get_Period(_Vocal) :.3} s)");
    }
}
