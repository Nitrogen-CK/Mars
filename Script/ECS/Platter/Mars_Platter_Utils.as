// A platter world item lying at World, with Food's whole joint on it when set.
struct FMars_Platter_SpawnSpec
{
    UPROPERTY()
    FTransform World;

    // Null = an empty platter.
    UPROPERTY()
    TWeakObjectPtr<UMars_Food_Def> Food;

    FMars_Platter_SpawnSpec() {}

    FMars_Platter_SpawnSpec(const FTransform& InWorld)
    {
        World = InWorld;
    }

    FMars_Platter_SpawnSpec(const FTransform& InWorld, UMars_Food_Def InFood)
    {
        World = InWorld;
        Food = TWeakObjectPtr<UMars_Food_Def>(InFood);
    }
}

namespace utils_platter
{
    // Composes the platter on InHandle, which must carry a Transform: the root the pieces ride. Every slot starts empty. A
    // rejected spec or a missing Transform ensures and returns an invalid handle.
    FCk_Handle_Platter Add(FCk_Handle& InHandle, FMars_Platter_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Platter] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Platter(); }

        const auto IsComposable = InHandle.Is_Transform() && InHandle.Is_Platter() == false;
        if (ck::EnsureIfNot(IsComposable, f"[Platter] [{InHandle.ToString()}] needs a Transform, and no Platter yet"))
        { return FCk_Handle_Platter(); }

        auto Params = FMars_Fragment_Platter_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Platter();
        for (int32 Index = 0; Index < InSpec.SlotsLocal.Num(); ++Index)
        { State.Slots.Add(FCk_Handle_FoodPiece()); }

        InHandle.Add_Fragment(FMars_Feature_Platter());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_Platter();
    }

    // The local pose a piece takes in a slot: its bounds centre over the slot's origin and its bounds bottom on the slot's
    // plane, in the slot's rotation. Metrics are the piece's Ready geometry's.
    FTransform Get_SlotPose(const FCk_RuntimeMesh_Metrics& InMetrics, const FTransform& InSlotLocal)
    {
        const auto Min = InMetrics.Get_BoundsMinCm();
        const auto Max = InMetrics.Get_BoundsMaxCm();
        const auto Centre = (Min + Max) * 0.5;
        return FTransform(FRotator::ZeroRotator, FVector(-Centre.X, -Centre.Y, -Min.Z)) * InSlotLocal;
    }

    // A platter world item (Mars_ItemDef_Platter, World mode) owned by InOwner (ck::TransientEntity() for one that must
    // outlive its spawner). Returns the entity under construction: it is a WorldItem and a Platter once constructed.
    FCk_Handle Request_SpawnWorld(FCk_Handle& InOwner, const FMars_Platter_SpawnSpec& InSpec)
    {
        auto SpawnParams = UMars_Platter_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(InSpec.World.Rotator(), InSpec.World.GetLocation());
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Platter());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.InitialFood = InSpec.Food;

        auto Pending = utils_entity_script::Request_SpawnEntity(InOwner, UMars_Platter_EntityScript, SpawnParams);
        return Pending.Get_EntityUnderConstruction();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Platter_Spec Get_Spec(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter_Params).Spec;
}

mixin int32 Get_Capacity(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter_Params).Spec.SlotsLocal.Num();
}

// One entry per slot; invalid = empty. A piece destroyed elsewhere leaves its slot empty: the ledger is not told.
mixin TArray<FCk_Handle_FoodPiece> Get_Slots(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter).Slots;
}

// The landed pieces, in slot order.
mixin TArray<FCk_Handle_FoodPiece> Get_Held(const FCk_Handle_Platter& Self)
{
    TArray<FCk_Handle_FoodPiece> Held;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Platter).Slots)
    {
        if (ck::IsValid(Piece))
        { Held.Add(Piece); }
    }

    return Held;
}

mixin int32 Get_HeldCount(const FCk_Handle_Platter& Self)
{
    auto Count = 0;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Platter).Slots)
    {
        if (ck::IsValid(Piece))
        { ++Count; }
    }

    return Count;
}

// Accepted loads still waiting for their piece.
mixin int32 Get_PendingCount(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter).Pending.Num();
}

// What a Load counts against the capacity: the landed pieces plus the pending ones.
mixin int32 Get_Occupancy(const FCk_Handle_Platter& Self)
{
    return Self.Get_HeldCount() + Self.Get_PendingCount();
}

mixin bool Get_IsFull(const FCk_Handle_Platter& Self)
{
    return Self.Get_Occupancy() >= Self.Get_Capacity();
}

mixin int32 Get_FreeSlotCount(const FCk_Handle_Platter& Self)
{
    return Math::Max(0, Self.Get_Capacity() - Self.Get_Occupancy());
}

// The lowest slot neither landed nor reserved by a pending load; unset when the platter is full.
mixin TOptional<int32> TryGet_FirstFreeSlot(const FCk_Handle_Platter& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Platter);
    for (int32 Index = 0; Index < State.Slots.Num(); ++Index)
    {
        if (ck::IsValid(State.Slots[Index]))
        { continue; }

        auto IsReserved = false;
        for (const auto& Pending : State.Pending)
        { IsReserved = IsReserved || Pending.Slot == Index; }

        if (IsReserved == false)
        { return TOptional<int32>(Index); }
    }

    return TOptional<int32>();
}

// Whether every landed piece is a root (never cut); true for an empty platter.
mixin bool Get_IsWhole(const FCk_Handle_Platter& Self)
{
    for (const auto& Piece : Self.Get_Held())
    {
        if (Piece.Get_IsWhole() == false)
        { return false; }
    }

    return true;
}

// The union of the landed pieces' kinds.
mixin FGameplayTagContainer Get_Kinds(const FCk_Handle_Platter& Self)
{
    auto Kinds = FGameplayTagContainer();
    for (const auto& Piece : Self.Get_Held())
    { Kinds.AppendTags(Piece.Get_Kind()); }

    return Kinds;
}

// The platter holding the piece, landed or pending; invalid for a piece no platter holds.
mixin FCk_Handle_Platter TryGet_Platter(const FCk_Handle_FoodPiece& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_Fragment(FMars_Fragment_Platter_Membership) == false)
    { return FCk_Handle_Platter(); }

    return Self.Get_Fragment(FMars_Fragment_Platter_Membership).Platter;
}

// The slot the piece holds or has reserved; unset for a piece no platter holds.
mixin TOptional<int32> Get_PlatterSlot(const FCk_Handle_FoodPiece& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_Fragment(FMars_Fragment_Platter_Membership) == false)
    { return TOptional<int32>(); }

    return TOptional<int32>(Self.Get_Fragment(FMars_Fragment_Platter_Membership).Slot);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Load(FCk_Handle_Platter& Self, const FMars_Request_Platter_Load& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.Piece), f"[Platter] [{Self.ToString()}] was asked to load an invalid piece"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Requests);
    Requests.LoadRequests.Add(InRequest);
}

mixin void Request_Unload(FCk_Handle_Platter& Self, const FMars_Request_Platter_Unload& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.Piece), f"[Platter] [{Self.ToString()}] was asked to unload an invalid piece"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Requests);
    Requests.UnloadRequests.Add(InRequest);
}

mixin void Request_Clear(FCk_Handle_Platter& Self, const FMars_Request_Platter_Clear& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Requests);
    Requests.ClearRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnLoaded(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoaded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Signals);
    Fragment.OnLoaded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLoaded(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoaded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Platter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoaded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnLoadRefused(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoadRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Signals);
    Fragment.OnLoadRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLoadRefused(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoadRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Platter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoadRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnUnloaded(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnUnloaded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Signals);
    Fragment.OnUnloaded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnUnloaded(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnUnloaded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Platter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Platter_Signals).OnUnloaded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCleared(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnCleared InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Signals);
    Fragment.OnCleared.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCleared(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnCleared InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Platter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Platter_Signals).OnCleared.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
