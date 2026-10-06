// The player's ManipulateControl task holds the camera still from the moment a lever's interaction starts, not only once
// the gloves grip it: a look drag during the reach must not turn the view off the lever. A pending interaction cancelled
// before any grip hands the orientation control back. The camera is a headless director on a CkTests camera helper
// actor, with a PlayerViewpoint on the test entity pointing at it. The gloves' timed reach is slowed to 2 s so the
// cancel always lands before the grip (and before the task's 1 s grip-wait fallback).
class UMars_AutoTest_Control_PendingGripFreezesCamera : UMars_AutoTestRig_LeverThroughPlayer
{
    private ACkAutoTest_GameplayCamera_Helper _CameraHelper;
    private FCk_Handle_Transform _CameraOwner;
    private FCk_Handle_Camera _Camera;
    private bool _SawManipulation = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _CameraHelper = Cast<ACkAutoTest_GameplayCamera_Helper>(SpawnActor(
            ACkAutoTest_GameplayCamera_Helper, FVector::ZeroVector, FRotator::ZeroRotator));
        if (ck::Is_NOT_Valid(_CameraHelper))
        {
            FinishFailure("failed to spawn the camera helper actor");
            return;
        }

        utils_pending_entity_script::Promise_OnConstructed(
            _CameraHelper.PendingEntity, FCk_Delegate_EntityScript_Constructed(this, n"OnCameraHelperReady"));

        auto HandsSpec = FMars_FPHands_Spec();
        HandsSpec.Reach.Hold.ReachSeconds = 2.0f;
        BuildPlayerAndLever(InHandle, HandsSpec);

        Add_Step_WaitUntil("the camera helper's entity is constructed", n"Check_CameraOwnerReady", 0, 5.0f);
        Add_Step("compose the camera, the viewpoint and the rig SM", n"Step_ComposeRig");
        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 5.0f);
        Add_Step("the view is free before any interaction; add the lever and open Use", n"Step_AssertViewFreeAndUseLever");
        Add_Step_WaitUntil("the lever's interaction started", n"Check_InteractionStarted", 0, 5.0f);
        Add_Step("the view is held while the gloves are still reaching; cancel before the grip", n"Step_AssertFrozenThenCancel");
        Add_Step_WaitUntil("the view is free again", n"Check_ViewFree", 0, 2.0f);
        Add_Step("the lever was never manipulated", n"Step_AssertNeverManipulated");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnCameraHelperReady(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave it alive into later tests.
        Track_ForCleanup(InEntityScriptHandle);
        _CameraOwner = InEntityScriptHandle.As_Transform();
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
        if (ck::Is_NOT_Valid(_Camera))
        {
            FinishFailure("the camera director did not compose headless");
            return;
        }

        ViewpointSpec.Camera = _Camera;
        utils_player_viewpoint::Add(_Player, ViewpointSpec);
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));
    }

    UFUNCTION()
    private void Step_AssertViewFreeAndUseLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_HasOrientationControl(), "the view is free before any interaction");
        UseLever();
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

    // Read from the camera's live state (Request_Set_HasOrientationControl writes it immediately).
    private bool Get_HasOrientationControl() const
    {
        return _Camera.Get_Profile().Get_HasOrientationControl();
    }
}
