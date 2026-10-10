// The player's tasks the player-path rig runs on its carrier, as Alive and Locomotion run them: the view trace -> focus,
// the Use row -> resolver intent and its interaction, the held-item -> gloves link and the gloves' Hands sub-SM.
class UMars_AutoTestState_PlayerPathRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_InteractionFocus);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesHands);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

// A carrier composed the way the player is, down the whole path from the view to the hands: Hotbar (two bag slots),
// HeldItem, gloves (FPHands on the Hand node, the Hands sub-SM), a Use resolver, InputIntents fed by a private Use key
// (UMars_AutoTestHelper_UseKey), and the player's interaction trace (utils_player_viewpoint::Make_InteractionTraceSettings)
// from an eye node _EyeHeight above the carrier that the rig aims - what utils_player_viewpoint::Add gives the player,
// without its camera. A static floor lies under and in front of the carrier.
// The test composes the player's real tasks (Get_RigStateClass: UMars_AutoTestState_PlayerPathRig) once the Use row is
// live, then presses, releases and aims. A subclass adds key rows (Get_ExtraKeyRows) and resolver mappings
// (Make_ResolverSpec) and composes its own rig state.
UCLASS(Abstract)
class UMars_AutoTestRig_PlayerPath : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    // The trace's reach (the player's default).
    protected const float32 k_TraceDistance = 250.0f;

    // The eye above the floor; a test that wants it higher sets it before Build_PlayerPath.
    protected float64 _EyeHeight = 15.0;

    protected FVector _Origin;
    protected FCk_Handle_InputIntents _Intents;
    protected FCk_Handle_InteractionResolver _Resolver;
    protected UMars_AutoTestHelper_UseKey _UseKey;
    protected FCk_Handle_SceneNode _Eye;
    protected FCk_Handle_StateMachine _Sm;

    protected void Build_PlayerPath(FCk_Handle InHandle, FVector InOrigin)
    {
        _Origin = InOrigin;
        Add_CarrierBodyWithBack(InHandle, InOrigin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Intents = utils_input_intents::Add(_Carrier);
        _Resolver = utils_interaction_resolver::Add(_Carrier, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);

        _UseKey = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _UseKey.Build_WithRows(InHandle, EKeys::F9, Get_ExtraKeyRows());

        auto HandsSpec = FMars_FPHands_Spec();
        HandsSpec.HandNode = _HandNode;
        _Hands = utils_fphands::Add(_Carrier, HandsSpec);
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnCarrierHandsPhaseChanged"));

        Add_ViewTrace();
        Add_StaticBox(InHandle, FVector(150.0, 0.0, -1.0), FVector(400.0, 400.0, 1.0));
    }

    // Up to a composed, idle rig: the Use row is live on the carrier's matcher, the player's tasks run and the gloves rest,
    // listening. The view looks away from everything.
    protected void Add_Steps_UntilReady()
    {
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_UseKeyRecording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step("compose the player's tasks on the carrier", n"Step_ComposePlayerPath");
        Add_Step_WaitUntil("the player reads the matcher and the gloves rest, listening", n"Check_PlayerPathReady", 0, 0);
    }

    // Spawns a world item of InDefinition at InLocal (from the origin) on the floor. Returns the entity under construction.
    protected FCk_Handle Spawn_WorldItem(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition, FVector InLocal)
    {
        auto Owner = InHandle;
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(InDefinition),
            FTransform(FRotator::ZeroRotator, _Origin + InLocal));
        return utils_world_item::Request_SpawnWorld(Owner, Spec);
    }

    // Spawns a meat slab's food item dropped from InLocal (from the origin). A piece outlives its spawner: it lives under the
    // world's transient entity, tracked for cleanup. Returns the entity under construction.
    protected FCk_Handle Spawn_Slab(FVector InLocal)
    {
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + InLocal);
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        auto Entity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(Entity);
        return Entity;
    }

    // A pulled lever (a ManuallyCompleted Control) whose interactable is a Probe.Mars.Interact sphere of InRadius at
    // InWorld: something the view trace hits that has no body of its own. Its root is a child of InOwner.
    protected FCk_Handle_Interactable Build_ProbedLever(FCk_Handle InOwner, FVector InWorld, float32 InRadius)
    {
        auto Owner = InOwner;
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(Owner);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, InWorld), ECk_Replication::DoesNotReplicate);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        auto Control = utils_control::Add(RootEntity, ControlSpec, FCk_Handle_Mover());

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InRadius));
        Probe.ProbeOffset = FTransform::Identity;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Control.Make_InteractTarget(FText::FromString("Pull")));
        return utils_interactable::Create(Root, Spec);
    }

    // A constructed world item (its holder holds its item).
    protected bool Get_IsConstructedWorldItem(FCk_Handle InEntity) const
    {
        return ck::IsValid(InEntity) && InEntity.Is_WorldItem() && ck::IsValid(InEntity.As_WorldItem().Get_HeldItem());
    }

    // InEntity lies under the view trace (the trace overlaps it this pass).
    protected bool Get_IsUnderTheTrace(FCk_Handle InEntity) const
    {
        const auto Overlaps = _Carrier.As_PlayerViewpoint().Get_InteractionTrace().Get_CurrentOverlaps();
        for (auto Overlap : Overlaps)
        {
            if (Overlap.Get_OtherEntity() == InEntity)
            { return true; }
        }

        return false;
    }

    // The eye's world location.
    protected FVector Get_EyeWorld() const
    {
        return _Origin + FVector(0.0, 0.0, _EyeHeight);
    }

    // Turns the eye toward InWorld: the trace now runs from the eye through it.
    protected void Aim_ViewAt(FVector InWorld)
    {
        const auto EyeLocal = FVector(0.0, 0.0, _EyeHeight);
        const auto Direction = InWorld - (_Origin + EyeLocal);
        Set_EyeOffset(FTransform(Direction.Rotation(), EyeLocal, FVector::OneVector));
    }

    // Turns the eye to look along +Y, where nothing lies.
    protected void Aim_ViewAway()
    {
        Set_EyeOffset(FTransform(FRotator(0.0, 90.0, 0.0), FVector(0.0, 0.0, _EyeHeight), FVector::OneVector));
    }

    protected bool Get_IsUseHeld()
    {
        return _Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use);
    }

    protected FCk_Handle_InteractTarget Get_UseTarget(const FCk_Handle_WorldItem& InWorldItem) const
    {
        auto Pickup = InWorldItem.Get_Pickup();
        return Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }

    // The state the rig composes on the carrier once the Use row is live.
    protected TSubclassOf<UCk_SmState_EntityScript> Get_RigStateClass() const
    { return UMars_AutoTestState_PlayerPathRig; }

    // Key rows baked beside the Use row on the carrier's matcher (none: the Use row alone).
    protected TArray<FMars_AutoTestHelper_KeyRow> Get_ExtraKeyRows() const
    { return TArray<FMars_AutoTestHelper_KeyRow>(); }

    private void Set_EyeOffset(FTransform InOffset)
    {
        utils_scene_node::Request_UpdateOffset(_Eye, FCk_Request_SceneNode_UpdateRelativeTransform(InOffset));
    }

    protected FCk_InteractionResolver_Spec Make_ResolverSpec() const
    {
        auto Channels = TArray<FGameplayTag>();
        Channels.Add(GameplayTags::InteractionChannel_Mars_Use);

        // The trace offers one target at a time: no distance sort.
        auto Mapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, Channels);
        Mapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(Mapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    // The player's interaction trace from an eye node on the carrier's root, looking away.
    private void Add_ViewTrace()
    {
        auto Root = _Carrier.As_Transform();
        _Eye = utils_scene_node::Create(Root, FTransform(FRotator(0.0, 90.0, 0.0), FVector(0.0, 0.0, _EyeHeight), FVector::OneVector));
        auto EyeTransform = _Eye.As_Transform();

        const auto TraceSettings = utils_player_viewpoint::Make_InteractionTraceSettings(EyeTransform, k_TraceDistance, _Carrier);

        auto Viewpoint = FMars_Fragment_PlayerViewpoint();
        Viewpoint.Viewpoint = EyeTransform;
        Viewpoint.InteractionTrace = utils_probe_trace::Create_LineTrace_Persistent(TraceSettings);

        _Carrier.Add_Fragment(FMars_Feature_PlayerViewpoint());
        _Carrier.Add_Fragment(Viewpoint);
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

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_UseKeyRecording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsRecording());
    }

    UFUNCTION()
    protected void Step_SwapUseSet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Swapped = _UseKey.Request_SwapUseSet();
        if (Swapped.IsValid() == false)
        { FinishFailure(Swapped.Get_Error()); }
    }

    UFUNCTION()
    protected void Check_UseSetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsUseSetActive());
    }

    UFUNCTION()
    protected void Step_ComposePlayerPath(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_UseKey.Get_Matcher()));
        _Sm = utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(Get_RigStateClass()));
    }

    UFUNCTION()
    protected void Check_PlayerPathReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_Matcher() == _UseKey.Get_Matcher()
            && utils_state_machine::IsInState(_Sm, Get_RigStateClass())
            && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    protected void Step_PressUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Press();
    }

    UFUNCTION()
    protected void Step_ReleaseUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Release();
    }

    UFUNCTION()
    protected void Check_UseHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsUseHeld());
    }

    UFUNCTION()
    protected void Check_UseReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsUseHeld() == false);
    }
}
