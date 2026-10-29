// One press on the key Use and Primary share, with a world prompt focused, runs that prompt's interaction and not the held
// item's use, and does nothing at all while that prompt is blocked: the player's Use and Primary intent tasks over the
// player's own channel mapping (Use -> [Use]; Primary -> [Use, Primary.UsableItem], the world channel first, claimed by
// any offered target), a lit torch in the hand (its UsableItem target toggles its flame) and an unlit fixture flame
// focused (its Use target lights it from the torch). Both rows are pressed in one frame, as one key does. First with the
// ignite row disabled, as a blocked prompt leaves it: nothing runs and the torch stays lit. Then with it enabled: the
// fixture lights, the torch stays lit, and the torch's use target never starts an interaction. The carrier rig with a
// belt, the player's intent tasks on it, and a private key stack (Use on F9, Primary on F10). Isolated origin
// (28000, -31000, -30000).
class UMars_AutoTest_Player_AFocusedPromptPressDoesNotAlsoUseTheHeldItem : UMars_AutoTestRig_FlameItem
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(28000.0, -31000.0, -30000.0);

    private FCk_Handle_HeldItemUse _Use;
    private FCk_Handle_InputIntents _Intents;
    private FCk_Handle_InteractionResolver _Resolver;
    private UMars_AutoTestHelper_UseKey _Keys;

    private FCk_Handle_Flame _Fixture;
    private FCk_Handle_Interactable _FixtureInteractable;
    private FCk_Handle_InteractTarget _IgniteTarget;
    private FCk_Handle_InteractTarget _UseTarget;

    private int32 _IgniteInteractions = 0;
    private int32 _HeldUseInteractions = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBelt(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Use = utils_held_item_use::Add(_Carrier);
        _Intents = utils_input_intents::Add(_Carrier);
        _Resolver = utils_interaction_resolver::Add(_Carrier, mars::Mars_PlayerCharacter_Config.InteractionResolver, ECk_Replication::DoesNotReplicate);

        auto ExtraRows = TArray<FMars_AutoTestHelper_KeyRow>();
        ExtraRows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F10, GameplayTags::Mars_Intent_Interact_Primary, n"IP"));
        _Keys = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _Keys.Build_WithRows(InHandle, EKeys::F9, ExtraRows);

        Build_Fixture(InHandle);
        SpawnFlameItem(InHandle, FMars_AutoTestHelper_FlameItemSpawn(mars_items::Torch(), UMars_Torch_EntityScript, k_Origin + FVector(0.0, 150.0, 0.0)));

        Add_Step_WaitUntil("the keys are minted and the sampler records", n"Check_Recording", 0, 0);
        Add_Step("bake the Use and Primary level rows and swap them in", n"Step_SwapKeySet");
        Add_Step_WaitUntil("both rows are live on the matcher", n"Check_KeySetActive", 0, 0);
        Add_Step_WaitUntil("the torch is composed", n"Check_FlameReady", k_SlowPolls, 0);
        Add_Step("stow the torch", n"Step_StowFlame");
        Add_Step("light the torch", n"Step_Light");
        Add_Step_WaitUntil("the carrier holds the lit torch", n"Check_FlameHeldAndLit", k_SlowPolls, 0);
        Add_Step("compose the player's intent tasks; the held torch's use; focus the fixture", n"Step_ComposeRig");
        Add_Step_WaitUntil("the torch's use target and the fixture's ignite target are both offered", n"Check_RigReady", 0, 0);
        Add_Step("the ignite row is disabled, as a blocked prompt leaves it", n"Step_DisableIgnite");
        Add_Step("press Use and Primary in one frame", n"Step_PressBoth");
        Add_Step_WaitFrames("an interaction from the press would have run by now", 20);
        Add_Step("nothing ran: the blocked prompt kept the key from the torch's use", n"Step_AssertNothingRan");
        Add_Step("release both", n"Step_ReleaseBoth");
        Add_Step_WaitUntil("both intents closed", n"Check_IntentsClosed", 0, 0);
        Add_Step("the ignite row is enabled again", n"Step_EnableIgnite");
        Add_Step("press Use and Primary in one frame", n"Step_PressBoth");
        Add_Step_WaitUntil("the fixture lights from the torch", n"Check_FixtureLit", k_SlowPolls, 0);
        Add_Step_WaitFrames("a second interaction from the same press would have run by now", 20);
        Add_Step("the fixture lit once, the torch is still lit, and its use never ran", n"Step_AssertOnlyTheFixture");
        Add_Step("release both", n"Step_ReleaseBoth");
        Run_Steps(InHandle);
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(_FlameItem))
        { return; }

        auto Entity = _FlameItem.H();
        utils_entity_lifetime::Request_DestroyEntity(Entity);
    }

    // An unlit fixture flame (needs a flame) with the fixture's ignite row on a transform-only interactable, 100 cm ahead.
    private void Build_Fixture(FCk_Handle InHandle)
    {
        auto FixtureEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(FixtureEntity, FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 60.0)), ECk_Replication::DoesNotReplicate);
        auto FixtureSpec = FMars_Flame_Spec();
        FixtureSpec.Lighting = EMars_Flame_Lighting::NeedsAFlame;
        _Fixture = utils_flame::Add(FixtureEntity, FixtureSpec);

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(utils_flame::Make_IgniteTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Torch"))));
        _FixtureInteractable = utils_interactable::Create(Root, Spec);
        _IgniteTarget = _FixtureInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        _IgniteTarget.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnIgniteInteraction"));
    }

    UFUNCTION()
    private void OnIgniteInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        ++_IgniteInteractions;
    }

    UFUNCTION()
    private void OnHeldUseInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        ++_HeldUseInteractions;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_Recording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Keys.Get_IsRecording());
    }

    UFUNCTION()
    private void Step_SwapKeySet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Swapped = _Keys.Request_SwapUseSet();
        if (Swapped.IsValid() == false)
        { FinishFailure(Swapped.Get_Error()); }
    }

    UFUNCTION()
    private void Check_KeySetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Keys.Get_IsUseSetActive());
    }

    // The player's InteractionFocus and HeldItemDrivesUse tasks, by hand: the matcher reaches the intents, the intent
    // tasks run, the held torch's use interactable is built and offered, the fixture is focused and its targets offered.
    UFUNCTION()
    private void Step_ComposeRig(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Keys.Get_Matcher()));
        utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_UseAndPrimaryIntentRig));
        _Use.Request_RefreshFromHeldItem(FMars_Request_HeldItemUse_RefreshFromHeldItem());

        _FixtureInteractable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        for (auto Target : _FixtureInteractable.Get_AllInteractTargets())
        { _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(Target)); }
    }

    UFUNCTION()
    private void Check_RigReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_UseTarget))
        {
            const auto UseInteractable = _Use.Get_Fragment(FMars_Fragment_HeldItemUse).CurrentInteractable;
            if (ck::Is_NOT_Valid(UseInteractable))
            {
                Res.Set(false);
                return;
            }

            _UseTarget = UseInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Primary_UsableItem);
            if (ck::IsValid(_UseTarget))
            { _UseTarget.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnHeldUseInteraction")); }
        }

        Res.Set(ck::IsValid(_UseTarget) && _Fixture.Get_ActionFor(_Carrier) == EMars_Flame_Action::Light
            && _Fixture.Get_IsLit() == false);
    }

    // What the fixture's prompt does for a blocked action (utils_interact_prompt::Apply_Action): the row stays offered to
    // the resolver, disabled.
    UFUNCTION()
    private void Step_DisableIgnite(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_interact_target::Set_Enabled(_IgniteTarget, ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Step_EnableIgnite(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_interact_target::Set_Enabled(_IgniteTarget, ECk_EnableDisable::Enable);
    }

    UFUNCTION()
    private void Step_AssertNothingRan(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Primary), "Primary is held");
        Assert_Equals_Int(_IgniteInteractions, 0, "the disabled ignite row ran nothing");
        Assert_Equals_Int(_HeldUseInteractions, 0, "the torch's use never ran: the blocked prompt kept the key");
        Assert_True(Get_Flame().Get_IsLit(), "the torch is still lit");
        Assert_False(_Fixture.Get_IsLit(), "the fixture is still dark");
    }

    UFUNCTION()
    private void Check_IntentsClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use) == false
            && _Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Primary) == false
            && _Resolver.Get_BestInteractTargets(GameplayTags::InteractionIntent_Mars_Primary).Num() == 0);
    }

    UFUNCTION()
    private void Step_PressBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Keys.Press_Row(GameplayTags::Mars_Intent_Interact_Use);
        _Keys.Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Check_FixtureLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsLit());
    }

    UFUNCTION()
    private void Step_AssertOnlyTheFixture(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_IgniteInteractions, 1, "the fixture's ignite ran once for the press");
        Assert_Equals_Int(_HeldUseInteractions, 0, "the held torch's use never ran: the focused prompt took the press");
        Assert_True(Get_Flame().Get_IsLit(), "the torch is still lit (its use would have snuffed it)");
        Assert_True(_Fixture.Get_IsLit(), "the fixture is lit from the torch");
    }

    UFUNCTION()
    private void Step_ReleaseBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Keys.Release_Row(GameplayTags::Mars_Intent_Interact_Use);
        _Keys.Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }
}

// The player's Use and Primary rows -> resolver intents and their interactions, on the test entity.
class UMars_AutoTestState_UseAndPrimaryIntentRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_PrimaryIntentToResolver);
    }
}
