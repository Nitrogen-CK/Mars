// A Persistent pebble (its world item survives the pickup, so the next target can become best beside it), here only.
asset Mars_ItemDef_AutoTest_Pebble of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Pebble"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Sphere();
    Presentation.Visual.MeshScale = FVector(0.2, 0.2, 0.2);
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Back;
    _ItemTraits.Add(Presentation);
}

// The player's tasks this test runs on the test entity: the resolver -> interaction bridge and the Use row -> resolver
// intent forwarding.
class UMars_AutoTestState_UseIntentRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_InteractionResolverBinds);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
    }
}

// One held press is one interaction. The carrier (Hotbar with two bag slots, HeldItem, the player's InteractionResolverBinds
// and UseIntentToResolver tasks, a Use resolver and a real Use level row on F9) has two pebbles focused. Pebble A is
// offered to the resolver and Use is pressed: A is picked up. With Use still held, A's target leaves the resolver and B's
// joins it, as the view moving on would: B becomes the best target, yet nothing picks it up while the row stays held.
// Releasing and pressing Use again picks B up. Isolated origin (28000, -27000, -30000).
class UMars_AutoTest_Player_AHeldUseDoesNotCarryToTheNextBestTarget : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(28000.0, -27000.0, -30000.0);

    private FCk_Handle_InputIntents _Intents;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InputSource _Source;
    private FCk_Handle_InputButtonMap _Map;
    private FCk_Handle_IntentSampler _Sampler;
    private FCk_Handle_IntentMatcher _Matcher;
    private FKey _UseKey;

    // Under construction until each is a WorldItem whose holder holds its item.
    private FCk_Handle _EntityA;
    private FCk_Handle _EntityB;
    private FCk_Handle_WorldItem _PebbleA;
    private FCk_Handle_WorldItem _PebbleB;
    private FCk_Handle_Item _ItemA;
    private FCk_Handle_Item _ItemB;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();
        _Intents = utils_input_intents::Add(_Carrier);
        _Resolver = utils_interaction_resolver::Add(_Carrier, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        Build_UseInput(InHandle);

        _EntityA = Spawn_Pebble(InHandle, k_Origin + FVector(150.0, -60.0, 0.0));
        _EntityB = Spawn_Pebble(InHandle, k_Origin + FVector(150.0, 60.0, 0.0));

        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 5.0f);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 5.0f);
        Add_Step_WaitUntil("both pebbles are constructed", n"Check_PebblesConstructed", 0, 10.0f);
        Add_Step("compose the player's matcher and its tasks; focus both pebbles; offer A", n"Step_ComposeRig");
        Add_Step_WaitUntil("the player reads the matcher and both pickups are Focused", n"Check_RigReady", 0, 5.0f);
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitUntil("A is picked up", n"Check_AStowed", 0, 5.0f);
        Add_Step("Use still held: A leaves the resolver and B joins it", n"Step_MoveOnToB");
        Add_Step_WaitFrames("a carried press would have taken B by now", 20);
        Add_Step("B is the best target, but still lies in the world", n"Step_AssertBNotTaken");
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the Use row releases", n"Check_UseReleased", 0, 5.0f);
        Add_Step("press Use again", n"Step_PressUse");
        Add_Step_WaitUntil("the fresh press picks B up", n"Check_BStowed", 0, 5.0f);
        Run_Steps(InHandle);
    }

    private FCk_InteractionResolver_Spec Make_ResolverSpec() const
    {
        auto Channels = TArray<FGameplayTag>();
        Channels.Add(GameplayTags::InteractionChannel_Mars_Use);

        auto Mapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, Channels);
        Mapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(Mapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    // A private input stack (source, button map, sampler, layer, matcher) the test presses F9 on.
    private void Build_UseInput(FCk_Handle InHandle)
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

    // A pebble world item resting on a static floor of its own.
    private FCk_Handle Spawn_Pebble(FCk_Handle InHandle, FVector InFloorTop)
    {
        auto Owner = InHandle;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InFloorTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(40.0, 40.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        return utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(Mars_ItemDef_AutoTest_Pebble), FTransform(FRotator::ZeroRotator, InFloorTop + FVector(0.0, 0.0, 15.0))));
    }

    private FCk_Handle_InteractTarget Get_UseTarget(const FCk_Handle_WorldItem& InPebble) const
    {
        auto Pickup = InPebble.Get_Pickup();
        return Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }

    private void Inject_UseKey(ECk_InputSource_EventType InEventType)
    {
        auto Event = FCk_InputSource_RawEvent(ECk_InputSource_DeviceClass::Keyboard, _UseKey, InEventType);
        utils_input_source::Request_InjectRawEvent(_Source, FCk_Request_InputSource_InjectRawEvent(Event));
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

    // Stands in for the player's InteractionFocus task: without focus a pickup's HFSM never reaches Interacting.
    UFUNCTION()
    private void Step_ComposeRig(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Matcher));
        utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_UseIntentRig));

        auto PickupA = _PebbleA.Get_Pickup();
        PickupA.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        auto PickupB = _PebbleB.Get_Pickup();
        PickupB.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));

        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(Get_UseTarget(_PebbleA)));
    }

    UFUNCTION()
    private void Step_PressUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Inject_UseKey(ECk_InputSource_EventType::Pressed);
    }

    UFUNCTION()
    private void Step_MoveOnToB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use), "Use is still held");
        _Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(Get_UseTarget(_PebbleA)));
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(Get_UseTarget(_PebbleB)));
    }

    UFUNCTION()
    private void Step_AssertBNotTaken(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use), "Use is still held");
        Assert_True(_PebbleB.Get_Mount() == EMars_WorldItem_Mount::World, "B still lies in the world");
        Assert_True(_PebbleB.Get_HeldItem() == _ItemB, "B's item is still in its holder");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(1)), "the second bag slot is empty");
        Assert_True(_Hotbar.Get_ItemAt(0) == _ItemA, "A is in the first bag slot");
    }

    UFUNCTION()
    private void Step_ReleaseUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Inject_UseKey(ECk_InputSource_EventType::Released);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

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
    private void Check_PebblesConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto AReady = ck::IsValid(_EntityA) && _EntityA.Is_WorldItem() && ck::IsValid(_EntityA.As_WorldItem().Get_HeldItem());
        const auto BReady = ck::IsValid(_EntityB) && _EntityB.Is_WorldItem() && ck::IsValid(_EntityB.As_WorldItem().Get_HeldItem());
        if (AReady && BReady && ck::Is_NOT_Valid(_PebbleA))
        {
            _PebbleA = _EntityA.As_WorldItem();
            _PebbleB = _EntityB.As_WorldItem();
            _ItemA = _PebbleA.Get_HeldItem();
            _ItemB = _PebbleB.Get_HeldItem();
        }

        auto Res = OutResult;
        Res.Set(AReady && BReady);
    }

    UFUNCTION()
    private void Check_RigReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto FocusedA = utils_state_machine::Get_CurrentStateClass(Get_UseTarget(_PebbleA).As_StateMachine()) == UMars_SmState_Interactable_Focused;
        const auto FocusedB = utils_state_machine::Get_CurrentStateClass(Get_UseTarget(_PebbleB).As_StateMachine()) == UMars_SmState_Interactable_Focused;

        auto Res = OutResult;
        Res.Set(_Intents.Get_Matcher() == _Matcher && FocusedA && FocusedB);
    }

    UFUNCTION()
    private void Check_AStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(0) == _ItemA && _PebbleA.Get_Mount() != EMars_WorldItem_Mount::World);
    }

    UFUNCTION()
    private void Check_UseReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use) == false);
    }

    UFUNCTION()
    private void Check_BStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(1) == _ItemB && _PebbleB.Get_Mount() != EMars_WorldItem_Mount::World);
    }
}
