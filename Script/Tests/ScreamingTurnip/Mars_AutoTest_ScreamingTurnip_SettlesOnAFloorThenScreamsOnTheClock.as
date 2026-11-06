// A root dropped 30 cm onto a slab goes Loose -> LooseSettled once it has been supported and still for the enter dwell, then
// screams on its own clock: three commits with sequences 1, 2, 3, the first a full warning (Anticipate + Inhale) after it
// settled, each later one Cooldown + Anticipate + Inhale after the one before (within one tick), one broadcast per commit.
class UMars_AutoTest_ScreamingTurnip_SettlesOnAFloorThenScreamsOnTheClock : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 0.0, -30000.0);

    private FMars_ScreamingTurnip_Vocal _Vocal;
    private float32 _SettledAt = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Vocal = Make_ShortVocal();
        Build_Floor(InHandle);
        Spawn_Turnip(InHandle, FVector(0.0, 0.0, 30.0), _Vocal);

        Add_Step_WaitUntil("the root is constructed and seeded", n"Check_TurnipsReady");
        Add_Step_WaitUntil("it settles on the slab", n"Check_FirstSettled", k_SlowPolls);
        Add_Step("it went Loose -> LooseSettled after the enter dwell, silent until then", n"Step_AssertSettled");
        Add_Step_WaitUntil("three screams", n"Check_ThreeScreams", k_SlowPolls);
        Add_Step("sequences 1, 2, 3 on the clock", n"Step_AssertScreams");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        const auto SettledAt = TryGet_EnteredAt(Turnip, EMars_ScreamingTurnip_Placement::LooseSettled, 0.0f);
        Assert_True(SettledAt.IsSet(), "OnPlacementChanged reported LooseSettled");
        if (SettledAt.IsSet() == false)
        { return; }

        _SettledAt = SettledAt.GetValue();
        const auto Settlement = FMars_ScreamingTurnip_Settlement();
        Assert_True(_SettledAt >= Settlement.EnterDwellSeconds, f"settled at {_SettledAt :.3} s, after the {Settlement.EnterDwellSeconds} s dwell");
        Assert_True(_Placements[_Placements.Num() - 1].Previous == EMars_ScreamingTurnip_Placement::Loose, "it settled from Loose");
        Assert_Equals_Int(_Commits.Num(), 0, "no scream before it settled");
        Assert_True(Turnip.Get_HasSupport(), "a settled root reads supported");
    }

    UFUNCTION()
    private void Check_ThreeScreams(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Commits.Num() >= 3);
    }

    UFUNCTION()
    private void Step_AssertScreams(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Turnip = _Turnips[0];
        Assert_Equals_Int(_Commits.Num(), 3, "one broadcast per commit");
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), 3, "the sequence counts the commits");
        for (int32 Index = 0; Index < _Commits.Num(); ++Index)
        { Assert_Equals_Int(_Commits[Index].Sequence, Index + 1, f"commit {Index} carries sequence {Index + 1}"); }

        const auto Warning = _Vocal.AnticipateSeconds + _Vocal.InhaleSeconds;
        const auto First = _Commits[0].At - _SettledAt;
        Assert_True(First >= Warning - 0.001f && First <= Warning + _MaxTick + 0.001f,
            f"the first scream comes one full warning ({Warning :.3} s) after settling (took {First :.3} s, one tick {_MaxTick :.3})");
        Assert_Intervals(_Commits, Get_Period(_Vocal), "settled");
        Assert_True(Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::LooseSettled, "still settled");
    }
}
