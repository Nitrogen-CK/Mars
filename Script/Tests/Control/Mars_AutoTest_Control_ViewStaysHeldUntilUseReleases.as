// A lever pulled past its threshold while the Use row is still held keeps the view held after the interaction finished and
// the manipulation ended: the drag that pulled it must not turn the view the frame it lands (ManipulateControl's default
// ViewLock, UntilUseReleases). Releasing the row hands the view back within two frames. The Use row is a real CkIntent
// level row (a lone "level" intent tagged Mars.Intent.Interact.Use on F9, injected through a private input source) on a
// matcher the player's InputIntents reads. The camera is the headless director of UMars_AutoTest_Control_PendingGripFreezesCamera.
class UMars_AutoTest_Control_ViewStaysHeldUntilUseReleases : UMars_AutoTestRig_LeverThroughPlayer
{
    default _TimeoutSeconds = 15.0f;

    private const int32 k_MaxPollsToFreeTheView = 2;

    private ACkAutoTest_GameplayCamera_Helper _CameraHelper;
    private FCk_Handle_Transform _CameraOwner;
    private FCk_Handle_Camera _Camera;
    private FCk_Handle_InputIntents _Intents;

    private FCk_Handle_InputSource _Source;
    private FCk_Handle_InputButtonMap _Map;
    private FCk_Handle_IntentSampler _Sampler;
    private FCk_Handle_IntentMatcher _Matcher;
    private FKey _UseKey;

    private int32 _PollsToFreeTheView = 0;

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
        // Before the rig SM: ManipulateControl caches the player's InputIntents on enter.
        _Intents = utils_input_intents::Add(_Player);
        BuildUseInput(InHandle);

        Add_Step_WaitUntil("the camera helper's entity is constructed", n"Check_CameraOwnerReady", 0, 5.0f);
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 5.0f);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 5.0f);
        Add_Step("compose the camera, the viewpoint, the player's matcher and the rig SM", n"Step_ComposeRig");
        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 5.0f);
        Add_Step_WaitUntil("the player reads the matcher", n"Check_MatcherSet", 0, 5.0f);
        Add_Step("the view is free before any interaction; press Use", n"Step_AssertViewFreeAndPressUse");
        Add_Step_WaitUntil("the Use row is held", n"Check_UseHeld", 0, 5.0f);
        Add_Step("focus the lever", n"Step_FocusLever");
        Add_Step_WaitUntil("the lever's interact target is Focused", n"Check_TargetFocused", 0, 5.0f);
        Add_Step("add the lever to the resolver and open Use", n"Step_UseLever");
        Add_Step_WaitUntil("the gloves grip and the lever is manipulated", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull until the threshold ends the manipulation", n"Check_PullUntilEnded", 0, 5.0f);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 5.0f);
        Add_Step("the lever landed with Use held: the view is still held", n"Step_AssertViewHeldAfterThreshold");
        Add_Step_WaitSeconds("Use stays held", 0.25f);
        Add_Step("the view stays held while Use is held; release Use", n"Step_AssertStillHeldAndReleaseUse");
        Add_Step_WaitUntil("the Use row releases", n"Check_UseReleased", 0, 5.0f);
        Add_Step_WaitUntil("the view is free", n"Check_ViewFreeAfterRelease", 0, 1.0f);
        Add_Step("the view was handed back within two frames of the release", n"Step_AssertFreedPromptly");
        Run_Steps(InHandle);
    }

    // A private input stack (source, button map, sampler, layer, matcher) the test presses F9 on.
    private void BuildUseInput(FCk_Handle InHandle)
    {
        _UseKey = EKeys::F9;

        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Source = utils_input_source::Add(Owner, FCk_InputSource_Spec(0));

        TArray<FKey> PhysicalButtons;
        PhysicalButtons.Add(_UseKey);
        _Map = utils_input_button_map::Add(Owner, FCk_InputButtonMap_Spec(PhysicalButtons));
        _Sampler = utils_intent_sampler::Add(Owner, FCk_IntentSampler_Spec(120));

        FCk_Handle LayerEntity = utils_input_layer::Create(Owner, FCk_InputLayer_Spec(_Source, 50));
        _Matcher = utils_intent_matcher::Add(LayerEntity, FCk_IntentMatcher_Spec());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_SwapUseSet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto UseTag = GameplayTags::Mars_Intent_Interact_Use;
        auto Parsed = utils_intent_grammar::Parse("IU level", UseTag.TagName, 0, UseTag);
        if (Parsed.Get_Outcome() != ECk_SucceededFailed::Succeeded)
        {
            FinishFailure("the Use level notation failed to parse");
            return;
        }

        TArray<FCk_Intent_Definition> Definitions;
        Definitions.Add(Parsed.Get_Definition());

        TArray<FCk_Intent_ButtonNameRow> Rows;
        Rows.Add(FCk_Intent_ButtonNameRow(n"IU", FCk_Input_ButtonId(ECk_Input_ButtonTier::Physical, _UseKey.GetKeyName())));

        auto Baked = utils_intent_grammar::Bake(Definitions, Rows);
        if (Baked.Get_Outcome() != ECk_SucceededFailed::Succeeded)
        {
            FinishFailure("the Use level row failed to bake");
            return;
        }

        utils_intent_matcher::Request_SwapSet(_Matcher, FCk_Request_IntentMatcher_SwapSet(Baked.Get_CompiledSet()));
    }

    // The viewpoint and the matcher must exist before the SM starts: ManipulateControl reads the camera on enter.
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
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Matcher));
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));
    }

    UFUNCTION()
    private void Step_AssertViewFreeAndPressUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_HasOrientationControl(), "the view is free before any interaction");
        Inject_UseKey(ECk_InputSource_EventType::Pressed);
    }

    // Stands in for the player's InteractionFocus task: without focus the Interactable's HFSM never reaches Interacting.
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
        Assert_True(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use), "Use is still held");
        Assert_False(Get_HasOrientationControl(), "the view is still held while Use is held");
    }

    UFUNCTION()
    private void Step_AssertStillHeldAndReleaseUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use), "Use is still held");
        Assert_False(Get_HasOrientationControl(), "the view stays held for as long as Use is held");
        Inject_UseKey(ECk_InputSource_EventType::Released);
    }

    UFUNCTION()
    private void Step_AssertFreedPromptly(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PollsToFreeTheView <= k_MaxPollsToFreeTheView,
            f"the view was free within {k_MaxPollsToFreeTheView} frames of the Use row releasing (took {_PollsToFreeTheView})");
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
    private void Check_Recording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_input_button_map::Get_ButtonIdsForKey(_Map, _UseKey).Num() >= 1 &&
                utils_intent_sampler::Get_FrameCount(_Sampler) >= 1);
    }

    UFUNCTION()
    private void Check_UseSetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_intent_matcher::Get_ActiveIntentCount(_Matcher) == 1 &&
                utils_intent_matcher::Get_RegisteredCaptureKeys(_Matcher).Contains(_UseKey));
    }

    UFUNCTION()
    private void Check_MatcherSet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_Matcher() == _Matcher);
    }

    UFUNCTION()
    private void Check_UseHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use));
    }

    UFUNCTION()
    private void Check_TargetFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    private void Check_UseReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use) == false);
    }

    UFUNCTION()
    private void Check_ViewFreeAfterRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _PollsToFreeTheView += 1;

        auto Res = OutResult;
        Res.Set(Get_HasOrientationControl());
    }

    //----------------------------------------------------------------------------------------------------------------------

    private void Inject_UseKey(ECk_InputSource_EventType InEventType)
    {
        auto Event = FCk_InputSource_RawEvent(ECk_InputSource_DeviceClass::Keyboard, _UseKey, InEventType);
        utils_input_source::Request_InjectRawEvent(_Source, FCk_Request_InputSource_InjectRawEvent(Event));
    }

    // Read from the camera's live state (Request_Set_HasOrientationControl writes it immediately).
    private bool Get_HasOrientationControl() const
    {
        return _Camera.Get_Profile().Get_HasOrientationControl();
    }
}
