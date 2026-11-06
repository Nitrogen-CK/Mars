// A settled root destroyed in the middle of its Inhale emits no final scream: no commit and no callback of any kind after
// the destroy request, through a window longer than the warning it had left, and the teardown raises no ensure (the
// harness fails the test on one).
class UMars_AutoTest_ScreamingTurnip_DestroyMidWarningEmitsNoFinalScream : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 15000.0, -30000.0);

    private int32 _CommitsAtDestroy = 0;
    private int32 _PlacementsAtDestroy = 0;
    private int32 _PhaseChangesAtDestroy = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Floor(InHandle);
        Spawn_Turnip(InHandle, FVector(0.0, 0.0, 30.0), Make_ShortVocal());

        Add_Step_WaitUntil("the root is constructed and seeded", n"Check_TurnipsReady");
        Add_Step_WaitUntil("it settles on the slab", n"Check_FirstSettled", k_SlowPolls);
        Add_Step_WaitUntil("its warning reaches the Inhale", n"Check_FirstInhaling", k_SlowPolls);
        Add_Step("destroy it mid-Inhale", n"Step_Destroy");
        Add_Step_WaitSeconds("a window longer than the whole warning", 0.6f);
        Add_Step("nothing after the destroy", n"Step_AssertNothing");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Destroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CommitsAtDestroy = _Commits.Num();
        _PlacementsAtDestroy = _Placements.Num();
        _PhaseChangesAtDestroy = _PhaseChangeCount;
        Assert_Equals_Int(_CommitsAtDestroy, 0, "destroyed before its first scream");

        FCk_Handle Entity = _WorldItems[0];
        utils_entity_lifetime::Request_DestroyEntity(Entity);
    }

    UFUNCTION()
    private void Step_AssertNothing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Commits.Num(), _CommitsAtDestroy, "no final scream");
        Assert_Equals_Int(_Placements.Num(), _PlacementsAtDestroy, "no placement callback after the destroy");
        Assert_Equals_Int(_PhaseChangeCount, _PhaseChangesAtDestroy, "no phase callback after the destroy");
        Assert_False(ck::IsValid(_Turnips[0]), "the root is gone");
    }
}
