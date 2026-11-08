//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

// The encounter driver, composed on the raid entity (one per encounter / nav island, no singleton): it discovers the dens
// and grounded cheese packs inside its bounds, observes every chef, owns one theft lease per pack, decides emergences and
// owns every rat it spawns (a den never owns a rat). Readiness (a built current ground nav field, a real provider route from
// a den's OutsideStand into the bounds, at least one den) is stamped FMars_Tag_PantryRaid_Ready last.
asset Mars_PantryRaidHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_PantryRaid";
    RequiredFragments.Add(FMars_Feature_PantryRaid);
    Description = "A pantry raid encounter: the dens, rats and grounded cheese packs inside its bounds, chef guard snapshots, one theft lease per pack, readiness and emergence";
}
struct FMars_Feature_PantryRaid {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_PantryRaid_Population
{
    UPROPERTY()
    int32 ResidentsPerDen = 2;

    UPROPERTY()
    int32 MaxActiveRats = 6;

    UPROPERTY()
    float32 EmergeSpacingSeconds = 4.0f;

    UPROPERTY()
    float32 DeadReplacementSeconds = 30.0f;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Population& Self)
{
    if (Self.ResidentsPerDen < 1 || Self.ResidentsPerDen > utils_rat_den::k_MaxResidents || Self.MaxActiveRats < 1)
    { return FMars_Validation(f"PantryRaid Population ResidentsPerDen [{Self.ResidentsPerDen}] / MaxActiveRats [{Self.MaxActiveRats}] out of range"); }

    if (Math::IsFinite(Self.EmergeSpacingSeconds) == false || Self.EmergeSpacingSeconds < 0.0f
        || Math::IsFinite(Self.DeadReplacementSeconds) == false || Self.DeadReplacementSeconds < 0.0f)
    { return FMars_Validation("PantryRaid Population has a negative or non-finite time"); }

    return FMars_Validation();
}

struct FMars_PantryRaid_Scent
{
    // A grounded, settled pack holding a cheese arms its scent after this long.
    UPROPERTY()
    float32 GroundArmSeconds = 3.0f;

    // An empty rat notices an armed pack this close (planar).
    UPROPERTY()
    float32 ScentRangeCm = 1200.0f;

    // An empty rat with no target this long goes home.
    UPROPERTY()
    float32 NoTargetReturnSeconds = 2.0f;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Scent& Self)
{
    if (Math::IsFinite(Self.GroundArmSeconds) == false || Self.GroundArmSeconds < 0.0f
        || Math::IsFinite(Self.ScentRangeCm) == false || Self.ScentRangeCm <= 0.0f
        || Math::IsFinite(Self.NoTargetReturnSeconds) == false || Self.NoTargetReturnSeconds < 0.0f)
    { return FMars_Validation("PantryRaid Scent has a negative or non-finite value"); }

    return FMars_Validation();
}

// Planar distances, cm. A pack is Guarded while any chef within GuardEnterCm (and within SameFloorCm vertically) stands by
// it; it clears only once every chef is beyond GuardExitCm for ClearDwellSeconds. A rat's threat is the nearest chef within
// AvoidEnterCm, cleared beyond AvoidExitCm. A chef's posture (standing, crouched, seated) does not matter: position only.
struct FMars_PantryRaid_Guard
{
    UPROPERTY()
    float32 GuardEnterCm = 220.0f;

    UPROPERTY()
    float32 GuardExitCm = 320.0f;

    UPROPERTY()
    float32 AvoidEnterCm = 300.0f;

    UPROPERTY()
    float32 AvoidExitCm = 380.0f;

    UPROPERTY()
    float32 ClearDwellSeconds = 1.0f;

    UPROPERTY()
    float32 SameFloorCm = 150.0f;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Guard& Self)
{
    if (Self.GuardEnterCm <= 0.0f || Self.GuardExitCm < Self.GuardEnterCm || Self.AvoidEnterCm <= 0.0f || Self.AvoidExitCm < Self.AvoidEnterCm)
    {
        return FMars_Validation(f"PantryRaid Guard needs 0 < enter <= exit (guard [{Self.GuardEnterCm}]/[{Self.GuardExitCm}], "
            + f"avoid [{Self.AvoidEnterCm}]/[{Self.AvoidExitCm}])");
    }

    if (Self.ClearDwellSeconds < 0.0f || Self.SameFloorCm <= 0.0f)
    { return FMars_Validation(f"PantryRaid Guard ClearDwellSeconds [{Self.ClearDwellSeconds}] / SameFloorCm [{Self.SameFloorCm}] out of range"); }

    return FMars_Validation();
}

struct FMars_PantryRaid_Routing
{
    // A loaded rat's flee goal and every waypoint of its route keep this far from every den portal.
    UPROPERTY()
    float32 LoadedPortalKeepOutCm = 150.0f;

    // How often a rat re-decides an open question (a cornered rescore, a cautious hold).
    UPROPERTY()
    float32 DecisionIntervalSeconds = 0.2f;

    // The flee / avoid candidates: a ring of this many points inside the bounds.
    UPROPERTY()
    int32 FleeRingCount = 12;

    // The ring sits this fraction of the bounds' half size in from the edge.
    UPROPERTY()
    float32 FleeRingInset = 0.2f;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Routing& Self)
{
    if (Self.LoadedPortalKeepOutCm < 0.0f || Self.DecisionIntervalSeconds <= 0.0f || Self.FleeRingCount < 3
        || Self.FleeRingInset < 0.0f || Self.FleeRingInset >= 1.0f)
    { return FMars_Validation("PantryRaid Routing has an out-of-range value"); }

    return FMars_Validation();
}

struct FMars_PantryRaid_Theft
{
    UPROPERTY()
    float32 InspectSeconds = 0.4f;

    UPROPERTY()
    float32 RummageSeconds = 1.6f;

    // A lease not committed by then is dropped.
    UPROPERTY()
    float32 LeaseSeconds = 3.0f;

    // A rat reaches a cargo slot whose mount point is at most this high above the pack's root (Phase 1 reared reach).
    UPROPERTY()
    float32 MaxReachCm = 48.0f;

    // The rat stands this far out from the slot's mount point (planar, away from the pack's centre) to work it.
    UPROPERTY()
    float32 WorkStandoffCm = 45.0f;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Theft& Self)
{
    if (Self.InspectSeconds < 0.0f || Self.RummageSeconds < 0.0f || Self.LeaseSeconds <= Self.InspectSeconds + Self.RummageSeconds
        || Self.MaxReachCm <= 0.0f || Self.WorkStandoffCm <= 0.0f)
    {
        return FMars_Validation(f"PantryRaid Theft: LeaseSeconds [{Self.LeaseSeconds}] must outlast inspect [{Self.InspectSeconds}] + "
            + f"rummage [{Self.RummageSeconds}], and reach / standoff must be positive");
    }

    return FMars_Validation();
}

// cm/s, through the navigator's SetSpeed (SurfaceMotion clamps to its MaxSpeed).
struct FMars_PantryRaid_Speeds
{
    UPROPERTY()
    float32 Creep = 100.0f;

    UPROPERTY()
    float32 Approach = 240.0f;

    UPROPERTY()
    float32 LoadedFlee = 320.0f;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Speeds& Self)
{
    if (Self.Creep <= 0.0f || Self.Approach <= 0.0f || Self.LoadedFlee <= 0.0f)
    { return FMars_Validation("PantryRaid Speeds has a non-positive speed"); }

    return FMars_Validation();
}

// The visual low hop (presentation; the root never leaves the ground).
struct FMars_PantryRaid_Hop
{
    UPROPERTY()
    float32 MaxLiftCm = 8.0f;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Hop& Self)
{
    if (Self.MaxLiftCm < 0.0f || Self.MaxLiftCm > 8.0f)
    { return FMars_Validation(f"PantryRaid Hop MaxLiftCm [{Self.MaxLiftCm}] is outside 0..8"); }

    return FMars_Validation();
}

// The burst / observe rhythm. A bound is one BoundCycle (BoundSeconds) at the burst's speed; a burst is 1..3 (empty) or
// 2..3 (loaded) bounds along the provider route, then a pause.
struct FMars_PantryRaid_Rhythm
{
    UPROPERTY()
    float32 BoundSeconds = 0.4f;

    UPROPERTY()
    int32 EmptyBoundsMin = 1;

    UPROPERTY()
    int32 EmptyBoundsMax = 3;

    UPROPERTY()
    float32 ObserveMinSeconds = 0.6f;

    UPROPERTY()
    float32 ObserveMaxSeconds = 1.5f;

    UPROPERTY()
    int32 LoadedBoundsMin = 2;

    UPROPERTY()
    int32 LoadedBoundsMax = 3;

    UPROPERTY()
    float32 FleePauseMinSeconds = 0.35f;

    UPROPERTY()
    float32 FleePauseMaxSeconds = 0.65f;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Rhythm& Self)
{
    if (Self.BoundSeconds <= 0.0f || Self.EmptyBoundsMin < 1 || Self.EmptyBoundsMax < Self.EmptyBoundsMin
        || Self.LoadedBoundsMin < 1 || Self.LoadedBoundsMax < Self.LoadedBoundsMin)
    { return FMars_Validation("PantryRaid Rhythm has an empty or inverted bound range"); }

    if (Self.ObserveMinSeconds < 0.0f || Self.ObserveMaxSeconds < Self.ObserveMinSeconds
        || Self.FleePauseMinSeconds < 0.0f || Self.FleePauseMaxSeconds < Self.FleePauseMinSeconds)
    { return FMars_Validation("PantryRaid Rhythm has a negative or inverted pause range"); }

    return FMars_Validation();
}

// Built by the entity script before Add. Not UPROPERTYs: spawn params never carry handles.
struct FMars_PantryRaid_Parts
{
    // The ground nav field the raid's readiness waits on (built and current).
    FCk_Handle_GroundNavVolume NavVolume;
}

struct FMars_PantryRaid_Spec
{
    // Local to the raid entity's translation.
    UPROPERTY()
    FBox EncounterBounds = FBox(FVector(-600.0, -600.0, -100.0), FVector(600.0, 600.0, 200.0));

    UPROPERTY()
    FMars_PantryRaid_Population Population;

    UPROPERTY()
    FMars_PantryRaid_Scent Scent;

    UPROPERTY()
    FMars_PantryRaid_Guard Guard;

    UPROPERTY()
    FMars_PantryRaid_Routing Routing;

    UPROPERTY()
    FMars_PantryRaid_Theft Theft;

    UPROPERTY()
    FMars_PantryRaid_Speeds Speeds;

    UPROPERTY()
    FMars_PantryRaid_Hop Hop;

    UPROPERTY()
    FMars_PantryRaid_Rhythm Rhythm;

    FMars_PantryRaid_Parts Parts;
}

mixin FMars_Validation Validate(const FMars_PantryRaid_Spec& Self)
{
    const auto Size = Self.EncounterBounds.Max - Self.EncounterBounds.Min;
    if (Self.EncounterBounds.Min.ContainsNaN() || Self.EncounterBounds.Max.ContainsNaN() || Size.X <= 0.0 || Size.Y <= 0.0 || Size.Z <= 0.0)
    { return FMars_Validation(f"PantryRaid EncounterBounds [{Self.EncounterBounds.Min.ToString()}]..[{Self.EncounterBounds.Max.ToString()}] is empty"); }

    auto Result = Self.Population.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Scent.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Guard.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Routing.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Theft.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Speeds.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Hop.Validate();
    if (Result.IsValid() == false) { return Result; }

    return Self.Rhythm.Validate();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_PantryRaid_Params
{
    UPROPERTY()
    FMars_PantryRaid_Spec Spec;

    UPROPERTY()
    FCk_Handle_GroundNavVolume NavVolume;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The rat a lease belongs to and what it may take: one per pack, granted only by the raid's request drain.
struct FMars_PantryRaid_Lease
{
    UPROPERTY()
    FCk_Handle Rat;

    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    FCk_Handle_Item ExpectedItem;

    UPROPERTY()
    FCk_Handle_Inventory_DataOnly SourceInventory;

    UPROPERTY()
    int32 Token = 0;

    // Raid clock.
    UPROPERTY()
    float32 Expiry = 0.0f;
}

struct FMars_PantryRaid_PackRecord
{
    UPROPERTY()
    FCk_Handle_WorldItem Pack;

    // Raid clock since the pack has been grounded, settled and holding a cheese, without a break.
    UPROPERTY()
    TOptional<float32> ArmingSince;

    UPROPERTY()
    bool ScentArmed = false;

    UPROPERTY()
    bool HasCheese = false;

    // Cargo slot indices holding a stealable item within reach.
    UPROPERTY()
    TArray<int32> EligibleSlots;

    UPROPERTY()
    bool Guarded = false;

    // The nearest chef standing guard (valid only while Guarded and one is within GuardExitCm).
    UPROPERTY()
    FCk_Handle GuardChef;

    // Raid clock since every chef has been beyond GuardExitCm (while Guarded).
    UPROPERTY()
    TOptional<float32> ClearSince;

    UPROPERTY()
    TOptional<FMars_PantryRaid_Lease> Lease;

    // Every Guarded -> clear and clear -> Guarded flip (tests read the hysteresis by it).
    UPROPERTY()
    int32 GuardFlips = 0;

    // F4-4 emergence gate: whether a provider route reaches one of the pack's eligible work points from a den's OutsideStand,
    // the pack location, den and raid clock it was last answered for (re-asked when the pack moves, the den differs, or
    // k_ReachRecheckSeconds pass), and whether its "unreachable" line was logged since the pack last moved.
    UPROPERTY()
    bool Reachable = false;

    UPROPERTY()
    TOptional<FVector> ReachCheckedAt;

    UPROPERTY()
    FCk_Handle_RatDen ReachDen;

    UPROPERTY()
    float32 ReachCheckedClock = 0.0f;

    UPROPERTY()
    bool UnreachableLogged = false;

    // F7-1: the den (and pack location) whose "beyond the scent range" line was logged; cleared when the pack moves.
    UPROPERTY()
    bool OutOfScentLogged = false;
}

struct FMars_PantryRaid_ChefSnapshot
{
    UPROPERTY()
    FCk_Handle Root;

    UPROPERTY()
    FVector Location = FVector::ZeroVector;
}

struct FMars_PantryRaid_RatRecord
{
    UPROPERTY()
    FCk_Handle Rat;

    UPROPERTY()
    FCk_Handle_RatDen Den;

    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    int32 OperationId = 0;

    // Dead rats count against the cap until their corpse is cleaned up (Phase 4).
    UPROPERTY()
    bool Dead = false;

    // The den was told the rat is out (MarkOutside).
    UPROPERTY()
    bool MarkedOutside = false;
}

// Written only by the raid's processors (and composed by Add). Every time is on Clock, the raid's own monotonic seconds.
struct FMars_Fragment_PantryRaid
{
    UPROPERTY()
    float32 Clock = 0.0f;

    UPROPERTY()
    bool Ready = false;

    UPROPERTY()
    TArray<FCk_Handle_RatDen> Dens;

    UPROPERTY()
    TArray<FMars_PantryRaid_RatRecord> Rats;

    UPROPERTY()
    TArray<FMars_PantryRaid_PackRecord> Packs;

    UPROPERTY()
    TArray<FMars_PantryRaid_ChefSnapshot> Chefs;

    UPROPERTY()
    int32 NextOperationId = 1;

    UPROPERTY()
    int32 NextToken = 1;

    // Bumped whenever the set of targets changes (a pack armed, lost or emptied).
    UPROPERTY()
    int32 Epoch = 0;

    UPROPERTY()
    TOptional<float32> LastEmergeAt;

    // Emergences asked of a den and not yet answered (operation ids).
    UPROPERTY()
    TArray<int32> PendingOperations;

    // Every lease granted so far (diagnostics and tests).
    UPROPERTY()
    int32 LeasesGranted = 0;

    // Every SpawnRat ignored because its operation already has a rat.
    UPROPERTY()
    int32 StaleSpawns = 0;

    // Every RatHome refused because the rat was loaded (a loaded thief is never retired).
    UPROPERTY()
    int32 RefusedRetirements = 0;

    // Emergence requests sent to a den (one per operation id).
    UPROPERTY()
    int32 EmergencesRequested = 0;

    // "Armed pack unreachable" lines logged (once per pack until it moves).
    UPROPERTY()
    int32 UnreachableTargetLogs = 0;

    // "Armed pack beyond the scent range of a den" lines logged (once per pack until it moves).
    UPROPERTY()
    int32 OutOfScentTargetLogs = 0;

    UPROPERTY()
    float32 NextDiscoveryAt = 0.0f;
}

// Stamped by the Tick processor LAST, once readiness holds; never removed (a raid that lost its field stops emerging but
// keeps every rat it owns).
struct FMars_Tag_PantryRaid_Ready {}

// The Setup pass binds every newly discovered den's signals; the tick re-stamps it when a den is discovered.
struct FMars_Tag_PantryRaid_NeedsDenBinding {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_PantryRaid_OnReady(FCk_Handle_PantryRaid InRaid);
event void FMars_Delegate_PantryRaid_OnReady_MC(FCk_Handle_PantryRaid InRaid);

// A rat entity was requested for InDen's resident InSlot (InRat is under construction).
delegate void FMars_Delegate_PantryRaid_OnRatSpawned(FCk_Handle_PantryRaid InRaid, FCk_Handle InRat, int32 InOperationId);
event void FMars_Delegate_PantryRaid_OnRatSpawned_MC(FCk_Handle_PantryRaid InRaid, FCk_Handle InRat, int32 InOperationId);

struct FMars_Fragment_PantryRaid_Signals
{
    FMars_Delegate_PantryRaid_OnReady_MC OnReady;
    FMars_Delegate_PantryRaid_OnRatSpawned_MC OnRatSpawned;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// A rat asks for the pack's one lease on InSlot's InItem. Granted only when the pack is armed, unguarded, unleased, the
// slot is eligible and still holds InItem; the rat reads the answer through Raid.TryGet_LeaseOf(Rat).
struct FMars_Request_PantryRaid_GrantLease
{
    UPROPERTY()
    FCk_Handle Rat;

    UPROPERTY()
    FCk_Handle_WorldItem Pack;

    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    FCk_Handle_Item Item;

    FMars_Request_PantryRaid_GrantLease() {}

    FMars_Request_PantryRaid_GrantLease(FCk_Handle InRat, FCk_Handle_WorldItem InPack, int32 InSlot, FCk_Handle_Item InItem)
    {
        Rat = InRat;
        Pack = InPack;
        Slot = InSlot;
        Item = InItem;
    }
}

// Drops InRat's lease if it still holds InToken (a stale token changes nothing). Sent on an abort, a refusal or a commit.
struct FMars_Request_PantryRaid_ReleaseLease
{
    UPROPERTY()
    FCk_Handle Rat;

    UPROPERTY()
    int32 Token = 0;

    FMars_Request_PantryRaid_ReleaseLease() {}

    FMars_Request_PantryRaid_ReleaseLease(FCk_Handle InRat, int32 InToken)
    {
        Rat = InRat;
        Token = InToken;
    }
}

// A den granted InSlot to InOperationId (its OnEmergeReady): spawn that resident's rat, once per operation.
struct FMars_Request_PantryRaid_SpawnRat
{
    UPROPERTY()
    FCk_Handle_RatDen Den;

    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    int32 OperationId = 0;

    FMars_Request_PantryRaid_SpawnRat() {}

    FMars_Request_PantryRaid_SpawnRat(FCk_Handle_RatDen InDen, int32 InSlot, int32 InOperationId)
    {
        Den = InDen;
        Slot = InSlot;
        OperationId = InOperationId;
    }
}

// A den admitted InRat home (OnResidentReturned): the raid retires the rat entity (an empty rat only).
struct FMars_Request_PantryRaid_RatHome
{
    UPROPERTY()
    FCk_Handle Rat;

    FMars_Request_PantryRaid_RatHome() {}

    FMars_Request_PantryRaid_RatHome(FCk_Handle InRat)
    {
        Rat = InRat;
    }
}

// InRat died: its den slot cools down for DeadReplacementSeconds; its lease (if any) is dropped. Once per rat.
struct FMars_Request_PantryRaid_RatDied
{
    UPROPERTY()
    FCk_Handle Rat;

    FMars_Request_PantryRaid_RatDied() {}

    FMars_Request_PantryRaid_RatDied(FCk_Handle InRat)
    {
        Rat = InRat;
    }
}

// Drain order: SpawnRat -> RatDied -> RatHome -> ReleaseLease -> GrantLease.
struct FMars_Fragment_PantryRaid_Requests
{
    UPROPERTY()
    TArray<FMars_Request_PantryRaid_SpawnRat> SpawnRatRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRaid_RatDied> RatDiedRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRaid_RatHome> RatHomeRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRaid_ReleaseLease> ReleaseLeaseRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRaid_GrantLease> GrantLeaseRequests;
}
