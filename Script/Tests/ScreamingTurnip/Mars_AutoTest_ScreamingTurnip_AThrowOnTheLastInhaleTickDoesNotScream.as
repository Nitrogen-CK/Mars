// A root Held in the hands is released (WorldItem.Request_Release, the call HeldItemUse's throw ends in) on the poll just
// before the kernel tick that completes its Inhale: that tick reads the release (Transfer, the WorldItem release drain runs
// before the kernel tick in the same frame) and commits nothing, then or after, until it is picked up again.
//
// Hitting the edge: the release is requested on the first poll at which the Inhale has no more than one kernel step left,
// so the next tick completes it. Automation runs on a fixed step (1/60 s: the remaining Inhale reads in whole steps), so
// that tick IS the Inhale-completing one, and the test asserts it (the Transfer change's clock reaches the Inhale's end).
// It also asserts Held -> Transfer on that tick: the order proof that the release drained in the main pass is read by the
// kernel in the same frame.
class UMars_AutoTest_ScreamingTurnip_AThrowOnTheLastInhaleTickDoesNotScream : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 24000.0, -30000.0);

    // A kernel step's float noise (the clock is a float32 sum of steps).
    private const float32 k_StepSlack = 0.0001f;

    private FMars_ScreamingTurnip_Vocal _Vocal;
    private float32 _LastPollClock = -1.0f;
    private float32 _LastStep = 0.0f;
    private int32 _SequenceAtRelease = 0;
    private int32 _CommitsAtRelease = 0;
    private int32 _PlacementsAtRelease = 0;
    private float32 _ReleasedAt = 0.0f;
    private float32 _InhaleEndsAt = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // A long Inhale, so a poll lands in its last tick's window.
        _Vocal = Make_ShortVocal();
        _Vocal.InhaleSeconds = 0.5f;
        Build_Floor(InHandle);
        Build_Carrier(InHandle);
        Spawn_Turnip(InHandle, FVector(0.0, 0.0, 10.0), _Vocal);

        Add_Step_WaitUntil("the root is constructed and seeded", n"Check_TurnipsReady");
        Add_Step("pick it up into the empty hands", n"Step_PickUp");
        Add_Step_WaitUntil("it is Held", n"Check_FirstHeld", k_SlowPolls);
        Add_Step_WaitUntil("a poll lands just before the Inhale's last tick", n"Check_LastInhaleTickIsNext", k_SlowPolls);
        Add_Step("release it", n"Step_Release");
        Add_Step_WaitUntil("it is Loose", n"Check_Loose", k_SlowPolls);
        Add_Step("the tick that read the release was Transfer; nothing committed", n"Step_AssertNoScream");
        Add_Step_WaitUntil("it settles on the slab", n"Check_FirstSettled", k_SlowPolls);
        Add_Step("still nothing committed from the released Inhale", n"Step_AssertStillSilent");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Stow(_WorldItems[0]);
    }

    // Held, in the Inhale, with no more than one kernel step left of it.
    UFUNCTION()
    private void Check_LastInhaleTickIsNext(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        const auto Turnip = _Turnips[0];
        const auto Clock = Turnip.Get_Clock();
        if (_LastPollClock >= 0.0f && Clock > _LastPollClock)
        { _LastStep = Clock - _LastPollClock; }

        _LastPollClock = Clock;

        const auto Remaining = _Vocal.AnticipateSeconds + _Vocal.InhaleSeconds - Turnip.Get_WarningElapsed();
        const auto IsNext = Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::Held
            && Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Inhale
            && _LastStep > 0.0f && Remaining > 0.0f && Remaining <= _LastStep + k_StepSlack;

        auto Res = OutResult;
        Res.Set(IsNext);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        _SequenceAtRelease = Turnip.Get_ScreamSequence();
        _CommitsAtRelease = _Commits.Num();
        _PlacementsAtRelease = _Placements.Num();
        _ReleasedAt = Turnip.Get_Clock();
        _InhaleEndsAt = _ReleasedAt + _Vocal.AnticipateSeconds + _Vocal.InhaleSeconds - Turnip.Get_WarningElapsed();

        auto WorldItem = _WorldItems[0];
        WorldItem.Request_Release(FMars_Request_WorldItem_Release(FVector(250.0, 0.0, 200.0), FVector(0.0, 0.0, 180.0)));
    }

    UFUNCTION()
    private void Check_Loose(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Turnips[0].Get_Placement() == EMars_ScreamingTurnip_Placement::Loose);
    }

    UFUNCTION()
    private void Step_AssertNoScream(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), _SequenceAtRelease, "the released Inhale committed nothing");
        Assert_Equals_Int(_Commits.Num(), _CommitsAtRelease, "no OnScreamCommitted after the release");

        Assert_True(_Placements.Num() > _PlacementsAtRelease, "the release changed the placement");
        if (_Placements.Num() <= _PlacementsAtRelease)
        { return; }

        const auto First = _Placements[_PlacementsAtRelease];
        Assert_True(First.Previous == EMars_ScreamingTurnip_Placement::Held && First.New == EMars_ScreamingTurnip_Placement::Transfer,
            f"the first tick after the release read the PendingRelease: Held -> Transfer (got {First.Previous :n} -> {First.New :n})");

        const auto HitTheEdge = First.At >= _InhaleEndsAt - k_StepSlack;
        Assert_True(HitTheEdge, f"the tick that read the release ({First.At :.4}) is the one the Inhale completes on ({_InhaleEndsAt :.4})");
        Log(f"[ScreamingTurnip] released at clock {_ReleasedAt :.4}, the Inhale ends at {_InhaleEndsAt :.4}; the tick that read the release ran at {First.At :.4} (the Inhale-completing tick: {HitTheEdge})");
    }

    UFUNCTION()
    private void Step_AssertStillSilent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // Settled again, the root starts a fresh warning; the released one never commits.
        const auto Turnip = _Turnips[0];
        for (int32 Index = _CommitsAtRelease; Index < _Commits.Num(); ++Index)
        {
            const auto SettledAt = TryGet_EnteredAt(Turnip, EMars_ScreamingTurnip_Placement::LooseSettled, _ReleasedAt);
            Assert_True(SettledAt.IsSet() && _Commits[Index].At >= SettledAt.Get(0.0f),
                f"scream {_Commits[Index].Sequence} at {_Commits[Index].At :.3} comes after the settle, not from the released Inhale");
        }
    }
}
