// The FPHands tests' rig: FPHands on the test entity (the player) with its hand node on a transform root of its own at
// the origin, the Hands state machine, and a log of the phases the gloves run.
UCLASS(Abstract)
class UMars_AutoTestRig_Hands : UCk_AutoTest_Base
{
    protected FCk_Handle_FPHands _Hands;
    protected FCk_Handle_StateMachine _Sm;
    protected FCk_Handle _Player;
    protected TArray<EMars_FPHands_Phase> _Phases;

    // FPHands on InPlayer with InSpec, the hand node on a fresh root at the origin; returns that root.
    protected FCk_Handle_Transform Add_Hands(FCk_Handle InPlayer, FMars_FPHands_Spec InSpec)
    {
        _Player = InPlayer;
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InPlayer);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto Spec = InSpec;
        Spec.HandNode = HandNode.As_Transform();
        _Hands = utils_fphands::Add(_Player, Spec);
        return Root;
    }

    protected void Add_HandsSm()
    {
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));
    }

    // Appends every phase change from here on to _Phases.
    protected void Log_Phases()
    {
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));
    }

    UFUNCTION()
    protected void OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        _Phases.Add(InNew);
    }

    UFUNCTION()
    protected void Check_RestListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    protected void Check_RestListeningForPush(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPushRequested._Inner.IsBound());
    }

    UFUNCTION()
    protected void Step_RequestTimedReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(ECk_Interaction_CompletionPolicy::Timed));
    }

    UFUNCTION()
    protected void Step_RequestRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_Release();
    }

    UFUNCTION()
    protected void Check_IsHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold);
    }

    UFUNCTION()
    protected void Check_IsRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Release);
    }
}
