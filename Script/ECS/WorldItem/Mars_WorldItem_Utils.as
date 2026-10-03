namespace utils_world_item
{
    // The entity script composes the holder, body, pickup and visual first and hands their handles in here.
    FCk_Handle_WorldItem Add(FCk_Handle& InHandle, FMars_Fragment_WorldItem_Params InParams, FMars_Fragment_WorldItem InState)
    {
        InHandle.Add_Fragment(FMars_Feature_WorldItem());
        InHandle.Add_Fragment(InParams);
        InHandle.Add_Fragment(InState);
        return InHandle.As_WorldItem();
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

    // The item's Presentation.WorldItemScriptClass, else the base WorldItem entity script.
    TSubclassOf<UMars_WorldItem_EntityScript> Get_WorldItemScriptClass(const FCk_Handle_Item& InItem)
    {
        TSubclassOf<UMars_WorldItem_EntityScript> ScriptClass = UMars_WorldItem_EntityScript;
        if (InItem.Has_Presentation() == false)
        { return ScriptClass; }

        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();
        if (ck::IsValid(Presentation.WorldItemScriptClass))
        { ScriptClass = Presentation.WorldItemScriptClass; }

        return ScriptClass;
    }

    // The shape every probe on the item's body uses (the pickup, a backpack's weight probe): a box over the Mesh bounds
    // (x MeshScale, matching the body), centred on them since a mesh's pivot need not be its centre; a sphere of
    // PickupProbeRadius at the root when there is no Mesh.
    FMars_WorldItem_ProbeFit Make_ProbeFit(const UMars_ItemTrait_Presentation InPresentation)
    {
        UStaticMesh Mesh = nullptr;
        if (InPresentation.Mesh.IsNull() == false)
        { Mesh = System::LoadAsset_Blocking(InPresentation.Mesh); }

        if (ck::Is_NOT_Valid(Mesh))
        {
            return FMars_WorldItem_ProbeFit(
                utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InPresentation.PickupProbeRadius)), FTransform::Identity);
        }

        const auto Bounds = Mesh.GetBounds();
        const auto Scale = InPresentation.MeshScale;
        const auto HalfExtents = FVector(Math::Abs(Bounds.BoxExtent.X * Scale.X), Math::Abs(Bounds.BoxExtent.Y * Scale.Y),
                                         Math::Abs(Bounds.BoxExtent.Z * Scale.Z));
        return FMars_WorldItem_ProbeFit(utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(HalfExtents)),
            FTransform(FRotator::ZeroRotator, Bounds.Origin * Scale));
    }

    // Per-channel blend, slerp on rotation so a >180 degree turn takes the short way (BB bb_scene_node_focus::Blend).
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
    auto Holder = Self.Get_Holder();
    if (ck::Is_NOT_Valid(Holder) || Holder.Get_NumItems() == 0)
    { return FCk_Handle_Item(); }

    auto Items = Holder.Get_Items();
    return Items[0];
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

// The unit-scale-parent node that carries the mesh (and the display scale). Invalid when the item has no Presentation.
mixin FCk_Handle_Transform Get_VisualRoot(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).VisualRoot;
}

// From the definition's Presentation trait; Transient when there is none.
mixin EMars_WorldItem_Persistence Get_Persistence(const FCk_Handle_WorldItem& Self)
{
    const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(Self);
    if (ck::Is_NOT_Valid(Presentation))
    { return EMars_WorldItem_Persistence::Transient; }

    return Presentation.Persistence;
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

// Sanctioned one-shot marker (design 7.3): whoever starts moving an item stamps where it visually was; the next visual
// spawned for it consumes the stamp. Overwrites an older stamp.
mixin void Request_SetArriveFrom(FCk_Handle_Item& Self, FTransform InWorld)
{
    auto& ArriveFrom = Self.AddOrGet_Fragment(FMars_Fragment_Item_ArriveFrom);
    ArriveFrom.World = InWorld;
    ArriveFrom.StampedAtSeconds = System::GetGameTimeInSeconds();
}

// Removes the stamp. Unset when there is none, or it is older than constants_world_item::k_ArriveFromMaxAgeSeconds.
mixin FMars_WorldItem_Arrival TryConsume_ArriveFrom(FCk_Handle_Item& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_Fragment(FMars_Fragment_Item_ArriveFrom) == false)
    { return FMars_WorldItem_Arrival(); }

    // Snapshot before the remove: Request_TryRemove is immediate (entt swap-and-pop).
    const auto World = Self.Get_Fragment(FMars_Fragment_Item_ArriveFrom).World;
    const auto StampedAtSeconds = Self.Get_Fragment(FMars_Fragment_Item_ArriveFrom).StampedAtSeconds;

    Self.Request_TryRemove(FMars_Fragment_Item_ArriveFrom);

    const auto AgeSeconds = System::GetGameTimeInSeconds() - StampedAtSeconds;
    if (AgeSeconds > constants_world_item::k_ArriveFromMaxAgeSeconds)
    { return FMars_WorldItem_Arrival(); }

    return FMars_WorldItem_Arrival(World);
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
