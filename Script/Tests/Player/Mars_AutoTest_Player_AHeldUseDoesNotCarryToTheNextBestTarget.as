// A Persistent pebble (its world item survives the pickup, so the next target can become best beside it), here only.
asset Mars_ItemDef_AutoTest_Pebble of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Pebble"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Sphere();
    Presentation.Visual.MeshScale = FVector(0.2, 0.2, 0.2);
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Back;
    _ItemTraits.Add(Presentation);
}

// The player's task this test runs on the test entity: the Use row -> resolver intent and its interaction.
class UMars_AutoTestState_UseIntentRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
    }
}

// One held press is one interaction. The carrier (Hotbar with two bag slots, HeldItem, the player's UseIntentToResolver
// task, a Use resolver and a real Use level row on F9 from UMars_AutoTestHelper_UseKey) has two pebbles focused. A is
// offered to the resolver and Use is pressed: A is picked up. With Use still held, A's target leaves the resolver and B's
// joins it, as the view moving on would: B becomes the best target, yet nothing picks it up while the row stays held.
// Releasing and pressing Use again picks B up. Isolated origin (28000, -27000, -30000).
class UMars_AutoTest_Player_AHeldUseDoesNotCarryToTheNextBestTarget : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(28000.0, -27000.0, -30000.0);
    // World item constructions and mount commits outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_InputIntents _Intents;
    private FCk_Handle_InteractionResolver _Resolver;
    private UMars_AutoTestHelper_UseKey _UseKey;

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
        _Intents = utils_input_intents::Add(_Carrier);
        _Resolver = utils_interaction_resolver::Add(_Carrier, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        _UseKey = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _UseKey.Build(InHandle, EKeys::F9);

        _EntityA = Spawn_Pebble(InHandle, k_Origin + FVector(150.0, -60.0, 0.0));
        _EntityB = Spawn_Pebble(InHandle, k_Origin + FVector(150.0, 60.0, 0.0));

        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step_WaitUntil("both pebbles are constructed", n"Check_PebblesConstructed", k_SlowPolls, 0);
        Add_Step("compose the player's matcher and its tasks; focus both pebbles; offer A", n"Step_ComposeRig");
        Add_Step_WaitUntil("the player reads the matcher and both pickups are Focused", n"Check_RigReady", 0, 0);
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitUntil("A is picked up", n"Check_AStowed", k_SlowPolls, 0);
        Add_Step("Use still held: A leaves the resolver and B joins it", n"Step_MoveOnToB");
        Add_Step_WaitFrames("a carried press would have taken B by now", 20);
        Add_Step("B is the best target, but still lies in the world", n"Step_AssertBNotTaken");
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the Use row releases", n"Check_UseReleased", 0, 0);
        Add_Step("press Use again", n"Step_PressUse");
        Add_Step_WaitUntil("the fresh press picks B up", n"Check_BStowed", k_SlowPolls, 0);
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

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_SwapUseSet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Swapped = _UseKey.Request_SwapUseSet();
        if (Swapped.IsValid() == false)
        { FinishFailure(Swapped.Get_Error()); }
    }

    // Stands in for the player's InteractionFocus task: both pebbles focused, A offered to the resolver.
    UFUNCTION()
    private void Step_ComposeRig(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_UseKey.Get_Matcher()));
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
        _UseKey.Press();
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
        _UseKey.Release();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_Recording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsRecording());
    }

    UFUNCTION()
    private void Check_UseSetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsUseSetActive());
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
        Res.Set(_Intents.Get_Matcher() == _UseKey.Get_Matcher() && FocusedA && FocusedB);
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
