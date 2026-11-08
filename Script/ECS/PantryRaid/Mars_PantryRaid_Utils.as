// A rat's view of the best target the raid sees for it (utils_pantry_raid::TryGet_Target).
struct FMars_PantryRaid_TargetView
{
    FCk_Handle_WorldItem Pack;
    int32 Slot = 0;
    FCk_Handle_Item Item;
    // The slot's mount point and the pack's root, world.
    FVector SlotLocation = FVector::ZeroVector;
    FVector PackLocation = FVector::ZeroVector;
    bool Guarded = false;
    // Leased to another rat.
    bool LeasedElsewhere = false;
}

// What a rat asks the raid for a target with (utils_pantry_raid::TryGet_Target).
struct FMars_PantryRaid_TargetQuery
{
    FCk_Handle Rat;
    FVector RatLocation = FVector::ZeroVector;
    // Picks among the pack's eligible slots (the rat's operation id: deterministic per rat).
    int32 Seed = 1;
}

namespace utils_pantry_raid
{
    // The entity tag a den's signal handler finds its raid by.
    const FName RaidTag = n"TAG_MarsPantryRaid";

    // Composes the raid on InOwner (which must carry a transform: the bounds are local to its translation). Nothing is
    // discovered and no rat emerges until the Tick processor proves readiness. A rejected spec ensures and returns an
    // invalid handle with nothing composed.
    FCk_Handle_PantryRaid Add(FCk_Handle& InOwner, FMars_PantryRaid_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[PantryRaid] [{InOwner.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_PantryRaid(); }

        if (ck::EnsureIfNot(ck::IsValid(InOwner.As_Transform(ECk_SanityCheck::UnChecked)),
            f"[PantryRaid] [{InOwner.ToString()}] has no transform: the encounter bounds are local to it"))
        { return FCk_Handle_PantryRaid(); }

        auto Params = FMars_Fragment_PantryRaid_Params();
        Params.Spec = InSpec;
        Params.NavVolume = InSpec.Parts.NavVolume;

        InOwner.Add_Fragment(FMars_Feature_PantryRaid());
        InOwner.Add_Fragment(Params);
        InOwner.Add_Fragment(FMars_Fragment_PantryRaid());
        utils_entity_tag::Add(InOwner, RaidTag);
        return InOwner.As_PantryRaid();
    }

    // What a rat may steal: any Food, a marked forage ingredient or a cheese; never a backpack, a hands-only item or a weapon.
    bool Get_IsStealable(const FCk_Handle_Item& InItem)
    {
        if (ck::Is_NOT_Valid(InItem) || InItem.Has_Backpack() || InItem.Has_HandsOnly() || InItem.Has_Strike())
        { return false; }

        return InItem.Has_Food() || InItem.Has_PantryIngredient() || InItem.Has_StinkyCheese();
    }

    // Planar distance; InA and InB further apart than InSameFloor vertically never count as near.
    // THE scent test, shared by the rat's target view (TryGet_Target, from the rat, no slack) and the raid's emergence (from a
    // den's OutsideStand, InSlackCm = utils_pantry_rat::k_ArrivalCm because the resident may stop that far short of the stand):
    // A smeller InPlanarDistance from the pack (Get_PlanarDistance) smells it when it is at least InSlackCm inside ScentRangeCm.
    bool Get_IsWithinScent(const FMars_PantryRaid_Scent& InScent, float64 InPlanarDistance, float64 InSlackCm)
    {
        return InPlanarDistance + InSlackCm <= float64(InScent.ScentRangeCm);
    }

    float64 Get_PlanarDistance(FVector InA, FVector InB)
    {
        return (InA - InB).Size2D();
    }

    bool Get_IsSameFloor(FVector InA, FVector InB, float32 InSameFloorCm)
    {
        return Math::Abs(InA.Z - InB.Z) < float64(InSameFloorCm);
    }

    // The nearest of InChefs to InPoint on its floor (planar); invalid Root when none is on the floor.
    FMars_PantryRaid_ChefSnapshot Get_NearestChef(const TArray<FMars_PantryRaid_ChefSnapshot>& InChefs, FVector InPoint, float32 InSameFloorCm)
    {
        auto Best = FMars_PantryRaid_ChefSnapshot();
        auto BestDistance = 0.0;
        for (const auto& Chef : InChefs)
        {
            if (Get_IsSameFloor(Chef.Location, InPoint, InSameFloorCm) == false)
            { continue; }

            const auto Distance = Get_PlanarDistance(Chef.Location, InPoint);
            if (ck::Is_NOT_Valid(Best.Root) || Distance < BestDistance)
            {
                Best = Chef;
                BestDistance = Distance;
            }
        }

        return Best;
    }

    // A chef root a raid observes: tagged TAG_MarsCombatTarget and carrying a Hotbar (a player or a test stand-in), not a
    // monster sharing the combat tag.
    bool Get_IsChef(const FCk_Handle& InCandidate)
    {
        if (ck::Is_NOT_Valid(InCandidate) || utils_world_item::Get_IsEnding(InCandidate))
        { return false; }

        return ck::IsValid(InCandidate.As_Hotbar(ECk_SanityCheck::UnChecked)) && ck::IsValid(InCandidate.As_Transform(ECk_SanityCheck::UnChecked));
    }

    // Every chef root's CURRENT location (not a snapshot): what the claim's drain-time acceptance reads.
    TArray<FMars_PantryRaid_ChefSnapshot> Read_ChefsNow(const FCk_Handle& InWorldContext)
    {
        auto Chefs = TArray<FMars_PantryRaid_ChefSnapshot>();
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InWorldContext, n"TAG_MarsCombatTarget"))
        {
            if (Get_IsChef(Candidate) == false)
            { continue; }

            auto Snapshot = FMars_PantryRaid_ChefSnapshot();
            Snapshot.Root = Candidate;
            Snapshot.Location = utils_transform::Get_EntityCurrentLocation(Candidate.As_Transform());
            Chefs.Add(Snapshot);
        }

        return Chefs;
    }

    // Any of InChefs within InRadius of InPoint (planar) on its floor.
    bool Get_IsAnyChefWithin(const TArray<FMars_PantryRaid_ChefSnapshot>& InChefs, FVector InPoint, float32 InRadius, float32 InSameFloorCm)
    {
        for (const auto& Chef : InChefs)
        {
            if (Get_IsSameFloor(Chef.Location, InPoint, InSameFloorCm) && Get_PlanarDistance(Chef.Location, InPoint) < float64(InRadius))
            { return true; }
        }

        return false;
    }

    // The candidate flee / avoid points: a ring of InRouting.FleeRingCount points inset in InBounds (world), at height InZ,
    // index 0 on +X, counter-clockwise.
    TArray<FVector> Make_FleeRing(FBox InBounds, const FMars_PantryRaid_Routing& InRouting, float64 InZ)
    {
        auto Points = TArray<FVector>();
        const auto Centre = (InBounds.Min + InBounds.Max) * 0.5;
        const auto Half = (InBounds.Max - InBounds.Min) * 0.5 * (1.0 - float64(InRouting.FleeRingInset));
        for (int32 Index = 0; Index < InRouting.FleeRingCount; ++Index)
        {
            const auto Angle = 2.0 * PI * float64(Index) / float64(InRouting.FleeRingCount);
            Points.Add(FVector(Centre.X + Math::Cos(Angle) * Half.X, Centre.Y + Math::Sin(Angle) * Half.Y, InZ));
        }

        return Points;
    }

    // A deterministic unit value in [0, 1) for (InSeed, InSalt): the rhythm's and the slot choice's variation.
    float32 Get_Unit(int32 InSeed, int32 InSalt)
    {
        auto Hash = InSeed * 73856093 + InSalt * 19349663 + 83492791;
        Hash = (Hash ^ (Hash >> 13)) * 1274126177;
        Hash = Hash ^ (Hash >> 16);
        const auto Positive = Hash & 0x7fffffff;
        return float32(Positive % 10000) / 10000.0f;
    }

    int32 Get_RangeInt(int32 InSeed, int32 InSalt, int32 InMin, int32 InMax)
    {
        const auto Span = InMax - InMin + 1;
        return InMin + Math::Min(int32(Get_Unit(InSeed, InSalt) * float32(Span)), Span - 1);
    }

    float32 Get_RangeFloat(int32 InSeed, int32 InSalt, float32 InMin, float32 InMax)
    {
        return InMin + (InMax - InMin) * Get_Unit(InSeed, InSalt);
    }

    // A cargo slot's mount point height above its pack's root (the pack's pivot is at its base).
    float64 Get_SlotHeight(const FCk_Handle_CargoSlot& InSlot, const FCk_Handle_WorldItem& InPack)
    {
        FCk_Handle SlotEntity = InSlot;
        const auto SlotZ = utils_transform::Get_EntityCurrentLocation(SlotEntity.As_Transform()).Z;
        return SlotZ - utils_transform::Get_EntityCurrentLocation(InPack.As_Transform()).Z;
    }

    // The planar point a rat works InSlot from: InStandoff out from the slot's mount point, away from the pack's root.
    FVector Get_WorkPoint(FVector InSlotLocation, FVector InPackLocation, float32 InStandoff, float64 InZ)
    {
        auto Outward = InSlotLocation - InPackLocation;
        Outward.Z = 0.0;
        Outward = Outward.GetSafeNormal();
        if (Outward.IsNearlyZero())
        { Outward = FVector::ForwardVector; }

        auto Point = InSlotLocation + Outward * float64(InStandoff);
        Point.Z = InZ;
        return Point;
    }

    // The point InDistance (planar) along InStart -> InWaypoints; the last waypoint when the route is shorter, InStart when empty.
    FVector Get_PointAlongPath(FVector InStart, const TArray<FVector>& InWaypoints, float64 InDistance)
    {
        auto Previous = InStart;
        auto Left = InDistance;
        for (const auto& Waypoint : InWaypoints)
        {
            auto Leg = Waypoint - Previous;
            Leg.Z = 0.0;
            const auto Length = Leg.Size();
            if (Length >= Left && Length > 0.0)
            {
                auto Point = Previous + Leg * (Left / Length);
                Point.Z = Waypoint.Z;
                return Point;
            }

            Left -= Length;
            Previous = Waypoint;
        }

        return Previous;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_PantryRaid_Spec Get_Spec(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid_Params).Spec;
}

mixin FCk_Handle_GroundNavVolume Get_NavVolume(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid_Params).NavVolume;
}

// The encounter bounds in the world (Spec.EncounterBounds moved by the raid's translation).
mixin FBox Get_BoundsWorld(const FCk_Handle_PantryRaid& Self)
{
    const auto Local = Self.Get_Spec().EncounterBounds;
    const auto Origin = utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
    return FBox(Local.Min + Origin, Local.Max + Origin);
}

mixin bool Get_IsInsideBounds(const FCk_Handle_PantryRaid& Self, FVector InPoint)
{
    const auto Bounds = Self.Get_BoundsWorld();
    return InPoint.X >= Bounds.Min.X && InPoint.X <= Bounds.Max.X && InPoint.Y >= Bounds.Min.Y && InPoint.Y <= Bounds.Max.Y
        && InPoint.Z >= Bounds.Min.Z && InPoint.Z <= Bounds.Max.Z;
}

mixin bool Get_IsReady(const FCk_Handle_PantryRaid& Self)
{
    return Self.Has_Fragment(FMars_Tag_PantryRaid_Ready);
}

mixin float32 Get_Clock(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).Clock;
}

mixin TArray<FCk_Handle_RatDen> Get_Dens(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).Dens;
}

mixin TArray<FMars_PantryRaid_RatRecord> Get_Rats(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).Rats;
}

// Every rat the raid owns, live or dead (the cap counts both).
mixin int32 Get_RatCount(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).Rats.Num();
}

mixin bool Get_HasRat(const FCk_Handle_PantryRaid& Self, const FCk_Handle& InRat)
{
    for (const auto& Record : Self.Get_Fragment(FMars_Fragment_PantryRaid).Rats)
    {
        if (Record.Rat == InRat)
        { return true; }
    }

    return false;
}

// Unset when InRat is not one of the raid's.
mixin TOptional<FMars_PantryRaid_RatRecord> TryGet_RatRecord(const FCk_Handle_PantryRaid& Self, const FCk_Handle& InRat)
{
    for (const auto& Record : Self.Get_Fragment(FMars_Fragment_PantryRaid).Rats)
    {
        if (Record.Rat == InRat)
        { return TOptional<FMars_PantryRaid_RatRecord>(Record); }
    }

    return TOptional<FMars_PantryRaid_RatRecord>();
}

mixin TArray<FMars_PantryRaid_PackRecord> Get_Packs(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).Packs;
}

// Unset when InPack is not a pack the raid tracks.
mixin TOptional<FMars_PantryRaid_PackRecord> TryGet_PackRecord(const FCk_Handle_PantryRaid& Self, const FCk_Handle_WorldItem& InPack)
{
    for (const auto& Record : Self.Get_Fragment(FMars_Fragment_PantryRaid).Packs)
    {
        if (Record.Pack == InPack)
        { return TOptional<FMars_PantryRaid_PackRecord>(Record); }
    }

    return TOptional<FMars_PantryRaid_PackRecord>();
}

mixin TArray<FMars_PantryRaid_ChefSnapshot> Get_Chefs(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).Chefs;
}

mixin int32 Get_LeasesGranted(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).LeasesGranted;
}

mixin int32 Get_StaleSpawns(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).StaleSpawns;
}

mixin int32 Get_RefusedRetirements(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).RefusedRetirements;
}

mixin int32 Get_EmergencesRequested(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).EmergencesRequested;
}

mixin int32 Get_UnreachableTargetLogs(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).UnreachableTargetLogs;
}

mixin int32 Get_OutOfScentTargetLogs(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).OutOfScentTargetLogs;
}

mixin int32 Get_Epoch(const FCk_Handle_PantryRaid& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRaid).Epoch;
}

// The lease InRat holds, on any pack (a rat holds at most one).
mixin TOptional<FMars_PantryRaid_Lease> TryGet_LeaseOf(const FCk_Handle_PantryRaid& Self, const FCk_Handle& InRat)
{
    for (const auto& Record : Self.Get_Fragment(FMars_Fragment_PantryRaid).Packs)
    {
        if (Record.Lease.IsSet() && Record.Lease.GetValue().Rat == InRat)
        { return Record.Lease; }
    }

    return TOptional<FMars_PantryRaid_Lease>();
}

// How many packs carry a lease right now.
mixin int32 Get_LeaseCount(const FCk_Handle_PantryRaid& Self)
{
    auto Count = 0;
    for (const auto& Record : Self.Get_Fragment(FMars_Fragment_PantryRaid).Packs)
    {
        if (Record.Lease.IsSet())
        { ++Count; }
    }

    return Count;
}

// The best target for an empty rat: the nearest armed pack with an eligible slot within ScentRangeCm of InQuery.RatLocation
// (deterministic: nearest, then the pack list order); the slot is eligible slot (Seed - 1) mod count, or the one the rat
// already holds a lease on. Unset
// when none.
mixin TOptional<FMars_PantryRaid_TargetView> TryGet_Target(const FCk_Handle_PantryRaid& Self, const FMars_PantryRaid_TargetQuery& InQuery)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_PantryRaid);
    const auto Spec = Self.Get_Spec();

    auto Best = TOptional<FMars_PantryRaid_TargetView>();
    auto BestDistance = 0.0;
    for (const auto& Record : State.Packs)
    {
        if (Record.ScentArmed == false || Record.EligibleSlots.Num() == 0 || ck::Is_NOT_Valid(Record.Pack))
        { continue; }

        const auto PackLocation = utils_transform::Get_EntityCurrentLocation(Record.Pack.As_Transform());
        const auto Distance = utils_pantry_raid::Get_PlanarDistance(PackLocation, InQuery.RatLocation);
        if (utils_pantry_raid::Get_IsWithinScent(Spec.Scent, Distance, 0.0) == false)
        { continue; }

        if (Best.IsSet() && Distance >= BestDistance)
        { continue; }

        auto View = FMars_PantryRaid_TargetView();
        View.Pack = Record.Pack;
        View.PackLocation = PackLocation;
        View.Guarded = Record.Guarded;
        View.LeasedElsewhere = Record.Lease.IsSet() && Record.Lease.GetValue().Rat != InQuery.Rat;

        // Deterministic per rat: the operation id walks the eligible slots in order (the first rat takes the first).
        auto Pick = Math::Max(InQuery.Seed - 1, 0) % Record.EligibleSlots.Num();
        if (Record.Lease.IsSet() && Record.Lease.GetValue().Rat == InQuery.Rat)
        { Pick = Math::Max(Record.EligibleSlots.FindIndex(Record.Lease.GetValue().Slot), 0); }

        View.Slot = Record.EligibleSlots[Pick];
        const auto Slot = Record.Pack.As_Backpack().Get_CargoSlot(View.Slot);
        View.Item = Slot.Get_Item();
        FCk_Handle SlotEntity = Slot;
        View.SlotLocation = utils_transform::Get_EntityCurrentLocation(SlotEntity.As_Transform());

        Best = TOptional<FMars_PantryRaid_TargetView>(View);
        BestDistance = Distance;
    }

    return Best;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_GrantLease(FCk_Handle_PantryRaid& Self, const FMars_Request_PantryRaid_GrantLease& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRaid_Requests);
    Requests.GrantLeaseRequests.Add(InRequest);
}

mixin void Request_ReleaseLease(FCk_Handle_PantryRaid& Self, const FMars_Request_PantryRaid_ReleaseLease& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRaid_Requests);
    Requests.ReleaseLeaseRequests.Add(InRequest);
}

mixin void Request_SpawnRat(FCk_Handle_PantryRaid& Self, const FMars_Request_PantryRaid_SpawnRat& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRaid_Requests);
    Requests.SpawnRatRequests.Add(InRequest);
}

mixin void Request_RatHome(FCk_Handle_PantryRaid& Self, const FMars_Request_PantryRaid_RatHome& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRaid_Requests);
    Requests.RatHomeRequests.Add(InRequest);
}

mixin void Request_RatDied(FCk_Handle_PantryRaid& Self, const FMars_Request_PantryRaid_RatDied& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRaid_Requests);
    Requests.RatDiedRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnReady(FCk_Handle_PantryRaid& Self, FMars_Delegate_PantryRaid_OnReady InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_PantryRaid_Signals);
    Fragment.OnReady.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReady(FCk_Handle_PantryRaid& Self, FMars_Delegate_PantryRaid_OnReady InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PantryRaid_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_PantryRaid_Signals).OnReady.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnRatSpawned(FCk_Handle_PantryRaid& Self, FMars_Delegate_PantryRaid_OnRatSpawned InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_PantryRaid_Signals);
    Fragment.OnRatSpawned.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRatSpawned(FCk_Handle_PantryRaid& Self, FMars_Delegate_PantryRaid_OnRatSpawned InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PantryRaid_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_PantryRaid_Signals).OnRatSpawned.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
