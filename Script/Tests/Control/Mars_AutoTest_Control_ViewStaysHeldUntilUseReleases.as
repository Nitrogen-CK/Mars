// A lever pulled past its threshold while the Use row is still held keeps the view held after the interaction finished and
// the manipulation ended: the drag that pulled it must not turn the view the frame it lands (ManipulateControl's default
// ViewLock, UntilUseReleases). Releasing the row hands the view back within two frames. The Use row is a real CkIntent
// level row on the rig's private Use key, on a matcher the player's InputIntents reads; Use is pressed before the lever is
// offered, so the press reaches it through the player's Use task. The camera is the headless director of
// UMars_AutoTest_Control_PendingGripFreezesCamera.
class UMars_AutoTest_Control_ViewStaysHeldUntilUseReleases : UMars_AutoTestRig_LeverThroughPlayer
{
    default _TimeoutSeconds = 15.0f;

    // From the frame the row reads released: the task's tick queues the view release, and the viewpoint's hold drain and
    // the camera's request drain apply it (the first poll is one frame later, so a same-frame hand-back reads 1).
    private const int32 k_MaxFramesToFreeTheView = 2;

    private ACkAutoTest_GameplayCamera_Helper _CameraHelper;
    private FCk_Handle_Transform _CameraOwner;
    private FCk_Handle_Camera _Camera;

    private int64 _UseReleasedFrame = -1;
    private int64 _ViewFreeSeenFrame = -1;

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

        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());

        Add_Step_WaitUntil("the camera helper's entity is constructed", n"Check_CameraOwnerReady", 0, 0);
        Add_Step("compose the camera, the viewpoint and the rig SM", n"Step_ComposeRig");
        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 0);
        Add_Steps_UseRowLive();
        Add_Step("the view is free before any interaction; press Use", n"Step_AssertViewFreeAndPressUse");
        Add_Step_WaitUntil("the Use row is held", n"Check_UseHeld", 0, 0);
        Add_Step("focus the lever", n"Step_FocusLever");
        Add_Step_WaitUntil("the lever's interact target is Focused", n"Check_TargetFocused", 0, 0);
        Add_Step("offer the lever to the resolver", n"Step_OfferLever");
        Add_Step_WaitUntil("the gloves grip and the lever is manipulated", n"Check_IsManipulating", k_SlowPolls, 0);
        Add_Step_WaitUntil("pull until the threshold ends the manipulation", n"Check_PullUntilEnded", 0, 0);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 0);
        Add_Step("the lever landed with Use held: the view is still held", n"Step_AssertViewHeldAfterThreshold");
        Add_Step_WaitSeconds("Use stays held", 0.25f);
        Add_Step("the view stays held while Use is held; release Use", n"Step_AssertStillHeldAndReleaseUse");
        Add_Step_WaitUntil("the Use row releases", n"Check_UseRowReleased", 0, 0);
        Add_Step_WaitUntil("the view is free", n"Check_ViewFreeAfterRelease", 0, 0);
        Add_Step("the view was handed back within two frames of the release", n"Step_AssertFreedPromptly");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

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
        utils_player_viewpoint::Add(_Player, ViewpointSpec);
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));
    }

    UFUNCTION()
    private void Step_AssertViewFreeAndPressUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_HasOrientationControl(), "the view is free before any interaction");
        _UseKey.Press();
    }

    // Stands in for the player's InteractionFocus task.
    UFUNCTION()
    private void Step_FocusLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Player));
    }

    UFUNCTION()
    private void Step_AssertViewHeldAfterThreshold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the threshold finished the interaction");
        Assert_False(_Control.Get_IsManipulating(), "the threshold ended the manipulation");
        Assert_True(Get_IsUseHeld(), "Use is still held");
        Assert_False(Get_HasOrientationControl(), "the view is still held while Use is held");
    }

    UFUNCTION()
    private void Step_AssertStillHeldAndReleaseUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsUseHeld(), "Use is still held");
        Assert_False(Get_HasOrientationControl(), "the view stays held for as long as Use is held");
        _UseKey.Release();
    }

    UFUNCTION()
    private void Step_AssertFreedPromptly(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Frames = _ViewFreeSeenFrame - _UseReleasedFrame;
        Assert_True(Frames <= k_MaxFramesToFreeTheView,
            f"the view was free within {k_MaxFramesToFreeTheView} frames of the Use row releasing (took {Frames})");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Conditions
    //----------------------------------------------------------------------------------------------------------------------

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

    UFUNCTION()
    private void Check_TargetFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    // Marks the frame the Use row is first seen released: the view's bound counts from it.
    UFUNCTION()
    private void Check_UseRowReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_IsUseHeld())
        {
            Res.Set(false);
            return;
        }

        _UseReleasedFrame = utils_time::Get_FrameCounter();
        Res.Set(true);
    }

    UFUNCTION()
    private void Check_ViewFreeAfterRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_HasOrientationControl() == false)
        {
            Res.Set(false);
            return;
        }

        _ViewFreeSeenFrame = utils_time::Get_FrameCounter();
        Res.Set(true);
    }

    //----------------------------------------------------------------------------------------------------------------------

    // Read from the camera's live state (the viewpoint's hold drain writes it).
    private bool Get_HasOrientationControl() const
    {
        return _Camera.Get_Profile().Get_HasOrientationControl();
    }
}
