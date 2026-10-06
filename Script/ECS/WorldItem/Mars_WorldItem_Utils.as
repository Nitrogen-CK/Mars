namespace utils_world_item
{
    // The entity script composes the holder, body, pickup and visual first and hands their handles in through the Spec.
    FCk_Handle_WorldItem Add(FCk_Handle& InHandle, FMars_WorldItem_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[WorldItem] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_WorldItem(); }

        auto Params = FMars_Fragment_WorldItem_Params();
        Params.Mode = InSpec.Mode;
        Params.Definition = InSpec.Definition;

        auto State = FMars_Fragment_WorldItem();
        State.Holder = InSpec.Holder;
        State.Pickup = InSpec.Pickup;
        State.Body = InSpec.Body;

        InHandle.Add_Fragment(FMars_Feature_WorldItem());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);

        // Never applied here: the body is not added for at least one frame. The launch processor drains it.
        if (InSpec.Launch.IsSet())
        { InHandle.Add_Fragment(InSpec.Launch.GetValue()); }

        if (InSpec.Arrival.IsSet())
        { InHandle.Add_Fragment(InSpec.Arrival.GetValue()); }

        return InHandle.As_WorldItem();
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

// Invalid in Visual mode, and when the item has no mesh.
mixin FCk_Handle_JoltBody Get_Body(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Body;
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
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Mount;
}

// The mount the item is committed to, or already moving toward (a PendingMount waiting for the body to read
// Kinematic). Requests are validated against this, so a Carry and a Hold queued back to back are both legal.
mixin EMars_WorldItem_Mount Get_TargetMount(const FCk_Handle_WorldItem& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_WorldItem_PendingMount))
    { return Self.Get_Fragment(FMars_Fragment_WorldItem_PendingMount).Mount; }

    return Self.Get_Mount();
}

// Valid while Carried / Held.
mixin FCk_Handle Get_Carrier(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Carrier;
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
// Requests (Persistent items only; UMars_Processor_WorldItem_HandleRequests validates the transition)
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Carry(FCk_Handle_WorldItem& Self, const FMars_Request_WorldItem_Carry& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Requests);
    Requests.CarryRequests.Add(InRequest);
}

mixin void Request_Hold(FCk_Handle_WorldItem& Self, const FMars_Request_WorldItem_Hold& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_WorldItem_Requests);
    Requests.HoldRequests.Add(InRequest);
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
