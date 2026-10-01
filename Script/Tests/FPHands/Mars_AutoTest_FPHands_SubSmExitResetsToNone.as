// Leaving the Hands state machine does not touch the phase (no state is entered, so nothing requests one): stopping it
// mid-Hold leaves the phase at Hold. Starting it again re-enters Rest, whose enter task puts the phase back to None -
// what re-entering Alive does to the gloves.
class UMars_AutoTest_FPHands_SubSmExitResetsToNone : UCk_AutoTest_Base
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
        Spec.Reach.GrabOutSeconds = 0.2f;
        Spec.Reach.GrabGripSeconds = 0.2f;
        Spec.Reach.GrabBackSeconds = 0.2f;
        Spec.Reach.ReleaseSeconds = 0.2f;

        _Hands = utils_fphands::Add(_Player, Spec, HandNode.As_Transform());
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request a timed reach", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the phase is Hold", n"Check_IsHold", 0, 5.0f);
        Add_Step("stop the Hands state machine", n"Step_StopSm");
        Add_Step_WaitUntil("the Hands state machine is stopped", n"Check_SmStopped", 0, 5.0f);
        Add_Step("the phase is still Hold: exiting requests no phase", n"Step_AssertStillHold");
        Add_Step("start the Hands state machine again", n"Step_StartSm");
        Add_Step_WaitUntil("the phase is None", n"Check_IsNone", 0, 5.0f);
        Add_Step("the phases ran Hold, None", n"Step_AssertSequence");
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
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FCk_Handle_InteractTarget(), FCk_Handle_Interactable(), _Player, false));
    }

    UFUNCTION()
    private void Check_IsHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold);
    }

    UFUNCTION()
    private void Step_StopSm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_state_machine::Request_Stop(_Sm);
    }

    UFUNCTION()
    private void Check_SmStopped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_RunStatus(_Sm) == ECk_SmRunStatus::Stopped);
    }

    UFUNCTION()
    private void Step_AssertStillHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold, "the phase is still Hold once the state machine stopped");
    }

    UFUNCTION()
    private void Step_StartSm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_state_machine::Request_Start(_Sm);
    }

    UFUNCTION()
    private void Check_IsNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest, "the restarted state machine is in Rest");

        Assert_Equals_Int(_Phases.Num(), 2, "two phase changes");
        if (_Phases.Num() != 2)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, "first change is to Hold");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::None, "second change is back to None");
    }
}
