// The player's ManipulateControl task holds the camera still from the moment a lever's interaction starts, not only once
// the gloves grip it: a look drag during the reach must not turn the view off the lever. A pending interaction cancelled
// before any grip hands the orientation control back. Rig: T3's (Mars_AutoTest_Control_ManipulationWaitsForTheGrip: the
// ManuallyCompleted lever, hands + resolver on the test entity, UMars_AutoTestState_ManipulateControlRig) plus a headless
// camera director on a CkTests camera helper actor and a PlayerViewpoint on the test entity pointing at it. The gloves'
// timed reach is slowed to 2 s so the cancel always lands before the grip (and before the task's 1 s grip-wait fallback).
class UMars_AutoTest_Control_PendingGripFreezesCamera : UCk_AutoTest_Base
{
    private ACkAutoTest_GameplayCamera_Helper _CameraHelper;
    private FCk_Handle_Transform _CameraOwner;
    private FCk_Handle_Camera _Camera;
    private FCk_Handle_Control _Control;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle _Player;
    private bool _SawManipulation = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Player = InHandle;

        _CameraHelper = Cast<ACkAutoTest_GameplayCamera_Helper>(SpawnActor(
            ACkAutoTest_GameplayCamera_Helper, FVector::ZeroVector, FRotator::ZeroRotator));
        if (ck::IsValid(_CameraHelper))
        {
            utils_pending_entity_script::Promise_OnConstructed(
                _CameraHelper.PendingEntity, FCk_Delegate_EntityScript_Constructed(this, n"OnCameraHelperReady"));
        }

        auto HandRootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto HandRoot = utils_transform::Add(HandRootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(HandRoot, FTransform::Identity);

        auto HandsSpec = FMars_FPHands_Spec();
        HandsSpec.Reach.HoldReachSeconds = 2.0f;
        _Hands = utils_fphands::Add(_Player, HandsSpec, HandNode.As_Transform());
        _Resolver = utils_interaction_resolver::Add(_Player, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        BuildLever(InHandle);

        Add_Step_WaitUntil("the camera helper's entity is constructed", n"Check_CameraOwnerReady", 0, 5.0f);
        Add_Step("compose the camera, the viewpoint and the rig SM", n"Step_ComposeRig");
        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 5.0f);
        Add_Step("the view is free before any interaction; add the lever and open Use", n"Step_UseLever");
        Add_Step_WaitUntil("the lever's interaction started", n"Check_InteractionStarted", 0, 5.0f);
        Add_Step("the view is held while the gloves are still reaching; cancel before the grip", n"Step_AssertFrozenThenCancel");
        Add_Step_WaitUntil("the view is free again", n"Check_ViewFree", 0, 2.0f);
        Add_Step("the lever was never manipulated", n"Step_AssertNeverManipulated");
        Run_Steps(InHandle);
    }

    private FCk_InteractionResolver_Spec Make_ResolverSpec()
    {
        auto Channels = TArray<FGameplayTag>();
        Channels.Add(GameplayTags::InteractionChannel_Mars_Use);

        // The test entity has no transform: no distance sort.
        auto Mapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, Channels);
        Mapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(Mapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    private void BuildLever(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandleNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndRotation = FRotator(70.0, 0.0, 0.0);
        MoverSpec.Duration = 0.3f;
        auto Mover = utils_mover::Add(HandleNode, MoverSpec);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        _Control = utils_control::Add(RootEntity, ControlSpec, Mover);

        // No ProbeInfo: a transform-only child; the reach resolves as a point grip at the owner.
        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(_Control.Make_InteractTarget(FText::FromString("Pull")));
        auto Interactable = utils_interactable::Create(Root, Spec);
        _Target = Interactable.Get_AllInteractTargets()[0];
    }

    UFUNCTION()
    private void OnCameraHelperReady(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave it alive into later tests.
        Track_ForCleanup(FCk_Handle(InEntityScriptHandle));
        _CameraOwner = FCk_Handle(InEntityScriptHandle).As_Transform();
    }

    UFUNCTION()
    private void Check_CameraOwnerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_CameraOwner));
    }

    // The viewpoint must exist before the SM starts: ManipulateControl reads the camera on enter.
    UFUNCTION()
    private void Step_ComposeRig(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto ViewpointSpec = FMars_PlayerViewpoint_Spec();
        auto CameraSpec = FCk_Camera_Spec(_CameraHelper.CameraComponent);
        CameraSpec.Set_Profile(utils_player_viewpoint::Make_CameraProfile(ViewpointSpec));
        _Camera = utils_camera::Add(_CameraOwner, CameraSpec);
        Assert_True(ck::IsValid(_Camera), "the camera director composed headless");

        utils_player_viewpoint::Add(_Player, _Camera, ViewpointSpec);
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));
    }

    UFUNCTION()
    private void Check_HandsRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_UseLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_HasOrientationControl(), "the view is free before any interaction");

        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Use));
    }

    UFUNCTION()
    private void Check_InteractionStarted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_Manipulation();

        auto Res = OutResult;
        Res.Set(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Player)));
    }

    // One step after the interaction appeared: its OnNewInteraction has been broadcast whatever the processor order.
    UFUNCTION()
    private void Step_AssertFrozenThenCancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Record_Manipulation();

        Assert_False(_Hands.Get_IsGrippingTarget(_Target),
            f"the gloves are still reaching (phase {_Hands.Get_Phase() :n}, alpha {_Hands.Get_ReachAlpha()})");
        Assert_False(_Control.Get_IsManipulating(), "the manipulation has not begun");
        Assert_False(Get_HasOrientationControl(), "the view is held from the interaction's start, before the grip");

        _Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
    }

    UFUNCTION()
    private void Check_ViewFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_Manipulation();

        auto Res = OutResult;
        Res.Set(Get_HasOrientationControl());
    }

    UFUNCTION()
    private void Step_AssertNeverManipulated(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Record_Manipulation();

        Assert_False(_SawManipulation, "the cancelled pending interaction never began a manipulation");
        Assert_False(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Player)), "the interaction is gone");
    }

    private void Record_Manipulation()
    {
        if (ck::IsValid(_Control) && _Control.Get_IsManipulating())
        { _SawManipulation = true; }
    }

    // Assembled from the camera's live state (Request_Set_HasOrientationControl writes it immediately).
    private bool Get_HasOrientationControl() const
    {
        if (ck::Is_NOT_Valid(_Camera))
        { return false; }

        return _Camera.Get_Profile().Get_HasOrientationControl();
    }
}
