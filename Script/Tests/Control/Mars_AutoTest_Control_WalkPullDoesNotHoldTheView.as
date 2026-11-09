// The player's ManipulateControl task on a Walk lever holds no view at all: from Use through the gloves' grip, the walk and
// the threshold, the viewpoint never carries the ControlPull hold and the camera keeps its orientation control - the
// player has to look and walk. The grip's Puller is the player's own transform (its root is what walks), and walking it
// back past WalkCm ends the interaction Succeeded. The test entity gets a transform for that, 60 cm out on the lever's -X;
// the camera is the headless director of UMars_AutoTest_Control_PendingGripFreezesCamera.
class UMars_AutoTest_Control_WalkPullDoesNotHoldTheView : UMars_AutoTestRig_LeverThroughPlayer
{
    default _PullSource = EMars_Control_PullSource::Walk;
    default _TimeoutSeconds = 15.0f;

    private ACkAutoTest_GameplayCamera_Helper _CameraHelper;
    private FCk_Handle_Transform _CameraOwner;
    private FCk_Handle_Camera _Camera;
    private FCk_Handle_PlayerViewpoint _Viewpoint;
    private FCk_Handle_Transform _PlayerRoot;
    private bool _SawViewHeld = false;

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

        auto PlayerEntity = InHandle;
        _PlayerRoot = utils_transform::Add(PlayerEntity, FTransform(FRotator::ZeroRotator, Get_PullerLocation(0.0)),
            ECk_Replication::DoesNotReplicate);
        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());

        Add_Step_WaitUntil("the camera helper's entity is constructed", n"Check_CameraOwnerReady", 0, 0);
        Add_Step("compose the camera, the viewpoint and the rig SM", n"Step_ComposeRig");
        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 0);
        Add_Steps_UseRowLive();
        Add_Step("the view is free before any interaction; offer the lever and press Use", n"Step_AssertViewFreeAndUseLever");
        Add_Step_WaitUntil("the gloves grip and the lever is manipulated", n"Check_ManipulatingWatchingTheView", k_SlowPolls, 0);
        Add_Step("gripped: the player is the puller and the view is free; walk back past WalkCm", n"Step_AssertGrippedFreeAndWalk");
        Add_Step_WaitUntil("the interaction finishes", n"Check_FinishedWatchingTheView", k_SlowPolls, 0);
        Add_Step("the walk ended it Succeeded and the view was never held", n"Step_AssertNeverHeld");
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the Use row releases", n"Check_UseReleased", 0, 0);
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

    // The viewpoint must exist before the SM starts: ManipulateControl reads it on enter.
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
        _Viewpoint = utils_player_viewpoint::Add(_Player, ViewpointSpec);
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));
    }

    UFUNCTION()
    private void Step_AssertViewFreeAndUseLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_HasOrientationControl(), "the view is free before any interaction");
        UseLever();
    }

    UFUNCTION()
    private void Check_ManipulatingWatchingTheView(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_ViewHeld();

        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating());
    }

    UFUNCTION()
    private void Step_AssertGrippedFreeAndWalk(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Record_ViewHeld();

        Assert_True(_Hands.Get_IsGrippingTarget(_Target), "the gloves grip the lever");
        Assert_True(_Control.TryGet_Puller() == _PlayerRoot, "the player's own transform is the puller");
        Assert_False(_Viewpoint.Get_IsViewHeldBy(EMars_PlayerViewpoint_ViewHolder::ControlPull), "no ControlPull hold while gripped");
        Assert_True(Get_HasOrientationControl(), "the camera keeps its orientation control while gripped");

        utils_transform::Request_SetLocation(_PlayerRoot, FCk_Request_Transform_SetLocation(Get_PullerLocation(1.3f * _WalkCm)));
    }

    UFUNCTION()
    private void Check_FinishedWatchingTheView(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_ViewHeld();

        auto Res = OutResult;
        Res.Set(_FinishedResults.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertNeverHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Record_ViewHeld();

        const auto Result = _FinishedResults[0];
        Assert_True(Result == ECk_SucceededFailed::Succeeded, f"walking the player back past WalkCm ends the interaction Succeeded (got {Result :n})");
        Assert_False(_SawViewHeld, "the view was never held from Use to the threshold");
        Assert_True(Get_HasOrientationControl(), "the view is free with Use still held");
    }

    private void Record_ViewHeld()
    {
        if (ck::IsValid(_Viewpoint) && _Viewpoint.Get_IsViewHeldBy(EMars_PlayerViewpoint_ViewHolder::ControlPull))
        { _SawViewHeld = true; }

        if (ck::IsValid(_Camera) && Get_HasOrientationControl() == false)
        { _SawViewHeld = true; }
    }

    // Read from the camera's live state (the viewpoint's hold drain writes it).
    private bool Get_HasOrientationControl() const
    {
        return _Camera.Get_Profile().Get_HasOrientationControl();
    }
}
