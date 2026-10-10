// The player's tasks the pickup-by-press rig runs on its carrier: the resolver -> interaction bridge, the Use row ->
// resolver intent forwarding, and the gloves' Hands sub-SM (whose Rest also follows a launch through with a push).
class UMars_AutoTestState_PickupByPressRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_InteractionResolverBinds);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

// A carrier composed as the player is for a pickup: Hotbar (two bag slots), HeldItem with the selection push, HeldItemUse
// (the drop / throw launch), its gloves (FPHands on the Hand node, the Hands sub-SM), a Use resolver, InputIntents and a
// private input stack with a real Use level row on F9, and the player's resolver -> interaction and Use -> resolver tasks.
// It holds a rock (seeded, stowed to bag slot 0, held), launches it with the real HeldItemUse path onto a floor in front
// of it, focuses the rock's new world item from the frame it exists (the player looks where it throws), and once it lies
// still offers it to the resolver as the view trace would and taps Use (pressed, released two frames later). A test sets
// _LaunchKind and asserts the pickup lands within k_StowSeconds. Add_Steps_TapWhileHolding instead keeps the held rock and
// taps on a second rock lying in front of the carrier: the gloves, full with a two-handed rock, refuse the reach, and the
// pickup must land at once (within k_RefusedStowSeconds, under the grip-wait's time bound).
UCLASS(Abstract)
class UMars_AutoTestRig_PickupByPress : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    // The tap must land the pickup this soon: the gloves' reach and grip, or at once when they cannot reach.
    protected const float32 k_StowSeconds = 1.0f;
    // A pickup the gloves refused lands within a few frames; the grip-wait's time bound (0.5 s) would be later.
    protected const float32 k_RefusedStowSeconds = 0.3f;

    protected EMars_LaunchKind _LaunchKind = EMars_LaunchKind::Drop;

    protected FCk_Handle_HeldItemUse _Use;
    protected FCk_Handle_InputIntents _Intents;
    protected FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InputSource _Source;
    private FCk_Handle_InputButtonMap _Map;
    private FCk_Handle_IntentSampler _Sampler;
    private FCk_Handle_IntentMatcher _Matcher;
    private FKey _UseKey;

    private FVector _Origin;
    // Every reach the gloves refused, by interact target (invalid for a reach that served no interaction).
    protected TArray<FCk_Handle_InteractTarget> _RefusedTargets;
    // The rock's Use target as it was offered (a picked-up transient rock's world item is destroyed with it).
    protected FCk_Handle_InteractTarget _OfferedTarget;
    protected FCk_Handle_WorldItem _Landed;
    private TOptional<FVector> _LastLandedLocation;
    private int32 _StillFrames = 0;

    protected void Build_Rig(FCk_Handle InHandle, FVector InOrigin)
    {
        _Origin = InOrigin;
        Add_CarrierBodyWithBack(InHandle, InOrigin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();
        _Use = utils_held_item_use::Add(_Carrier);
        _Intents = utils_input_intents::Add(_Carrier);
        _Resolver = utils_interaction_resolver::Add(_Carrier, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);

        auto HandsSpec = FMars_FPHands_Spec();
        HandsSpec.HandNode = _HandNode;
        _Hands = utils_fphands::Add(_Carrier, HandsSpec);
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnCarrierHandsPhaseChanged"));
        _Hands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnRigReachRefused"));

        Build_UseInput(InHandle);
        Build_Floor(InHandle);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
    }

    // Up to the tap; the test adds its assertion steps after.
    protected void Add_Steps_LaunchAndTap()
    {
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 5.0f);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 5.0f);
        Add_Step_WaitUntil("the rock holder is seeded", n"Check_HoldersSeeded", 0, 5.0f);
        Add_Step("compose the player's tasks and stow the rock into bag slot 0", n"Step_ComposeAndStow");
        Add_Step_WaitUntil("the rock is held and the gloves rest, listening", n"Check_RockHeldAndRest", 0, 5.0f);
        Add_Step("launch the rock with the held item's drop / throw", n"Step_Launch");
        Add_Step_WaitUntil("the rock lies (nearly) still on the floor", n"Check_Landed", 0, 15.0f);
        Add_Step("offer its (focused) pickup to the resolver", n"Step_FocusAndOffer");
        Add_Step_WaitUntil("the pickup is Focused", n"Check_Focused", 0, 2.0f);
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the rock is picked up", n"Check_Stowed", 0, k_StowSeconds);
        Add_Step("it is in a bag slot and its world item is gone", n"Step_AssertStowed");
    }

    // Up to the tap on a loose rock while the carrier still holds its own; the test adds its assertion steps after.
    protected void Add_Steps_TapWhileHolding()
    {
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 5.0f);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 5.0f);
        Add_Step_WaitUntil("the rock holder is seeded", n"Check_HoldersSeeded", 0, 5.0f);
        Add_Step("compose the player's tasks and stow the rock into bag slot 0", n"Step_ComposeAndStow");
        Add_Step_WaitUntil("the rock is held and the gloves rest, listening", n"Check_RockHeldAndRest", 0, 5.0f);
        Add_Step("a second rock is dropped in front of the carrier", n"Step_SpawnLooseRock");
        Add_Step_WaitUntil("the second rock lies (nearly) still on the floor", n"Check_Landed", 0, 15.0f);
        Add_Step("offer its (focused) pickup to the resolver", n"Step_FocusAndOffer");
        Add_Step_WaitUntil("the pickup is Focused", n"Check_Focused", 0, 2.0f);
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the second rock is picked up at once", n"Check_Stowed", 0, k_RefusedStowSeconds);
        Add_Step("the gloves refused its reach, and it is in the other bag slot", n"Step_AssertRefusedAndStowed");
    }

    // Two taps, each its own hold: empty-handed, the carrier taps on a loose rock (the first hold is spent by that pickup),
    // throws it, and taps on it again once it lies still; the test adds its assertion steps after.
    protected void Add_Steps_TapTwice()
    {
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_Recording", 0, 5.0f);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 5.0f);
        Add_Step("compose the player's tasks", n"Step_Compose");
        Add_Step_WaitUntil("the empty gloves rest, listening", n"Check_EmptyAndRest", 0, 5.0f);
        Add_Step("a rock is dropped in front of the carrier", n"Step_SpawnLooseRock");
        Add_Step_WaitUntil("the rock lies (nearly) still on the floor", n"Check_Landed", 0, 15.0f);
        Add_Step("offer its (focused) pickup to the resolver", n"Step_FocusAndOffer");
        Add_Step_WaitUntil("the pickup is Focused", n"Check_Focused", 0, 2.0f);
        Add_Step("press Use (the first hold)", n"Step_PressUse");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the first tap picks the rock up", n"Check_Stowed", 0, k_StowSeconds);
        Add_Step_WaitUntil("the rock is held and the gloves rest, listening", n"Check_RockHeldAndRest", 0, 5.0f);
        Add_Step("forget the picked-up world item and throw the rock", n"Step_ForgetAndLaunch");
        Add_Step_WaitUntil("the thrown rock lies (nearly) still on the floor", n"Check_Landed", 0, 15.0f);
        Add_Step("offer its (focused) pickup to the resolver", n"Step_FocusAndOffer");
        Add_Step_WaitUntil("the pickup is Focused", n"Check_Focused", 0, 2.0f);
        Add_Step("press Use again (a fresh hold)", n"Step_PressUse");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the second tap picks the rock up again", n"Check_Stowed", 0, k_StowSeconds);
        Add_Step("it is in a bag slot and its world item is gone", n"Step_AssertStowed");
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

    // A static slab under the carrier and in front of it (+X), its top at the carrier's feet, with a trough that stops a
    // rolling rock: a kerb 150 cm out (20 cm tall: a throw clears it, a drop or a roll-back stops at it) and a wall 320 cm out.
    private void Build_Floor(FCk_Handle InOwner)
    {
        Add_StaticBox(InOwner, FVector(150.0, 0.0, -1.0), FVector(400.0, 200.0, 1.0));
        Add_StaticBox(InOwner, FVector(150.0, 0.0, 10.0), FVector(2.0, 200.0, 10.0));
        Add_StaticBox(InOwner, FVector(320.0, 0.0, 50.0), FVector(2.0, 200.0, 50.0));
    }

    private void Add_StaticBox(FCk_Handle InOwner, FVector InCentreLocal, FVector InHalfExtents)
    {
        auto Owner = InOwner;
        auto Box = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Box, FTransform(FRotator::ZeroRotator, _Origin + InCentreLocal), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Box, BoxSpec);
    }

    private void Inject_UseKey(ECk_InputSource_EventType InEventType)
    {
        auto Event = FCk_InputSource_RawEvent(ECk_InputSource_DeviceClass::Keyboard, _UseKey, InEventType);
        utils_input_source::Request_InjectRawEvent(_Source, FCk_Request_InputSource_InjectRawEvent(Event));
    }

    protected FCk_Handle_InteractTarget Get_UseTarget() const
    {
        auto Pickup = _Landed.Get_Pickup();
        return Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_Recording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_input_button_map::Get_ButtonIdsForKey(_Map, _UseKey).Num() >= 1 &&
                utils_intent_sampler::Get_FrameCount(_Sampler) >= 1);
    }

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

    UFUNCTION()
    private void Check_UseSetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_intent_matcher::Get_ActiveIntentCount(_Matcher) == 1 &&
                utils_intent_matcher::Get_RegisteredCaptureKeys(_Matcher).Contains(_UseKey));
    }

    UFUNCTION()
    private void Step_ComposeAndStow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Matcher));
        utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_PickupByPressRig));
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Step_Compose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_intent_matcher::BindTo_OnIntentPhaseChanged(_Matcher,
            FCk_Delegate_IntentMatcher_PhaseChanged(this, n"OnRigIntentPhaseChanged"), ECk_Signal_BindingPolicy::IgnorePayloadInFlight);
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Matcher));
        utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_PickupByPressRig));
    }

    UFUNCTION()
    private void Check_EmptyAndRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_Matcher() == _Matcher && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_ForgetAndLaunch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Landed = FCk_Handle_WorldItem();
        _LastLandedLocation.Reset();
        _StillFrames = 0;
        _LaunchKind = EMars_LaunchKind::Throw;
        _Use.Request_Throw();
    }

    UFUNCTION()
    private void Check_RockHeldAndRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_HeldItem.Get_CurrentItem()) && _Intents.Get_Matcher() == _Matcher
            && _Hands.Get_Hold().Kind != EMars_FPHands_HoldKind::Empty && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_SpawnLooseRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = InHandle;
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Rock()),
            FTransform(FRotator::ZeroRotator, _Origin + FVector(100.0, 0.0, 20.0)));
        utils_world_item::Request_SpawnWorld(Owner, Spec);
    }

    UFUNCTION()
    private void Step_Launch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (_LaunchKind == EMars_LaunchKind::Throw)
        { _Use.Request_Throw(); }
        else
        { _Use.Request_Drop(); }
    }

    // The launched rock is the World-mode world item near the carrier (the only one this rig spawns; found from the frame it
    // exists and focused then); it has moved less than 1.5 mm a frame for 10 frames (a sphere in the trough may still creep).
    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Landed))
        {
            _Landed = Find_LaunchedRock(InHandle);
            if (ck::Is_NOT_Valid(_Landed))
            {
                Res.Set(false);
                return;
            }

            FCk_Handle LandedEntity = _Landed;
            Track_ForCleanup(LandedEntity);

            // The player looks where it throws: the rock is focused from the frame it exists, in flight, before its
            // holder has even adopted the item.
            auto Pickup = _Landed.Get_Pickup();
            Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        }

        FCk_Handle Entity = _Landed;
        const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
        const auto IsStill = _LastLandedLocation.IsSet() && _LastLandedLocation.GetValue().Equals(Location, 0.15);
        _StillFrames = IsStill ? _StillFrames + 1 : 0;
        _LastLandedLocation = TOptional<FVector>(Location);
        Res.Set(_StillFrames >= 10 && Location.Z < _Origin.Z + 30.0);
    }

    private FCk_Handle_WorldItem Find_LaunchedRock(FCk_Handle InHandle) const
    {
        const auto WorldItems = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem");
        for (const auto& Entity : WorldItems)
        {
            if (ck::Is_NOT_Valid(Entity) || Entity.Is_WorldItem() == false)
            { continue; }

            const auto WorldItem = Entity.As_WorldItem();
            if (WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
            if (Location.Distance(_Origin) < 1000.0)
            { return WorldItem; }
        }

        return FCk_Handle_WorldItem();
    }

    UFUNCTION()
    private void Step_FocusAndOffer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Landed;
        const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
        Log(f"[PickupByPress] the {_LaunchKind :n} rock lies {(Location - _Origin).Size2D()} cm from the carrier");

        _OfferedTarget = Get_UseTarget();
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_OfferedTarget));
    }

    UFUNCTION()
    private void Check_Focused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(Get_UseTarget().As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    private void Step_PressUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Inject_UseKey(ECk_InputSource_EventType::Pressed);
    }

    // Logs the held row's activation frame first: the frame each hold is known by.
    UFUNCTION()
    private void Step_ReleaseUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Frame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Use);
        auto FrameText = FString("unset");
        if (Frame.IsSet())
        { FrameText = f"{Frame.GetValue()}"; }

        Log(f"[PickupByPress] releasing Use: the row's activation frame is {FrameText}");
        Inject_UseKey(ECk_InputSource_EventType::Released);
    }

    // A transient rock's world item ends once its holder gives the item up.
    UFUNCTION()
    private void Check_Stowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Landed) || ck::Is_NOT_Valid(_Landed.Get_HeldItem()));
    }

    UFUNCTION()
    private void Step_AssertRefusedAndStowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RefusedTargets.Contains(_OfferedTarget), "the gloves, full with a two-handed rock, refused the reach for it");
        Assert_True(ck::IsValid(_Hotbar.Get_ItemAt(0)) && ck::IsValid(_Hotbar.Get_ItemAt(1)), "both bag slots hold a rock");
        Assert_True(_HeldItem.Get_CurrentItem() == _Hotbar.Get_ItemAt(0), "the first rock stays in the hands");
    }

    // The frames a press is known by, read in the matcher's own phase broadcast (where the player's intent task reads them).
    UFUNCTION()
    private void OnRigIntentPhaseChanged(FCk_Handle_IntentMatcher InMatcher, FName InIntentName, FGameplayTag InIntentTag,
                                         ECk_Intent_Phase InPreviousPhase, ECk_Intent_Phase InNewPhase, int32 InFrame)
    {
        if (InIntentTag != GameplayTags::Mars_Intent_Interact_Use || InNewPhase != ECk_Intent_Phase::Active || InPreviousPhase == ECk_Intent_Phase::Active)
        { return; }

        const auto Row = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Use);
        auto RowText = FString("unset");
        if (Row.IsSet())
        { RowText = f"{Row.GetValue()}"; }

        Log(f"[PickupByPress] Use pressed: matcher frame {InFrame}, the row's activation frame then {RowText}");
    }

    UFUNCTION()
    private void OnRigReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind)
    {
        _RefusedTargets.Add(InTarget);
    }

    UFUNCTION()
    private void Step_AssertStowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto InABagSlot = ck::IsValid(_Hotbar.Get_ItemAt(0)) || ck::IsValid(_Hotbar.Get_ItemAt(1));
        Assert_True(InABagSlot, "the rock is in a bag slot");
        Assert_True(ck::Is_NOT_Valid(_Landed) || ck::Is_NOT_Valid(_Landed.Get_HeldItem()), "the world item gave its rock up");
    }
}
