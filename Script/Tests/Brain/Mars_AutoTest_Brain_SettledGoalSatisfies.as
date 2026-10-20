// The brain's goal is Settled, a fact nothing in the game writes true. Written true, the goal is met: the planner's
// plan is empty, so the leaf goes Roam -> none (OnLeafChanged carries it) and Settled reads true. Written false again,
// the plan and the leaf return to Roam.
class UMars_AutoTest_Brain_SettledGoalSatisfies : UMars_AutoTestRig_Brain
{
    default _TimeoutSeconds = 20.0f;

    private TArray<TSubclassOf<UCk_GoapAction_EntityScript>> _OldLeaves;
    private TArray<TSubclassOf<UCk_GoapAction_EntityScript>> _NewLeaves;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddBrainEntity(InHandle);
        _Brain.BindTo_OnLeafChanged(FMars_Delegate_Brain_OnLeafChanged(this, n"OnLeafChanged"));

        Add_Step_WaitUntil("the leaf settles on Roam", n"Check_LeafRoam", 0, 0);
        Add_Step("Settled true", n"Step_Settle");
        Add_Step_WaitUntil("the leaf clears", n"Check_LeafNone", 0, 0);
        Add_Step("the goal is met: no leaf, Settled reads true; Settled false", n"Step_AssertSettledAndUnsettle");
        Add_Step_WaitUntil("the leaf returns to Roam", n"Check_LeafRoam", 0, 0);
        Add_Step("the leaf history is Roam, none, Roam", n"Step_AssertHistory");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnLeafChanged(FCk_Handle_Brain InBrain, TSubclassOf<UCk_GoapAction_EntityScript> InOld, TSubclassOf<UCk_GoapAction_EntityScript> InNew)
    {
        _OldLeaves.Add(InOld);
        _NewLeaves.Add(InNew);
    }

    UFUNCTION()
    private void Check_LeafRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Brain.Get_LeafClass() == UMars_GoapAction_Crawler_Roam);
    }

    UFUNCTION()
    private void Step_Settle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Brain.Get_Fact(Settled()), "Settled starts false");
        SetFact(Settled(), true);
    }

    UFUNCTION()
    private void Check_LeafNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Brain.Get_LeafClass()));
    }

    UFUNCTION()
    private void Step_AssertSettledAndUnsettle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Brain.Get_Fact(Settled()), "Settled reads true");
        Assert_Equals_Int(_NewLeaves.Num(), 2, "OnLeafChanged fired for the first plan and the settle");
        if (_NewLeaves.Num() == 2)
        {
            Assert_True(_OldLeaves[1] == UMars_GoapAction_Crawler_Roam, f"the settle left Roam (old {utils_brain::Get_ClassName(_OldLeaves[1])})");
            Assert_True(ck::Is_NOT_Valid(_NewLeaves[1]), f"the settle cleared the leaf (new {utils_brain::Get_ClassName(_NewLeaves[1])})");
        }

        SetFact(Settled(), false);
    }

    UFUNCTION()
    private void Step_AssertHistory(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_NewLeaves.Num(), 3, "three leaf changes: the first plan, the settle, the unsettle");
        if (_NewLeaves.Num() == 3)
        {
            Assert_True(ck::Is_NOT_Valid(_OldLeaves[0]) && _NewLeaves[0] == UMars_GoapAction_Crawler_Roam, "the first plan chose Roam");
            Assert_True(ck::Is_NOT_Valid(_OldLeaves[2]) && _NewLeaves[2] == UMars_GoapAction_Crawler_Roam, "the unsettle chose Roam again");
        }
    }
}
