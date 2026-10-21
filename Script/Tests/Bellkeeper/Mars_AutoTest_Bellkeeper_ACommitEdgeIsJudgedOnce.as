// A rising edge on the lock's own sink is one commit and a falling edge is none; two commits requested in one frame are
// judged once. The edges are fed straight to the sink, so no mechanism driver or chain is involved.
class UMars_AutoTest_Bellkeeper_ACommitEdgeIsJudgedOnce : UMars_AutoTestRig_Bellkeeper
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddLock(InHandle);

        Add_Step_WaitUntil("the link is set up (the sink's rising-edge signal is bound)", n"Check_LinkBound", 0, 0);
        Add_Step("a rising edge on the commit channel", n"Step_RisingEdge");
        Add_Step_WaitUntil("the edge commits", n"Check_OneFailure", k_SlowPolls, 0);
        Add_Step("a falling edge on the commit channel", n"Step_FallingEdge");
        Add_Step_WaitSeconds("let the sink drain it", 0.3f);
        Add_Step("still one failure; request two commits in one frame", n"Step_DoubleCommit");
        Add_Step_WaitUntil("the lock drains", n"Check_Drained", k_SlowPolls, 0);
        Add_Step("two failures in all", n"Step_AssertTwo");
        Run_Steps(InHandle);
    }

    private FCk_Handle_MechanismSink Get_Sink() const
    {
        return _Entity.As_MechanismSink();
    }

    UFUNCTION()
    private void Check_LinkBound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Sink = Get_Sink();
        auto Res = OutResult;
        Res.Set(_Bellkeeper.Has_Fragment(FMars_Tag_Bellkeeper_NeedsSetup) == false
            && Sink.Has_Fragment(FMars_Fragment_MechanismSink_Signals)
            && Sink.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnInputRose._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_RisingEdge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NothingSourcesTheRigChannels(InHandle);

        auto Sink = Get_Sink();
        Sink.Request_NotifyInputEdge(FMars_Request_MechanismSink_NotifyInputEdge(GameplayTags::Mechanism_Channel_J, EMars_MechanismSource_Output::Asserted));
    }

    UFUNCTION()
    private void Check_OneFailure(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailedRemaining.Num() >= 1);
    }

    UFUNCTION()
    private void Step_FallingEdge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Sink = Get_Sink();
        Sink.Request_NotifyInputEdge(FMars_Request_MechanismSink_NotifyInputEdge(GameplayTags::Mechanism_Channel_J, EMars_MechanismSource_Output::Deasserted));
    }

    UFUNCTION()
    private void Step_DoubleCommit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Bellkeeper.Get_FailedCommits(), 1, "a rising edge is one commit and a falling edge none");
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDrained() && _FailedRemaining.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Bellkeeper.Get_FailedCommits(), 2, "two commits in one frame are judged once");
        Assert_Equals_Int(_FailedRemaining.Num(), 2, "two failure signals");
    }
}
