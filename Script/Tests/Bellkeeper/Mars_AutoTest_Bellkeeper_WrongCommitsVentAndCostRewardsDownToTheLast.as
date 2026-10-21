// Three wrong commits on a three-reward lock: each asserts the vent source for the pulse and then lets it go, the dials
// keep the attempt, and the rewards left go 3 -> 2 -> 1 -> 1: the last is never lost.
class UMars_AutoTest_Bellkeeper_WrongCommitsVentAndCostRewardsDownToTheLast : UMars_AutoTestRig_Bellkeeper
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddLock(InHandle);

        Add_Step("set a wrong combination and commit", n"Step_FirstWrongCommit");
        Add_Step_WaitUntil("the commit is judged", n"Check_FirstFailed", k_SlowPolls, 0);
        Add_Step("one failure, two rewards left, venting, the dials kept", n"Step_AssertFirstFailure");
        Add_Step_WaitUntil("the vent pulse ends", n"Check_VentEnded", k_SlowPolls, 0);
        Add_Step("the vent source is down; commit twice more, a frame apart", n"Step_SecondWrongCommit");
        Add_Step_WaitUntil("the second commit is judged", n"Check_SecondFailed", k_SlowPolls, 0);
        Add_Step("commit a third wrong time", n"Step_ThirdWrongCommit");
        Add_Step_WaitUntil("the third commit is judged", n"Check_ThirdFailed", k_SlowPolls, 0);
        Add_Step("three failures, rewards 2 -> 1 -> 1, still venting, never solved", n"Step_AssertFloor");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_FirstWrongCommit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NothingSourcesTheRigChannels(InHandle);
        Assert_Equals_Int(_Bellkeeper.Get_RemainingRewards(), 3, "all three rewards at stake");

        TArray<int32> Wrong;
        Wrong.Add(1);
        Wrong.Add(2);
        Wrong.Add(4);
        Request_SetDials(Wrong);
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_FirstFailed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailedRemaining.Num() == 1 && Get_IsDrained());
    }

    UFUNCTION()
    private void Step_AssertFirstFailure(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Bellkeeper.Get_FailedCommits(), 1, "one failure");
        Assert_Equals_Int(_FailedRemaining[0], 2, "the signal reports two rewards left");
        Assert_True(_Bellkeeper.Get_IsVenting(), "the vent pulse runs");
        Assert_True(_VentSource.Get_IsAsserted(), "the vent source is asserted");
        Assert_False(_OutputSource.Get_IsAsserted(), "the lock stays shut");

        const auto Indices = Get_DialIndices();
        Assert_Equals_Int(Indices[0], 1, "dial 0 keeps the attempt");
        Assert_Equals_Int(Indices[1], 2, "dial 1 keeps the attempt");
        Assert_Equals_Int(Indices[2], 4, "dial 2 keeps the attempt");
    }

    UFUNCTION()
    private void Check_VentEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bellkeeper.Get_IsVenting() == false && _VentSource.Get_IsAsserted() == false);
    }

    UFUNCTION()
    private void Step_SecondWrongCommit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_SecondFailed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailedRemaining.Num() == 2);
    }

    UFUNCTION()
    private void Step_ThirdWrongCommit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_ThirdFailed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailedRemaining.Num() == 3);
    }

    UFUNCTION()
    private void Step_AssertFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Bellkeeper.Get_FailedCommits(), 3, "three failures, uncapped");
        Assert_Equals_Int(_FailedRemaining[1], 1, "the second costs the second reward");
        Assert_Equals_Int(_FailedRemaining[2], 1, "the third costs nothing: the last reward is kept");
        Assert_Equals_Int(_Bellkeeper.Get_RemainingRewards(), 1, "one reward left");
        Assert_True(_VentSource.Get_IsAsserted(), "a later wrong commit still vents");
        Assert_Equals_Int(_Solved, 0, "never solved");
        Assert_False(_Bellkeeper.Get_IsSolved(), "not solved");
    }
}
