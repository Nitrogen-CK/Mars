// A lever's prompt leaves the player's display once its grip ends and the focus moves off it. The player walked away
// holding the lever (the focus task pins the focus while the player's interaction is live), then the grip ended: the
// focus task's next tick unfocuses the lever. The unfocus lands here in the very frame the interaction finishes, the
// tightest order the focus task can produce. Regression for the "Grip lever" prompt staying on screen after a pulled lever
// was let go (Warrens R3, 2026-10-20). Use is the player's (the player's Use task, the lever offered to the resolver).
UCLASS(Abstract)
class UMars_AutoTestRig_PromptClearsWhenAGripEnds : UMars_AutoTestRig_LeverThroughPlayer
{
    default _TimeoutSeconds = 15.0f;

    // Frames the display may take to drop the prompt after the unfocus (the focus drain, the state machine step, the
    // display drain).
    protected const float32 k_SettleSeconds = 0.3f;

    protected FCk_Handle_InteractPromptDisplay _Display;
    protected bool _UnfocusedOnFinish = false;

    protected void Build(FCk_Handle InHandle)
    {
        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());
        _Display = utils_interact_prompt_display::Add(_Player);
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinishedUnfocus"));
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 0);
        Add_Step("focus the lever", n"Step_FocusLever");
        Add_Step_WaitUntil("the lever's interact target is Focused", n"Check_TargetFocused", 0, 0);
        Add_Step_WaitUntil("the lever's prompt is on the display", n"Check_PromptShown", 0, 0);
        Add_Steps_UseRowLive();
        Add_Step("offer the lever to the resolver and press Use", n"Step_UseLever");
        Add_Step_WaitUntil("the gloves grip and the lever is manipulated", n"Check_IsManipulating", k_SlowPolls, 0);
    }

    protected void Add_Steps_AfterTheGripEnds()
    {
        Add_Step_WaitUntil("the interaction finishes (the lever is unfocused in that frame)", n"Check_InteractionFinished", 0, 0);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitSeconds("let the unfocus, the state machine and the display settle", k_SettleSeconds);
        Add_Step("the lever is Idle and its prompt is off the display", n"Step_AssertPromptGone");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    // Stands in for the player's InteractionFocus task.
    UFUNCTION()
    protected void Step_FocusLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Player));
    }

    UFUNCTION()
    protected void Step_AssertPromptGone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_UnfocusedOnFinish, "the lever was unfocused in the frame its interaction finished");
        Assert_False(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Player)),
            "no interaction from the player is left on the lever (the focus task pins on one)");
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Idle,
            "the unfocused lever's target is Idle");
        Assert_Equals_Int(_Display.Get_Slots().Num(), 0, "the display holds no prompt once the lever is unfocused");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Conditions and handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_TargetFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    protected void Check_PromptShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Display.Get_Slots().Num() == 1);
    }

    // What the focus task does on its next tick once the player's interaction is gone and the lever is out of the view.
    UFUNCTION()
    private void OnFinishedUnfocus(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _UnfocusedOnFinish = true;
        _Interactable.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Player));
        _Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(_Target));
    }
}

// Pulled past the threshold: the interaction ends Succeeded and the lever's engage sub-SM runs before the unfocus lands.
class UMars_AutoTest_Control_PromptClearsWhenAPulledGripEnds : UMars_AutoTestRig_PromptClearsWhenAGripEnds
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build(InHandle);
        Add_Step_WaitUntil("pull until the threshold ends the manipulation", n"Check_PullUntilEnded", 0, 0);
        Add_Steps_AfterTheGripEnds();
        Run_Steps(InHandle);
    }
}

// Pulled past the threshold with Use still held: the pull's interaction is gone at once, so nothing is left for the
// player's focus task to pin the lever on while the row stays down.
class UMars_AutoTest_Control_NoInteractionOutlivesAPulledGrip : UMars_AutoTestRig_PromptClearsWhenAGripEnds
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build(InHandle);
        Add_Step_WaitUntil("pull until the threshold ends the manipulation", n"Check_PullUntilEnded", 0, 0);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 0);
        Add_Step_WaitSeconds("Use stays held", k_SettleSeconds);
        Add_Step("Use is held and no interaction from the player is left on the lever", n"Step_AssertNoLiveInteraction");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertNoLiveInteraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsUseHeld(), "Use is still held");
        Assert_Equals_Int(_NewInteractionCount, 1, "the press started one interaction");
        Assert_False(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Player)),
            "no interaction from the player is left on the lever while Use stays held");
    }
}

// Let go before the threshold: releasing Use cancels the interaction (Failed), so no engage runs.
class UMars_AutoTest_Control_PromptClearsWhenALetGoGripEnds : UMars_AutoTestRig_PromptClearsWhenAGripEnds
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build(InHandle);
        Add_Step("let go before the threshold", n"Step_ReleaseUse");
        Add_Steps_AfterTheGripEnds();
        Run_Steps(InHandle);
    }
}

// The player's ManipulateControl, both of its key-to-resolver tasks (Use and Primary) and the Hands sub-SM.
class UMars_AutoTestState_ManipulateControlBothIntentsRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_ManipulateControl);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_PrimaryIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

// Use and Primary held from the same frame with Primary resolving the Use channel first, as the player has them: the left
// mouse button drives both input actions, so one click brings both rows down on one frame (two rows on one physical key do
// not bake: a shared terminal resolves to one intent). One click on a lever opens both intents, and it starts one
// interaction, which the pull ends. Regression for the second interaction the Primary task started in the same frame
// (neither was live yet): the pull ended one, the other stayed live while the button was held, and the focus task stayed
// pinned on the lever, its prompt on screen (2026-10-20).
class UMars_AutoTest_Control_ASharedKeyPressStartsOneInteraction : UMars_AutoTestRig_LeverThroughPlayer
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());

        // The Primary row on a key of its own, pressed in the Use row's frame.
        auto ExtraRows = TArray<FMars_AutoTestHelper_KeyRow>();
        ExtraRows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F10, GameplayTags::Mars_Intent_Interact_Primary, n"IP"));
        _UseKey = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _UseKey.Build_WithRows(InHandle, EKeys::F9, ExtraRows);

        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlBothIntentsRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 0);
        Add_Step("focus the lever", n"Step_FocusLever");
        Add_Steps_UseRowLive();
        Add_Step("offer the lever to the resolver and press Use and Primary in one frame", n"Step_PressBothRows");
        Add_Step_WaitUntil("the gloves grip and the lever is manipulated", n"Check_IsManipulating", k_SlowPolls, 0);
        Add_Step_WaitUntil("pull until the threshold ends the manipulation", n"Check_PullUntilEnded", 0, 0);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 0);
        Add_Step_WaitSeconds("both rows stay held", 0.3f);
        Add_Step("one interaction started, and none is left while the rows are held", n"Step_AssertOneInteraction");
        Run_Steps(InHandle);
    }

    // The player's own mappings: Primary resolves the Use channel first (Mars_PlayerCharacter_Config).
    protected FCk_InteractionResolver_Spec Make_ResolverSpec() const override
    {
        auto UseChannels = TArray<FGameplayTag>();
        UseChannels.Add(GameplayTags::InteractionChannel_Mars_Use);
        auto PrimaryChannels = TArray<FGameplayTag>();
        PrimaryChannels.Add(GameplayTags::InteractionChannel_Mars_Use);
        PrimaryChannels.Add(GameplayTags::InteractionChannel_Mars_Primary_UsableItem);

        // The test entity has no transform: no distance sort.
        auto UseMapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, UseChannels);
        UseMapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);
        auto PrimaryMapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Primary, PrimaryChannels);
        PrimaryMapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(UseMapping);
        Mappings.Add(PrimaryMapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    // Stands in for the player's InteractionFocus task.
    UFUNCTION()
    private void Step_FocusLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Player));
    }

    // What one left click does: both input actions go down on the same frame.
    UFUNCTION()
    private void Step_PressBothRows(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        OfferLever();
        _UseKey.Press();
        _UseKey.Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Step_AssertOneInteraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsUseHeld(), "Use is still held");
        Assert_Equals_Int(_NewInteractionCount, 1, "one click on both rows started one interaction");
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the pull finished it");
        Assert_False(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Player)),
            "no interaction from the player is left on the lever while the rows are held");
    }
}
