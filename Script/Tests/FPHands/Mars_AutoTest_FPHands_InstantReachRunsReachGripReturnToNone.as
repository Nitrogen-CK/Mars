// An instant reach runs the Hands sub-SM Rest -> Reach -> Grip -> Return -> Rest: the feature's phase goes Reach, Grip,
// Return, None in that order, and every change resets PhaseTime. The test entity carries FPHands and the Hands state
// machine; the reach is a bare one (no interactable), which the requests processor turns into a hand-node reach.
class UMars_AutoTest_FPHands_InstantReachRunsReachGripReturnToNone : UCk_AutoTest_Base
{
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_StateMachine _Sm;
    private FCk_Handle _Player;
    private TArray<EMars_FPHands_Phase> _Phases;
    private TArray<float32> _PhaseTimesAtChange;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Player = InHandle;
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.GrabOutSeconds = 0.2f;
        Spec.Reach.GrabGripSeconds = 0.2f;
        Spec.Reach.GrabBackSeconds = 0.2f;
        Spec.Reach.ReleaseSeconds = 0.2f;

        _Hands = utils_fphands::Add(_Player, Spec, HandNode.As_Transform());
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request an instant reach", n"Step_RequestInstantReach");
        Add_Step_WaitUntil("the phase went through Reach, Grip, Return back to None", n"Check_BackToNone", 0, 5.0f);
        Add_Step("the phases ran in order and each change reset PhaseTime", n"Step_AssertSequence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        _Phases.Add(InNew);
        _PhaseTimesAtChange.Add(InHands.Get_PhaseTime());
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
    private void Step_RequestInstantReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FCk_Handle_InteractTarget(), FCk_Handle_Interactable(), _Player, true));
    }

    UFUNCTION()
    private void Check_BackToNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Phases.Num() >= 4 && _Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Phases.Num(), 4, "four phase changes");
        if (_Phases.Num() != 4)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Reach, "first change is to Reach");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::Grip, "second change is to Grip");
        Assert_True(_Phases[2] == EMars_FPHands_Phase::Return, "third change is to Return");
        Assert_True(_Phases[3] == EMars_FPHands_Phase::None, "fourth change is back to None");

        for (int32 Index = 0; Index < _PhaseTimesAtChange.Num(); ++Index)
        { Assert_True(_PhaseTimesAtChange[Index] < 0.05f, f"PhaseTime was reset at change {Index}"); }
    }
}
