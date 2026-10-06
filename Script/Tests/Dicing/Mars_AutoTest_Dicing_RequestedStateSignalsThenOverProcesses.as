// RequestedState = CoarseChop with one chop per state: the first aligned chop reaches the requested texture
// (OnRequestedStateReached, Get_HasReachedRequested), two more over-process it to FineFlecks then GreenPaste, and a fourth
// leaves the pile at GreenPaste while still resolving aligned.
class UMars_AutoTest_Dicing_RequestedStateSignalsThenOverProcesses : UMars_AutoTestRig_Dicing
{
    private int32 _RequestedReached = 0;
    private bool _HasReachedAfterFirst = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Dicing_Spec();
        Spec.RequestedState = EMars_Dicing_State::CoarseChop;
        Spec.ChopsPerState = 1;
        BuildStation(InHandle, Spec);

        _Dicing.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolvedLatchingReached"));
        _Dicing.BindTo_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
        _Dicing.BindTo_OnRequestedStateReached(FMars_Delegate_Dicing_OnRequestedStateReached(this, n"OnRequestedStateReached"));

        Add_Step("the pile has not reached the requested texture", n"Step_AssertNotReached");
        for (int32 Index = 0; Index < 4; ++Index)
        {
            Add_Step("nudge the hand onto the band", n"Step_AimAtBand");
            Add_Step_WaitUntil("the hand is on the band", n"Check_HandOnBand", 0, 2.0f);
            Add_Step("chop", n"Step_Chop");
            Add_Step_WaitUntil("the chop resolved and the cleaver is back up", n"Check_ChopDone", 0, 2.0f);
        }
        Add_Step("requested once, then over-processed to green paste, where it stays", n"Step_AssertOverProcessed");
        Run_Steps(InHandle);
    }

    // The rig's recorder, plus Get_HasReachedRequested latched as the first chop resolves.
    UFUNCTION()
    private void OnChopResolvedLatchingReached(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        _Resolved.Add(InResult == EMars_Dicing_ChopResult::Aligned);
        if (_Resolved.Num() == 1)
        { _HasReachedAfterFirst = _Dicing.Get_HasReachedRequested(); }
    }

    UFUNCTION()
    private void OnRequestedStateReached(FCk_Handle_Dicing InDicing)
    {
        _RequestedReached += 1;
    }

    UFUNCTION()
    private void Step_AssertNotReached(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Dicing), "the feature composed");
        Assert_False(_Dicing.Get_HasReachedRequested(), "whole leaves has not reached coarse chop");
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _ChopsIssued += 1;
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
    }

    UFUNCTION()
    private void Step_AssertOverProcessed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Resolved.Num(), 4, "four chops resolved");
        for (int32 Index = 0; Index < _Resolved.Num(); ++Index)
        { Assert_True(_Resolved[Index], f"chop {Index + 1} resolved aligned"); }

        Assert_True(_HasReachedAfterFirst, "Get_HasReachedRequested was true once the first chop resolved");
        Assert_Equals_Int(_RequestedReached, 1, "OnRequestedStateReached fired once, on coarse chop");

        Assert_Equals_Int(_States.Num(), 3, "three state changes: coarse chop, fine flecks, green paste");
        if (_States.Num() == 3)
        {
            Assert_True(_States[0] == EMars_Dicing_State::CoarseChop, f"first change is coarse chop (got {_States[0] :n})");
            Assert_True(_States[1] == EMars_Dicing_State::FineFlecks, f"second change is fine flecks (got {_States[1] :n})");
            Assert_True(_States[2] == EMars_Dicing_State::GreenPaste, f"third change is green paste (got {_States[2] :n})");
        }

        const auto MaterialState = _Dicing.Get_MaterialState();
        Assert_True(MaterialState == EMars_Dicing_State::GreenPaste,
            f"the pile stays green paste after the fourth chop (got {MaterialState :n})");
        Assert_True(_Dicing.Get_HasReachedRequested(), "an over-processed pile still counts as having reached the request");
        Assert_Equals_Int(_Dicing.Get_UsefulChops(), 4, "all four chops were useful");
    }
}
