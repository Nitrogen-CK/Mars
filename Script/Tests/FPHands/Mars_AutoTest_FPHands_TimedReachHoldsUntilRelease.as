// A timed reach holds: the phase goes to Hold and stays there with no timer moving it on, then a Release request runs
// Hold -> Release -> None.
class UMars_AutoTest_FPHands_TimedReachHoldsUntilRelease : UCk_AutoTest_Base
{
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_StateMachine _Sm;
    private FCk_Handle _Player;
    private TArray<EMars_FPHands_Phase> _Phases;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Player = InHandle;
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.2f;
        Spec.Reach.Grab.GripSeconds = 0.2f;
        Spec.Reach.Grab.BackSeconds = 0.2f;
        Spec.Reach.Hold.ReleaseSeconds = 0.2f;

        Spec.HandNode = HandNode.As_Transform();
        _Hands = utils_fphands::Add(_Player, Spec);
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request a timed reach", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the phase is Hold", n"Check_IsHold", 0, 5.0f);
        Add_Step_WaitSeconds("hold for longer than any phase timer", 0.6f);
        Add_Step("the phase is still Hold", n"Step_AssertStillHold");
        Add_Step("request a second timed reach while holding", n"Step_RequestTimedReach");
        Add_Step_WaitSeconds("let the drain run", 0.1f);
        Add_Step("a reach requested mid-Hold is ignored", n"Step_AssertHoldIgnoresReach");
        Add_Step_WaitUntil("the Hold state listens for a lost target", n"Check_HoldListening", 0, 5.0f);
        Add_Step("request a release", n"Step_RequestRelease");
        Add_Step_WaitUntil("the phase is back to None", n"Check_IsNone", 0, 5.0f);
        Add_Step("the phases ran Hold, Release, None", n"Step_AssertSequence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        _Phases.Add(InNew);
    }

    UFUNCTION()
    private void Check_RestListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_RequestTimedReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(ECk_Interaction_CompletionPolicy::Timed));
    }

    UFUNCTION()
    private void Check_IsHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold);
    }

    UFUNCTION()
    private void Step_AssertStillHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold, f"the phase is still Hold after 0.6s (got {_Hands.Get_Phase() :n})");
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Hold, "the Hands SM is still in Hold");
    }

    UFUNCTION()
    private void Step_AssertHoldIgnoresReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold, f"the phase is still Hold after a second reach request (got {_Hands.Get_Phase() :n})");
    }

    UFUNCTION()
    private void Check_HoldListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_RequestRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_Release();
    }

    UFUNCTION()
    private void Check_IsNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Phases.Num() >= 3 && _Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Phases.Num(), 3, "three phase changes");
        if (_Phases.Num() != 3)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, f"first change is to Hold (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::Release, f"second change is to Release (got {_Phases[1] :n})");
        Assert_True(_Phases[2] == EMars_FPHands_Phase::None, f"third change is back to None (got {_Phases[2] :n})");
    }
}
