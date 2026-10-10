// A pickup lands at the gloves' Grip. A carrier with gloves reaches for a meat slab (as the resolver would) and starts its
// pickup: every frame before the gloves' Grip the slab's mount is World and it lies where it lay; it is stowed within a few
// frames of the Grip into the empty hands' bag slot, which selects itself, so it is Held on the carrier's Hand. A second carrier without gloves picks up a second slab: it is stowed at once
// (no reach to wait for) and Held on its Hand. Isolated origin (23600, -15000, -30000).
class UMars_AutoTest_WorldItem_APickupWaitsForTheGrip : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(23600.0, -15000.0, -30000.0);
    private const FVector k_SlabOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_BareOffset = FVector(0.0, 400.0, 0.0);
    // From the bare pickup's start: the target's drain that starts the interaction, the interactable's step into its
    // pickup state (whose task, with no gloves, asks the transfer at once), the holder's transfer drain and the poll
    // after it. A wrongly awaited grip would take the reach window.
    private const int32 k_MaxBareStowFrames = 5;
    // The slabs' construction (their joints import), their fall onto their floors and the mounts' arrivals outrun the
    // default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;
    // A body slower than this (cm/s) for k_RestPolls polls in a row lies still: one slow poll may be a bounce's top.
    private const float64 k_RestSpeed = 2.0;
    private const int32 k_RestPolls = 10;
    // A stow at the Grip lands within a few frames of it.
    private const float64 k_AtGripSeconds = 0.25;

    private FCk_Handle _SlabEntity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle _BareSlabEntity;
    private FCk_Handle_WorldItem _BareSlab;

    private FCk_Handle _BareCarrier;
    private FCk_Handle_Hotbar _BareHotbar;
    private FCk_Handle_Transform _BareHandNode;

    private FTransform _SlabWorldAtStart;
    private int32 _FramesBeforeGrip = 0;
    private int32 _MovedFramesBeforeGrip = 0;
    private bool _StowedBeforeGrip = false;
    // Game time the gloves were first seen in Grip, and the slab's holder first seen empty.
    private TOptional<float64> _GripSeconds;
    private TOptional<float64> _StowSeconds;
    // The frame the bare pickup started, and the frame its slab was first seen stowed.
    private int64 _BarePickUpFrame = -1;
    private int64 _BareStowSeenFrame = -1;
    private int32 _RestPolls = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        Add_CarrierHands();
        Build_BareCarrier(InHandle);

        _SlabEntity = Spawn_Slab(InHandle, k_Origin + k_SlabOffset);
        _BareSlabEntity = Spawn_Slab(InHandle, k_Origin + k_BareOffset + k_SlabOffset);

        Add_Step_WaitUntil("both slabs are constructed and their bodies added", n"Check_SlabsReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step_WaitUntil("the slabs lie still on their floors", n"Check_SlabsAtRest", k_SlowPolls, 0);
        Add_Step("each carrier focuses its slab's pickup", n"Step_FocusBoth");
        Add_Step_WaitUntil("the pickups' targets enter Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier reaches for its slab and picks it up", n"Step_ReachAndPickUp");
        Add_Step_WaitUntil("the gloves close on the slab (every frame before: World, where it lay)", n"Check_GripWatchingTheSlab", k_SlowPolls, 0);
        Add_Step_WaitUntil("the slab is stowed and Held on the hand", n"Check_SlabInTheHand", k_SlowPolls, 0);
        Add_Step("nothing moved before the Grip; after it the slab is Held", n"Step_AssertWaitedForTheGrip");
        Add_Step("the bare carrier picks its slab up", n"Step_BarePickUp");
        Add_Step_WaitUntil("the bare carrier's slab is stowed at once", n"Check_BareStowed", 0, 0);
        Add_Step_WaitUntil("and Held on its hand", n"Check_BareInTheHand", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    // A carrier with a Hand node, a Back node and a hotbar, and no gloves.
    private void Build_BareCarrier(FCk_Handle InHandle)
    {
        _BareCarrier = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_BareCarrier, FTransform(FRotator::ZeroRotator, k_Origin + k_BareOffset), ECk_Replication::DoesNotReplicate);
        _BareHandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        auto BackNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(-30.0, 0.0, 20.0))).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _BareHandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, BackNode));
        utils_attach_points::Add(_BareCarrier, AttachPointsSpec);

        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        _BareHotbar = utils_hotbar::Add(_BareCarrier, Spec);
    }

    // A meat slab lying on a static floor whose top is at InTop; a piece outlives its spawner, so it lives under the world's
    // transient entity, tracked for cleanup.
    private FCk_Handle Spawn_Slab(FCk_Handle InOwner, FVector InTop)
    {
        auto Owner = InOwner;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(80.0, 80.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InTop + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        auto Entity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(Entity);
        return Entity;
    }

    UFUNCTION()
    private void Check_SlabsReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Slab) && Get_IsConstructed(_SlabEntity))
        { _Slab = _SlabEntity.As_WorldItem(); }

        if (ck::Is_NOT_Valid(_BareSlab) && Get_IsConstructed(_BareSlabEntity))
        { _BareSlab = _BareSlabEntity.As_WorldItem(); }

        auto Res = OutResult;
        Res.Set(ck::IsValid(_Slab) && ck::IsValid(_BareSlab)
            && utils_jolt_body::Get_IsBodyAdded(_Slab.Get_Body()) && utils_jolt_body::Get_IsBodyAdded(_BareSlab.Get_Body()));
    }

    UFUNCTION()
    private void Check_SlabsAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsSlow = utils_jolt_body::Get_LinearVelocity(_Slab.Get_Body()).Size() < k_RestSpeed
            && utils_jolt_body::Get_LinearVelocity(_BareSlab.Get_Body()).Size() < k_RestSpeed;
        _RestPolls = IsSlow ? _RestPolls + 1 : 0;

        auto Res = OutResult;
        Res.Set(_RestPolls >= k_RestPolls);
    }

    private bool Get_IsConstructed(FCk_Handle InEntity) const
    {
        return ck::IsValid(InEntity) && InEntity.Is_WorldItem() && ck::IsValid(InEntity.As_WorldItem().Get_HeldItem());
    }

    UFUNCTION()
    private void Step_FocusBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Slab.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        auto BarePickup = _BareSlab.Get_Pickup();
        BarePickup.Request_Focus(FMars_Request_Interactable_Focus(_BareCarrier));
        Await_FocusOf(Pickup);
        Await_FocusOf(BarePickup);
    }

    // What the player's resolver and interaction glue do on a press: the gloves reach for the pickup's target, and the
    // interaction starts.
    UFUNCTION()
    private void Step_ReachAndPickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SlabWorldAtStart = utils_transform::Get_EntityCurrentTransform(_SlabEntity.As_Transform());

        auto Pickup = _Slab.Get_Pickup();
        auto Target = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(Target, Pickup, _SlabEntity),
            ECk_Interaction_CompletionPolicy::Instant));
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_GripWatchingTheSlab(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsGripped = _HandPhases.Contains(EMars_FPHands_Phase::Grip);
        if (IsGripped == false)
        {
            ++_FramesBeforeGrip;
            const auto SlabWorld = utils_transform::Get_EntityCurrentTransform(_SlabEntity.As_Transform());
            if (_Slab.Get_Mount() != EMars_WorldItem_Mount::World || SlabWorld.GetLocation().Equals(_SlabWorldAtStart.GetLocation(), 1.0) == false)
            { ++_MovedFramesBeforeGrip; }

            // Stowed = its holder gave the item up.
            if (ck::Is_NOT_Valid(_Slab.Get_HeldItem()))
            { _StowedBeforeGrip = true; }
        }

        if (IsGripped && _GripSeconds.IsSet() == false)
        { _GripSeconds = TOptional<float64>(System::GetGameTimeInSeconds()); }

        auto Res = OutResult;
        Res.Set(IsGripped);
    }

    UFUNCTION()
    private void Check_SlabInTheHand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Slab.Get_HeldItem()) && _StowSeconds.IsSet() == false)
        { _StowSeconds = TOptional<float64>(System::GetGameTimeInSeconds()); }

        auto Res = OutResult;
        Res.Set(_Slab.Get_Mount() == EMars_WorldItem_Mount::Held && Get_MountParent(_Slab) == _HandNode);
    }

    UFUNCTION()
    private void Step_AssertWaitedForTheGrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_HandPhases.Num() > 0 && _HandPhases[0] == EMars_FPHands_Phase::Reach, "the gloves reached first");
        Assert_True(_FramesBeforeGrip > 1, f"the gloves took frames to reach ({_FramesBeforeGrip})");
        Assert_Equals_Int(_MovedFramesBeforeGrip, 0, "before the Grip the slab stayed World, where it lay");
        Assert_False(_StowedBeforeGrip, "before the Grip the slab was not stowed");
        const auto StowDelay = _StowSeconds.IsSet() && _GripSeconds.IsSet() ? _StowSeconds.GetValue() - _GripSeconds.GetValue() : -1.0;
        Assert_True(StowDelay >= 0.0 && StowDelay < k_AtGripSeconds, f"it was stowed at the Grip ({StowDelay} s after it)");
        Assert_True(_Slab.Get_Carrier() == _Carrier, "the carrier carries it");
    }

    UFUNCTION()
    private void Step_BarePickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _BareSlab.Get_Pickup();
        auto Target = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_BareCarrier, _BareCarrier));
        _BarePickUpFrame = utils_time::Get_FrameCounter();
    }

    // Asserts the frame bound itself when it holds: the step after it is a wait.
    UFUNCTION()
    private void Check_BareStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::IsValid(_BareSlab.Get_HeldItem()))
        {
            Res.Set(false);
            return;
        }

        _BareStowSeenFrame = utils_time::Get_FrameCounter();
        const auto Frames = _BareStowSeenFrame - _BarePickUpFrame;
        Assert_True(Frames <= k_MaxBareStowFrames,
            f"the bare carrier's slab was stowed within {k_MaxBareStowFrames} frames of its pickup (took {Frames})");
        Res.Set(true);
    }

    UFUNCTION()
    private void Check_BareInTheHand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_BareSlab.Get_Mount() == EMars_WorldItem_Mount::Held && Get_MountParent(_BareSlab) == _BareHandNode
            && _BareSlab.Get_Carrier() == _BareCarrier);
    }

    // Invalid while the world item is not scene-node attached.
    private FCk_Handle_Transform Get_MountParent(FCk_Handle_WorldItem InWorldItem) const
    {
        auto Node = InWorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }
}
