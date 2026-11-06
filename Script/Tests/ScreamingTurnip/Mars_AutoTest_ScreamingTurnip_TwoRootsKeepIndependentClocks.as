// Two roots dropped 0.4 s apart onto one slab, a metre apart, keep their own clocks: each counts its own sequences 1, 2, 3
// on its own period, the second's commits trail the first's (it settled later), and neither's commits move the other's.
class UMars_AutoTest_ScreamingTurnip_TwoRootsKeepIndependentClocks : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 12000.0, -30000.0);

    private FMars_ScreamingTurnip_Vocal _Vocal;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Vocal = Make_ShortVocal();
        Build_Floor(InHandle);
        Spawn_Turnip(InHandle, FVector(0.0, -50.0, 30.0), _Vocal);

        Add_Step_WaitSeconds("0.4 s before the second root", 0.4f);
        Add_Step("drop the second root", n"Step_SpawnSecond");
        Add_Step_WaitUntil("both roots are constructed and seeded", n"Check_BothReady");
        Add_Step_WaitUntil("each has screamed three times", n"Check_ThreeEach", k_SlowPolls);
        Add_Step("independent sequences and clocks", n"Step_AssertIndependent");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Spawn_Turnip(InHandle, FVector(0.0, 50.0, 30.0), _Vocal);
    }

    UFUNCTION()
    private void Check_BothReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Ready = _WorldItems.Num() == 2;
        for (const auto& WorldItem : _WorldItems)
        { Ready = Ready && ck::IsValid(WorldItem.Get_HeldItem()); }

        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Check_ThreeEach(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(Get_CommitsOf(_Turnips[0]).Num() >= 3 && Get_CommitsOf(_Turnips[1]).Num() >= 3);
    }

    UFUNCTION()
    private void Step_AssertIndependent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Turnips[0] != _Turnips[1], "two kernels");
        for (int32 Root = 0; Root < 2; ++Root)
        {
            const auto Commits = Get_CommitsOf(_Turnips[Root]);
            for (int32 Index = 0; Index < 3; ++Index)
            { Assert_Equals_Int(Commits[Index].Sequence, Index + 1, f"root {Root} commit {Index} carries its own sequence {Index + 1}"); }

            Assert_Intervals(Commits, Get_Period(_Vocal), f"root {Root}");
            Assert_Equals_Int(_Turnips[Root].Get_ScreamSequence(), Commits.Num(), f"root {Root} counts only its own commits");
        }

        // The second root's clock started 0.4 s (or more) later, so it reads less at any instant.
        Assert_True(_Turnips[1].Get_Clock() < _Turnips[0].Get_Clock(), "the second root's kernel clock started later");
        Assert_False(_Turnips[0].Get_LastScreamPosition().Equals(_Turnips[1].Get_LastScreamPosition(), 1.0),
            "each scream is placed at its own root");
    }
}
