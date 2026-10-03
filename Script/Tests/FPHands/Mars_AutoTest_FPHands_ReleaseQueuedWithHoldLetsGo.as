// A Release queued in the same frame as SetPhase(Hold), while the committed phase is not yet Hold (the Hold state's
// enter request and a lost target landing in one drain), lets go: the drain applies the phase first and the release
// then sees Hold. The Hands SM is put in Hold by a timed reach, the committed phase is moved back to None under it, and
// SetPhase(Hold) and Release are queued together.
class UMars_AutoTest_FPHands_ReleaseQueuedWithHoldLetsGo : UCk_AutoTest_Base
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
        // A release long enough that the Hands SM is still in Release when the sequence is asserted.
        Spec.Reach.Hold.ReleaseSeconds = 1.0f;

        Spec.HandNode = HandNode.As_Transform();
        _Hands = utils_fphands::Add(_Player, Spec);
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request a timed reach", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the phase is Hold and the Hold state listens for a lost target", n"Check_HoldListening", 0, 5.0f);
        Add_Step("move the committed phase back to None under the Hold state", n"Step_RequestPhaseNone");
        Add_Step_WaitUntil("the phase is None while the Hands SM is still in Hold", n"Check_NoneUnderHold", 0, 5.0f);
        Add_Step("queue SetPhase(Hold) and Release in the same frame", n"Step_RequestHoldAndRelease");
        Add_Step_WaitUntil("the phase leaves Hold for Release", n"Check_IsRelease", 0, 5.0f);
        Add_Step("the queued Hold was applied, then let go", n"Step_AssertSequence");
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
    private void Check_HoldListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold
            && utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Hold
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_RequestPhaseNone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetPhase(FMars_Request_FPHands_SetPhase(EMars_FPHands_Phase::None));
    }

    UFUNCTION()
    private void Check_NoneUnderHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None
            && utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Hold);
    }

    UFUNCTION()
    private void Step_RequestHoldAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Phases.Empty();
        _Hands.Request_SetPhase(FMars_Request_FPHands_SetPhase(EMars_FPHands_Phase::Hold));
        _Hands.Request_Release();
    }

    UFUNCTION()
    private void Check_IsRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Release);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Release, "the Hands SM left Hold for Release");

        Assert_Equals_Int(_Phases.Num(), 2, "two phase changes after the queued pair");
        if (_Phases.Num() != 2)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, f"first change is to Hold (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::Release, f"second change is to Release (got {_Phases[1] :n})");
    }
}
