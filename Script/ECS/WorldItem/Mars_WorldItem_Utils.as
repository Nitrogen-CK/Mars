namespace utils_world_item
{
    // The entity script composes the holder, body, pickup and visual first and hands their handles in through the Spec. The
    // item is linked once the holder holds it (Add_Item).
    FCk_Handle_WorldItem Add(FCk_Handle& InHandle, FMars_WorldItem_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[WorldItem] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_WorldItem(); }

        auto Params = FMars_Fragment_WorldItem_Params();
        Params.Mode = InSpec.Mode;
        Params.Definition = InSpec.Definition;

        auto State = FMars_Fragment_WorldItem();
        if (InSpec.World.IsSet())
        {
            const auto& World = InSpec.World.GetValue();
            State.Holder = World.Holder;
            State.Pickup = World.Pickup;
            State.Body = World.Composition.Body;
            State.BodyProfile = World.Composition.BodyProfile;
            State.BoundsFit = World.Composition.BoundsFit;
        }

        InHandle.Add_Fragment(FMars_Feature_WorldItem());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        Add_ReachHint(InHandle, InSpec);

        // Never applied here: the body is not added for at least one frame. The launch processor drains it.
        if (InSpec.World.IsSet() && InSpec.World.GetValue().Composition.Launch.IsSet())
        { InHandle.Add_Fragment(InSpec.World.GetValue().Composition.Launch.GetValue()); }

        if (InSpec.Arrival.IsSet())
        { InHandle.Add_Fragment(InSpec.Arrival.GetValue()); }

        return InHandle.As_WorldItem();
    }

    // The second half of Add, once the holder has seeded or adopted InItem: a Persistent world item links InItem to itself
    // and stamps the item's back-link, so the item's moves reach this entity and its mount follows the inventory the item
    // lives in (UMars_Processor_WorldItem_Reconcile). A Transient world item links nothing.
    void Add_Item(FCk_Handle_WorldItem& InWorldItem, FCk_Handle_Item InItem)
    {
        if (ck::EnsureIfNot(ck::IsValid(InItem), f"[WorldItem] [{InWorldItem.ToString()}] has no item to link"))
        { return; }

        if (InWorldItem.Get_Persistence() != EMars_WorldItem_Persistence::Persistent)
        { return; }

        // The message is formatted whether or not the ensure fires: Get_Item reads an unset link as an invalid handle.
        const auto IsLinked = InWorldItem.Get_Fragment(FMars_Fragment_WorldItem).Item.IsSet();
        if (ck::EnsureIfNot(IsLinked == false,
            f"[WorldItem] [{InWorldItem.ToString()}] already links item [{InWorldItem.Get_Item().ToString()}], not [{InItem.ToString()}]"))
        { return; }

        auto Item = InItem;
        if (Item.Has_PersistentWorldItem())
        {
            const auto Existing = Item.Get_PersistentWorldItem();
            if (ck::EnsureIfNot(Existing == InWorldItem,
                f"[WorldItem] Item [{Item.ToString()}] is already linked to world item [{Existing.ToString()}], not [{InWorldItem.ToString()}]"))
            { return; }
        }
        else
        {
            auto Marker = FMars_Fragment_Item_PersistentWorldItem();
            Marker.WorldItem = InWorldItem;
            Item.Add_Fragment(Marker);
        }

        auto& State = InWorldItem.Get_Fragment(FMars_Fragment_WorldItem);
        State.Item = TOptional<FCk_Handle_Item>(Item);
    }

    // Marks InInventory as one whose Persistent items ride its lifetime owner as InMarker says. Called once, by whoever
    // composes the inventory.
    void Add_MountedInventory(FCk_Handle_Inventory_DataOnly& InInventory, FMars_Fragment_MountedInventory InMarker)
    {
        FCk_Handle InventoryEntity = InInventory;
        InventoryEntity.Add_Fragment(InMarker);
    }

    // Where InWorldItem belongs, from the inventory its item lives in: its own holder -> World; the selected slot of the
    // carrier's hotbar -> Held on the carrier's Hand at Presentation.Mounting.HeldOffset; any other inventory marked
    // FMars_Fragment_MountedInventory -> Carried on its lifetime owner as the marker says. Unlinked (Transient, Visual, not
    // yet seeded) -> World. The carrier is the inventory's lifetime owner and must publish the attach point.
    FMars_WorldItem_Resolution Resolve_Target(const FCk_Handle_WorldItem& InWorldItem)
    {
        auto Resolution = FMars_WorldItem_Resolution();
        const auto& State = InWorldItem.Get_Fragment(FMars_Fragment_WorldItem);
        if (State.Item.IsSet() == false)
        { return Resolution; }

        const auto Item = State.Item.GetValue();
        if (Get_IsEnding(Item))
        {
            Resolution.Placement = EMars_WorldItem_Placement::ItemGone;
            return Resolution;
        }

        auto Inventory = Item.Get_ParentInventory();
        Resolution.Inventory = Inventory;
        FCk_Handle InventoryEntity = Inventory;
        const FCk_Handle HolderEntity = State.Holder;
        if (ck::IsValid(Inventory) && InventoryEntity == HolderEntity)
        { return Resolution; }

        if (ck::Is_NOT_Valid(Inventory))
        {
            Resolution.Placement = EMars_WorldItem_Placement::Unmountable;
            return Resolution;
        }

        const auto Carrier = utils_entity_lifetime::Get_LifetimeOwner(InventoryEntity, ECk_PendingKill_Policy::IncludePendingKill);
        if (Get_IsEnding(InventoryEntity) || Get_IsEnding(Carrier))
        {
            Resolution.Placement = EMars_WorldItem_Placement::CarrierGone;
            return Resolution;
        }

        const UMars_ItemTrait_Presentation Presentation = TryGet_Presentation(InWorldItem);
        if (ck::Is_NOT_Valid(Presentation))
        {
            Resolution.Placement = EMars_WorldItem_Placement::Unmountable;
            return Resolution;
        }

        const auto& Mounting = Presentation.Mounting;
        const auto Hotbar = Carrier.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Hotbar) && Hotbar.Get_SelectedItem() == Item)
        {
            Resolution.Target = FMars_WorldItem_MountTarget(EMars_WorldItem_Mount::Held, Carrier, GameplayTags::AttachPoint_Mars_Hand,
                Mounting.HeldOffset);
        }
        else if (InventoryEntity.Has_Fragment(FMars_Fragment_MountedInventory))
        {
            const auto Marker = InventoryEntity.Get_Fragment(FMars_Fragment_MountedInventory);
            auto Point = Marker.Point;
            auto Offset = Marker.Offset;
            if (Marker.Rule == EMars_WorldItem_MountRule::ItemCarryPoint)
            {
                Point = Mounting.CarryPoint;
                Offset = Mounting.CarryOffset;
            }
            else if (Marker.Rule == EMars_WorldItem_MountRule::PointAtCargoOffset)
            { Offset = Mounting.CargoOffset; }

            Resolution.Target = FMars_WorldItem_MountTarget(EMars_WorldItem_Mount::Carried, Carrier, Point, Offset);
        }
        else
        {
            Resolution.Placement = EMars_WorldItem_Placement::Unmountable;
            return Resolution;
        }

        const auto AttachPoints = Carrier.As_AttachPoints(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(AttachPoints) || AttachPoints.Has_AttachPoint(Resolution.Target.Point) == false)
        { Resolution.Placement = EMars_WorldItem_Placement::Unmountable; }

        return Resolution;
    }

    // The same mount: the same kind, carrier and point at the same offset (World has neither).
    bool Get_IsSameMount(const FMars_WorldItem_MountTarget& InA, const FMars_WorldItem_MountTarget& InB)
    {
        if (InA.Mount != InB.Mount)
        { return false; }

        if (InA.Mount == EMars_WorldItem_Mount::World)
        { return true; }

        return InA.Carrier == InB.Carrier && InA.Point == InB.Point && InA.Offset.Equals(InB.Offset, 0.01);
    }

    // Invalid, or on its way out.
    bool Get_IsEnding(const FCk_Handle& InEntity)
    {
        return ck::Is_NOT_Valid(InEntity) || utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    // The World commit, called only by the WorldItem processors (a release's answer, and the reconcile's recovery): any
    // pending mount and arrival dropped, detached keeping its world pose, the body Dynamic with its own profile
    // (InOnProfileRestored records it) and InLaunch pending, the pickup's Mounted claim released, then OnMountChanged and
    // OnMountSettled.
    void Commit_World(FCk_Handle_WorldItem& InWorldItem, TOptional<FMars_Fragment_WorldItem_PendingLaunch> InLaunch,
                      FCk_Delegate_Request_OnCompleted InOnProfileRestored)
    {
        InWorldItem.Request_TryRemove(FMars_Fragment_WorldItem_PendingMount);
        InWorldItem.Request_TryRemove(FMars_Fragment_WorldItem_Arrival);

        auto SceneNode = InWorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(SceneNode))
        { utils_scene_node::Request_Detach(SceneNode); }

        auto& State = InWorldItem.Get_Fragment(FMars_Fragment_WorldItem);

        // The launch processor waits for the body to read Dynamic before applying the velocity.
        auto Body = State.Body;
        if (ck::IsValid(Body))
        {
            utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));
            utils_jolt_body::Request_SetCollisionProfile(Body, FCk_Request_JoltBody_SetCollisionProfile(State.BodyProfile), InOnProfileRestored);

            if (InLaunch.IsSet())
            {
                auto& Launch = InWorldItem.AddOrGet_Fragment(FMars_Fragment_WorldItem_PendingLaunch);
                Launch.LinearVelocity = InLaunch.GetValue().LinearVelocity;
                Launch.AngularVelocityDeg = InLaunch.GetValue().AngularVelocityDeg;
                Launch.WaitedPasses = 0;
            }
        }

        auto Pickup = State.Pickup;
        if (ck::IsValid(Pickup))
        { Pickup.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Mounted)); }

        const auto PrevMount = State.Committed.Mount;
        State.Committed = FMars_WorldItem_MountTarget();

        // State is not read past this line: a listener may add a fragment to the world item.
        if (InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_Signals) == false)
        { return; }

        if (PrevMount != EMars_WorldItem_Mount::World)
        { InWorldItem.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountChanged.Broadcast(InWorldItem, PrevMount, EMars_WorldItem_Mount::World); }

        if (InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_Signals))
        { InWorldItem.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountSettled.Broadcast(InWorldItem, EMars_WorldItem_Mount::World, FCk_Handle()); }
    }

    // InSpec InElapsedSeconds after it was asked for: the delay shrinks first, then the travel (a travel already over
    // snaps in the next frame).
    FMars_WorldItem_ArriveSpec Get_ArriveSpecAfter(const FMars_WorldItem_ArriveSpec& InSpec, float32 InElapsedSeconds)
    {
        const auto Elapsed = Math::Max(0.0f, InElapsedSeconds);
        const auto Overshoot = Math::Max(0.0f, Elapsed - InSpec.DelaySeconds);
        return FMars_WorldItem_ArriveSpec(Math::Max(0.0f, InSpec.DelaySeconds - Elapsed),
            Math::Max(0.0f, InSpec.Seconds - Overshoot), InSpec.Easing);
    }

    // A World-mode item tells a reach what its body spans and how many hands its Presentation takes it with. No
    // Presentation: no hint (the gloves fall back to sockets or a point). A Presentation that fails Validate (no
    // handedness) ensures and hints nothing.
    void Add_ReachHint(FCk_Handle& InHandle, const FMars_WorldItem_Spec& InSpec)
    {
        if (InSpec.World.IsSet() == false)
        { return; }

        auto Definition = System::LoadAsset_Blocking(InSpec.Definition);
        if (ck::Is_NOT_Valid(Definition))
        { return; }

        const UMars_ItemTrait_Presentation Presentation = Definition.Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
        if (ck::Is_NOT_Valid(Presentation))
        { return; }

        const auto Validation = Presentation.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[WorldItem] [{InHandle.ToString()}] has a Presentation the gloves cannot hold: {Validation.Get_Error()}"))
        { return; }

        utils_reach_hint::Add(InHandle,
            FMars_Fragment_ReachHint(InSpec.World.GetValue().Composition.BoundsFit, Presentation.Grip.Handedness, Presentation.Grip.HalfWidth));
    }

    // A Visual-mode world item of InSpec.Item, owned by InOwner (it dies with it). It spawns where it starts - at
    // ArriveFrom when set (then lerps in), else at rest - so the first rendered frame is already there.
    FCk_Handle Request_SpawnVisual(FCk_Handle& InOwner, const FMars_WorldItem_VisualSpec& InSpec)
    {
        auto Item = InSpec.Item;
        const auto AttachWorld = utils_transform::Get_EntityCurrentTransform(InSpec.AttachTo);

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.SpawnTransform = InSpec.AttachOffset * AttachWorld;
        if (InSpec.ArriveFrom.IsSet)
        { SpawnParams.SpawnTransform = InSpec.ArriveFrom.World; }

        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(Item.Get_Definition());
        SpawnParams.Mode = EMars_WorldItem_Mode::Visual;
        SpawnParams.AttachTo = InSpec.AttachTo;
        SpawnParams.AttachOffset = InSpec.AttachOffset;
        SpawnParams.ArriveFrom = InSpec.ArriveFrom;

        auto Pending = utils_entity_script::Request_SpawnEntity(InOwner, Get_WorldItemScriptClass(Item), SpawnParams);
        return Pending.Get_EntityUnderConstruction();
    }

    // A World-mode world item seeded from InSpec.Definition, owned by InOwner (ck::TransientEntity() for something that
    // must outlive its spawner). Uses the definition's Presentation.WorldItem.ScriptClass, else the base script. The
    // launch goes through the PendingLaunch processor once the body exists. An unresolved definition ensures and spawns
    // nothing.
    FCk_Handle Request_SpawnWorld(FCk_Handle& InOwner, const FMars_WorldItem_WorldSpec& InSpec)
    {
        const auto Definition = InSpec.Definition.Get();
        if (ck::EnsureIfNot(ck::IsValid(Definition), f"[WorldItem] Request_SpawnWorld from [{InOwner.ToString()}] has no resolvable definition"))
        { return FCk_Handle(); }

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(InSpec.World.Rotator(), InSpec.World.GetLocation());
        SpawnParams.Definition = InSpec.Definition;
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.LaunchVelocity = InSpec.LinearVelocity;
        SpawnParams.AngularVelocityDeg = InSpec.AngularVelocityDeg;

        auto Pending = utils_entity_script::Request_SpawnEntity(InOwner, Get_WorldItemScriptClass(Definition), SpawnParams);
        return Pending.Get_EntityUnderConstruction();
    }

    // Unset when InPending is older than constants_world_item::k_ArriveFromMaxAgeSeconds.
    FMars_WorldItem_Arrival Get_FreshArrival(const FMars_WorldItem_PendingArrival& InPending)
    {
        const auto AgeSeconds = System::GetGameTimeInSeconds() - InPending.StampedAtSeconds;
        if (AgeSeconds > constants_world_item::k_ArriveFromMaxAgeSeconds)
        { return FMars_WorldItem_Arrival(); }

        return FMars_WorldItem_Arrival(InPending.World);
    }

    // For a container that recorded where a moving item visually was (FMars_WorldItem_PendingArrival) and reacts to what
    // lands: the arrival for InItem when the record is for InItem and fresh, else unset. The record is cleared either way,
    // so it never outlives the next content change.
    FMars_WorldItem_Arrival Consume_PendingArrival(TOptional<FMars_WorldItem_PendingArrival>& InOutPending, const FCk_Handle_Item& InItem)
    {
        auto Arrival = FMars_WorldItem_Arrival();
        if (InOutPending.IsSet() && InOutPending.GetValue().Item == InItem)
        { Arrival = Get_FreshArrival(InOutPending.GetValue()); }

        InOutPending.Reset();
        return Arrival;
    }

    // The world pose of InEntity when it has a transform yet (a pending visual may not), else of InFallback.
    FTransform Get_WorldOf(const FCk_Handle& InEntity, const FCk_Handle& InFallback)
    {
        const auto EntityTransform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(EntityTransform))
        { return utils_transform::Get_EntityCurrentTransform(EntityTransform); }

        return utils_transform::Get_EntityCurrentTransform(InFallback.As_Transform());
    }

    // Null when the definition does not resolve or carries no Presentation trait.
    const UMars_ItemTrait_Presentation TryGet_Presentation(const FCk_Handle_WorldItem& InWorldItem)
    {
        auto Definition = InWorldItem.Get_Definition();
        if (ck::Is_NOT_Valid(Definition))
        { return nullptr; }

        const UMars_ItemTrait_Presentation Presentation = Definition.Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
        return Presentation;
    }

    // The item's Presentation.WorldItem.ScriptClass, else the base WorldItem entity script.
    TSubclassOf<UMars_WorldItem_EntityScript> Get_WorldItemScriptClass(const FCk_Handle_Item& InItem)
    {
        return Get_WorldItemScriptClass(InItem.Get_Definition());
    }

    // The definition's Presentation.WorldItem.ScriptClass, else the base WorldItem entity script.
    TSubclassOf<UMars_WorldItem_EntityScript> Get_WorldItemScriptClass(const UCk_InventoryItem_Definition InDefinition)
    {
        TSubclassOf<UMars_WorldItem_EntityScript> ScriptClass = UMars_WorldItem_EntityScript;
        if (ck::Is_NOT_Valid(InDefinition))
        { return ScriptClass; }

        const UMars_ItemTrait_Presentation Presentation = InDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
        if (ck::IsValid(Presentation) && ck::IsValid(Presentation.WorldItem.ScriptClass))
        { ScriptClass = Presentation.WorldItem.ScriptClass; }

        return ScriptClass;
    }

    // The shape every probe on the item's body uses (the pickup, a backpack's weight probe): the Make_BoundsFit box, or
    // a sphere of WorldItem.PickupProbeRadius at the root when there is no Mesh.
    FMars_WorldItem_ProbeFit Make_ProbeFit(const UMars_ItemTrait_Presentation InPresentation)
    {
        if (ck::Is_NOT_Valid(TryLoad_Mesh(InPresentation)))
        {
            return FMars_WorldItem_ProbeFit(
                utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InPresentation.WorldItem.PickupProbeRadius)), FTransform::Identity);
        }

        const auto Fit = Make_BoundsFit(InPresentation);
        return FMars_WorldItem_ProbeFit(utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(Fit.HalfExtents)),
            FTransform(FRotator::ZeroRotator, Fit.Centre));
    }

    // A box over the Mesh bounds (x MeshScale, matching the body), centred on them since a mesh's pivot need not be its
    // centre; a cube of half extent WorldItem.PickupProbeRadius at the root when there is no Mesh.
    FMars_WorldItem_BoundsFit Make_BoundsFit(const UMars_ItemTrait_Presentation InPresentation)
    {
        const auto Mesh = TryLoad_Mesh(InPresentation);
        if (ck::Is_NOT_Valid(Mesh))
        {
            const auto Radius = InPresentation.WorldItem.PickupProbeRadius;
            return FMars_WorldItem_BoundsFit(FVector(Radius, Radius, Radius), FVector::ZeroVector);
        }

        const auto Bounds = Mesh.GetBounds();
        const auto Scale = InPresentation.Visual.MeshScale;
        const auto HalfExtents = FVector(Math::Abs(Bounds.BoxExtent.X * Scale.X), Math::Abs(Bounds.BoxExtent.Y * Scale.Y),
                                         Math::Abs(Bounds.BoxExtent.Z * Scale.Z));
        return FMars_WorldItem_BoundsFit(HalfExtents, Bounds.Origin * Scale);
    }

    // Null when the Presentation names no mesh or it does not load.
    UStaticMesh TryLoad_Mesh(const UMars_ItemTrait_Presentation InPresentation)
    {
        if (InPresentation.Visual.Mesh.IsNull())
        { return nullptr; }

        return System::LoadAsset_Blocking(InPresentation.Visual.Mesh);
    }

    // Per-channel blend, slerp on rotation so a >180 degree turn takes the short way.
    FTransform Blend(FTransform InFrom, FTransform InTo, float32 InAlpha)
    {
        const auto Loc   = Math::Lerp(InFrom.GetLocation(), InTo.GetLocation(), InAlpha);
        const auto Rot   = FQuat::Slerp(InFrom.GetRotation(), InTo.GetRotation(), InAlpha).Rotator();
        const auto Scale = Math::Lerp(InFrom.GetScale3D(), InTo.GetScale3D(), InAlpha);
        return FTransform(Rot, Loc, Scale);
    }

    // Claims (Disable) or releases (Enable) InReason on the pickup of InEntity's world item: a ledger that holds an item's
    // entity (a whole food on a board or in a pan) keeps a hand from taking it until it lets go, whatever other claimant
    // releases in between. An entity that is no World-mode world item has no pickup and needs nothing.
    void Request_ClaimPickup(FCk_Handle InEntity, EMars_Interactable_DisableReason InReason, ECk_EnableDisable InEnableDisable)
    {
        if (InEntity.Is_WorldItem() == false)
        { return; }

        auto Pickup = InEntity.As_WorldItem().Get_Pickup();
        if (ck::Is_NOT_Valid(Pickup))
        { return; }

        if (InEnableDisable == ECk_EnableDisable::Disable)
        { Pickup.Request_Disable(FMars_Request_Interactable_Disable(InReason)); }
        else
        { Pickup.Request_Enable(FMars_Request_Interactable_Enable(InReason)); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_WorldItem_Mode Get_Mode(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem_Params).Mode;
}

// Null when the soft reference does not resolve.
mixin UCk_InventoryItem_Definition Get_Definition(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem_Params).Definition.Get();
}

// Invalid in Visual mode.
mixin FCk_Handle_Inventory_DataOnly Get_Holder(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Holder;
}

// Invalid in Visual mode, and while the holder is empty.
mixin FCk_Handle_Item Get_HeldItem(const FCk_Handle_WorldItem& Self)
{
    const auto Holder = Self.Get_Holder();
    return Holder.Get_SoleItem();
}

// The item a Persistent world item is the body of, wherever it lives; invalid before its holder seeded or adopted it, and
// for a Transient or Visual-mode world item.
mixin FCk_Handle_Item Get_Item(const FCk_Handle_WorldItem& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_WorldItem);
    if (State.Item.IsSet() == false)
    { return FCk_Handle_Item(); }

    return State.Item.GetValue();
}

// Invalid in Visual mode.
mixin FCk_Handle_Interactable Get_Pickup(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Pickup;
}

// Invalid in Visual mode, and when the item has no mesh.
mixin FCk_Handle_JoltBody Get_Body(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Body;
}

// The collision profile the body was built with (and goes back to on a Release).
mixin FName Get_BodyProfile(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).BodyProfile;
}

// The profile the body last confirmed through a completed request; unset before the first mount.
mixin TOptional<FName> Get_AppliedBodyProfile(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).AppliedBodyProfile;
}

// What the body spans, from the root. Zero in Visual mode.
mixin FMars_WorldItem_BoundsFit Get_BoundsFit(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).BoundsFit;
}

// From the definition's Presentation trait; Transient when there is none.
mixin EMars_WorldItem_Persistence Get_Persistence(const FCk_Handle_WorldItem& Self)
{
    const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(Self);
    if (ck::Is_NOT_Valid(Presentation))
    { return EMars_WorldItem_Persistence::Transient; }

    return Presentation.Mounting.Persistence;
}

// The committed mount. Always World for a Transient item.
mixin EMars_WorldItem_Mount Get_Mount(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Committed.Mount;
}

// The mount the item is committed to, or already moving toward (a PendingMount waiting for the body to read Kinematic).
mixin EMars_WorldItem_Mount Get_TargetMount(const FCk_Handle_WorldItem& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_WorldItem_PendingMount))
    { return Self.Get_Fragment(FMars_Fragment_WorldItem_PendingMount).Target.Mount; }

    return Self.Get_Mount();
}

// Valid while Carried / Held.
mixin FCk_Handle Get_Carrier(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Committed.Carrier;
}

// The carrier's attach point the committed mount rides; invalid while it rides none.
mixin FGameplayTag Get_MountPoint(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Committed.Point;
}

// Landed: the committed mount is where the item's inventory says it belongs, with nothing pending (no mount waiting on the
// body, no arrival in flight, no release waiting on its transfer). The one "landed" predicate; OnMountSettled reports the
// moment it becomes true.
mixin bool Get_IsSettled(const FCk_Handle_WorldItem& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_WorldItem_PendingMount) || Self.Has_Fragment(FMars_Fragment_WorldItem_Arrival)
        || Self.Has_Fragment(FMars_Fragment_WorldItem_PendingRelease))
    { return false; }

    const auto Resolution = utils_world_item::Resolve_Target(Self);
    if (Resolution.Placement != EMars_WorldItem_Placement::Resolved)
    { return false; }

    return utils_world_item::Get_IsSameMount(Resolution.Target, Self.Get_Fragment(FMars_Fragment_WorldItem).Committed);
}

//--------------------------------------------------------------------------------------------------------------------------
// Item-side markers
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Has_PersistentWorldItem(const FCk_Handle_Item& Self)
{
    return Self.Has_Fragment(FMars_Fragment_Item_PersistentWorldItem);
}

// Invalid when absent.
mixin FCk_Handle_WorldItem Get_PersistentWorldItem(const FCk_Handle_Item& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Item_PersistentWorldItem) == false)
    { return FCk_Handle_WorldItem(); }

    return Self.Get_Fragment(FMars_Fragment_Item_PersistentWorldItem).WorldItem;
}

//--------------------------------------------------------------------------------------------------------------------------
// Capacity-1 inventories (a world item's holder, a hotbar slot, a cargo slot)
//--------------------------------------------------------------------------------------------------------------------------

// Invalid while the inventory is empty (or invalid).
mixin FCk_Handle_Item Get_SoleItem(const FCk_Handle_Inventory_DataOnly& Self)
{
    auto Inventory = Self;
    if (ck::Is_NOT_Valid(Inventory) || Inventory.Get_NumItems() == 0)
    { return FCk_Handle_Item(); }

    auto Items = Inventory.Get_Items();
    return Items[0];
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests (Persistent items only; UMars_Processor_WorldItem_HandleRequests validates them)
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_ArriveNextMount(FCk_Handle_WorldItem& Self, const FMars_Request_WorldItem_ArriveNextMount& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Requests);
    Requests.ArriveNextMountRequests.Add(InRequest);
}

mixin void Request_Release(FCk_Handle_WorldItem& Self, const FMars_Request_WorldItem_Release& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Requests);
    Requests.ReleaseRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnMountChanged(FCk_Handle_WorldItem& Self, FMars_Delegate_WorldItem_OnMountChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Signals);
    Fragment.OnMountChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnMountChanged(FCk_Handle_WorldItem& Self, FMars_Delegate_WorldItem_OnMountChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_WorldItem_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnMountSettled(FCk_Handle_WorldItem& Self, FMars_Delegate_WorldItem_OnMountSettled InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Signals);
    Fragment.OnMountSettled.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnMountSettled(FCk_Handle_WorldItem& Self, FMars_Delegate_WorldItem_OnMountSettled InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_WorldItem_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnMountSettled.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReleaseRefused(FCk_Handle_WorldItem& Self, FMars_Delegate_WorldItem_OnReleaseRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Signals);
    Fragment.OnReleaseRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReleaseRefused(FCk_Handle_WorldItem& Self, FMars_Delegate_WorldItem_OnReleaseRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_WorldItem_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnReleaseRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
