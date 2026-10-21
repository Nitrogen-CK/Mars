// One wrong commit, then the answer: the lock solves, asserts its output, locks the dials, cuts the live vent pulse and
// spawns the two rewards still at stake (Cog, Ration), once. A later commit is ignored (no vent, no second payout), and a
// step on a locked dial is dropped.
class UMars_AutoTest_Bellkeeper_RightCommitPaysTheRemainingRewardsOnce : UMars_AutoTestRig_Bellkeeper
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddLock(InHandle);

        Add_Step("commit the starting dials (wrong)", n"Step_WrongCommit");
        Add_Step_WaitUntil("the commit is judged", n"Check_Failed", k_SlowPolls, 0);
        Add_Step("set the answer while the vent pulse runs", n"Step_SetAnswer");
        Add_Step_WaitUntil("the dials settle", n"Check_Drained", k_SlowPolls, 0);
        Add_Step("commit the answer", n"Step_RightCommit");
        Add_Step_WaitUntil("the lock solves", n"Check_Solved", k_SlowPolls, 0);
        Add_Step("output up, vent cut, dials locked, two rewards; commit again and turn a dial", n"Step_AssertSolvedThenPoke");
        Add_Step_WaitSeconds("let a second payout or a vent show", 0.5f);
        Add_Step("still one payout of two, no vent, the dial unmoved", n"Step_AssertIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_WrongCommit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NothingSourcesTheRigChannels(InHandle);
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_Failed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailedRemaining.Num() == 1);
    }

    UFUNCTION()
    private void Step_SetAnswer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Request_SetDials(Get_Answer());
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDrained());
    }

    UFUNCTION()
    private void Step_RightCommit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Bellkeeper.Get_IsVenting(), "the wrong commit's pulse is still running");
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_Solved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Solved == 1 && Get_IsDrained());
    }

    UFUNCTION()
    private void Step_AssertSolvedThenPoke(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Bellkeeper.Get_IsSolved(), "solved");
        Assert_True(_OutputSource.Get_IsAsserted(), "the output source is asserted");
        Assert_False(_Bellkeeper.Get_IsVenting(), "solving cut the vent pulse");
        Assert_False(_VentSource.Get_IsAsserted(), "the vent source is down");

        for (const auto& Dial : _Dials)
        { Assert_True(Dial.Get_IsLocked(), "every dial is locked"); }

        const auto Rewards = _Bellkeeper.Get_RewardHandles();
        Assert_Equals_Int(Rewards.Num(), 2, "one failure cost the first reward; the other two are paid");
        for (const auto& Reward : Rewards)
        { Assert_True(ck::IsValid(Reward), "each paid reward spawned"); }

        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
        _Dials[0].Request_Step(FMars_Request_Dial_Step(1));
    }

    UFUNCTION()
    private void Step_AssertIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Solved, 1, "solved once");
        Assert_Equals_Int(_Bellkeeper.Get_RewardHandles().Num(), 2, "no second payout");
        Assert_Equals_Int(_FailedRemaining.Num(), 1, "the commit after solving is not a failure");
        Assert_False(_VentSource.Get_IsAsserted(), "no vent after solving");
        Assert_Equals_Int(_Dials[0].Get_Index(), Get_Answer()[0], "a locked dial does not turn");
    }
}
