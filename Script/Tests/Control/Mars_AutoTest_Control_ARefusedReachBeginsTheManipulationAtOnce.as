// A refused reach begins the manipulation at once. Through the player's tasks (the lever offered to the resolver, Use
// pressed), the gloves are already busy holding something else (a bare Hold reach), so they refuse the reach the player's
// ManipulateControl asks for the lever: the lever's manipulation begins within a few frames of its interaction's start,
// with the gloves still on their own hold - not after a grip that will never come. Releasing Use ends the pull.
class UMars_AutoTest_Control_ARefusedReachBeginsTheManipulationAtOnce : UMars_AutoTestRig_LeverThroughPlayer
{
    // The gloves answer a reach in the drain after it is asked; the manipulation begins in the frame after that.
    private const int32 k_AtOncePolls = 4;

    private TArray<FCk_Handle_InteractTarget> _RefusedReaches;
    private TArray<EMars_FPHands_ReachRefusal> _RefusalReasons;
    private int32 _Poll = 0;
    private TOptional<int32> _InteractionPoll;
    private TOptional<int32> _ManipulationPoll;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());
        _Hands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnReachRefused"));
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 0);
        Add_Steps_UseRowLive();
        Add_Step("the gloves take a bare hold of their own", n"Step_BusyTheGloves");
        Add_Step_WaitUntil("the gloves hold", n"Check_GlovesHold", 0, 0);
        Add_Step("offer the lever to the resolver and press Use", n"Step_UseLever");
        Add_Step_WaitUntil("the lever is manipulated", n"Check_ManipulatedWatchingTheStart", 0, 0);
        Add_Step("the gloves refused the lever's reach and the manipulation began at once without them; release Use", n"Step_AssertAtOnceAndRelease");
        Add_Step_WaitUntil("the pull ends with the release", n"Check_PullEnded", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_BusyTheGloves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(ECk_Interaction_CompletionPolicy::Timed));
    }

    UFUNCTION()
    private void Check_GlovesHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold);
    }

    UFUNCTION()
    private void OnReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind,
                                EMars_FPHands_ReachRefusal InReason)
    {
        _RefusedReaches.Add(InTarget);
        _RefusalReasons.Add(InReason);
    }

    // One poll a frame: the clock the interaction's start and the manipulation's begin are read on.
    UFUNCTION()
    private void Check_ManipulatedWatchingTheStart(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_Poll;
        if (_InteractionPoll.IsSet() == false && ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Player)))
        { _InteractionPoll = TOptional<int32>(_Poll); }

        if (_ManipulationPoll.IsSet() == false && _Control.Get_IsManipulating())
        { _ManipulationPoll = TOptional<int32>(_Poll); }

        auto Res = OutResult;
        Res.Set(_ManipulationPoll.IsSet());
    }

    UFUNCTION()
    private void Step_AssertAtOnceAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RefusedReaches.Contains(_Target), "the gloves refused the reach for the lever");
        const auto Index = _RefusedReaches.FindIndex(_Target);
        Assert_True(Index >= 0 && _RefusalReasons[Index] == EMars_FPHands_ReachRefusal::Busy,
            "the refusal says the gloves are busy (on their own hold)");
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold && _Hands.Get_IsReachTarget(_Target) == false,
            f"the gloves are still on their own hold (phase {_Hands.Get_Phase() :n})");
        Assert_False(_Hands.Get_IsGrippingTarget(_Target), "the gloves never gripped the lever");

        const auto Started = _InteractionPoll.IsSet() ? _InteractionPoll.GetValue() : _ManipulationPoll.GetValue();
        const auto Waited = _ManipulationPoll.GetValue() - Started;
        Assert_True(Waited <= k_AtOncePolls, f"the manipulation began within {k_AtOncePolls} frames of the interaction's start ({Waited})");

        _UseKey.Release();
    }

    UFUNCTION()
    private void Check_PullEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating() == false && ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _Player)));
    }
}
