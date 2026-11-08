//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

// Composed on the rat's root (its SurfaceMotion body; the entity script hangs every visual off it). The rat is owned by
// the PantryRaid that spawned it, never by its den. Its phase ledger is written only by
// UMars_Processor_PantryRat_HandleRequests (and the kernel's own Tick for receipts and clocks); the HFSM (Mars_PantryRat_Hfsm.as)
// reads it and enqueues requests.
asset Mars_PantryRatHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_PantryRat";
    RequiredFragments.Add(FMars_Feature_PantryRat);
    Description = "A pantry rat: phase ledger, capacity-1 loot pocket, guarded claim transaction, threat and flee routing, lethal hit and original-item release receipts";
}
struct FMars_Feature_PantryRat {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// The design's state table (DESIGN_TECH_SPEC section 6) plus BlockedCleanup, its "visible blocked cleanup" exit.
enum EMars_PantryRat_Phase
{
    DormantInDen,
    Peek,
    Emerge,
    Observe,
    BoundApproach,
    WatchGuarded,
    AvoidPlayer,
    Inspect,
    ClaimTell,
    ClaimTransfer,
    CarryMountPending,
    FleeWithLoot,
    FleePause,
    FleeCornered,
    ReturnEmpty,
    DenEnter,
    Dying,
    LootReleasePending,
    DeadHold,
    CorpseFade,
    Destroyed,
    // A release was refused, or the loot left the pocket without a receipt: the corpse stays, visible, never cleaned up.
    BlockedCleanup
}

// What a claim came to (OnClaimResolved). Contended / Cancelled are the benign losses of a race; Failed is anything else.
enum EMars_PantryRat_ClaimResult
{
    None,
    Accepted,
    // The pocket's drain-time acceptance refused it (a chef reached the pack, the lease lapsed, the rat was hit, ...).
    Contended,
    // The item was no longer in the slot (another taker won the same pass), or the operation was cancelled.
    Cancelled,
    Failed
}

// Which authored death topple the corpse plays (DeathToppleLeft / DeathToppleRight): the side the blow pushes it toward,
// or the other side when that one has no floor clearance (utils_pantry_rat::Get_ToppleSide).
enum EMars_PantryRat_ToppleSide
{
    Left,
    Right
}

enum EMars_PantryRat_RoutePurpose
{
    Approach,
    Avoid,
    Flee,
    Home
}

enum EMars_PantryRat_RouteStatus
{
    Idle,
    Moving,
    Arrived,
    Failed
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Who the rat belongs to. Handles, filled by the raid when it spawns the rat.
struct FMars_PantryRat_Links
{
    UPROPERTY()
    FCk_Handle Raid;

    UPROPERTY()
    FCk_Handle Den;

    UPROPERTY()
    int32 ResidentSlot = 0;

    UPROPERTY()
    int32 OperationId = 0;
}

mixin FMars_Validation Validate(const FMars_PantryRat_Links& Self)
{
    if (ck::Is_NOT_Valid(Self.Raid.As_PantryRaid(ECk_SanityCheck::UnChecked)))
    { return FMars_Validation("PantryRat Links.Raid is not a pantry raid"); }

    if (ck::Is_NOT_Valid(Self.Den.As_RatDen(ECk_SanityCheck::UnChecked)))
    { return FMars_Validation("PantryRat Links.Den is not a rat den"); }

    if (Self.ResidentSlot < 0 || Self.OperationId <= 0)
    { return FMars_Validation(f"PantryRat Links ResidentSlot [{Self.ResidentSlot}] / OperationId [{Self.OperationId}] out of range"); }

    return FMars_Validation();
}

// The raid's tuning, copied (utils_pantry_raid::Make_RatTuning), not chased through the raid handle.
struct FMars_PantryRat_Tuning
{
    UPROPERTY()
    FMars_PantryRaid_Guard Guard;

    UPROPERTY()
    FMars_PantryRaid_Scent Scent;

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

    // The corpse's minimum X-eyed hold, counted from the death (DESIGN_TECH_SPEC section 14: DeathHold 3 s).
    UPROPERTY()
    float32 DeathHoldSeconds = 3.0f;

    // The corpse's dither out, FadeAlpha 1 -> 0, once the hold and the loot's receipt are both in (returnFade / corpseFade).
    UPROPERTY()
    float32 CorpseFadeSeconds = 0.35f;

    // The empty return's dither out after the crouch into the den.
    UPROPERTY()
    float32 ReturnFadeSeconds = 0.25f;

    // DenEnter's crouch through the portal before the return fade starts (the DenEnter clip is 1.0 s).
    UPROPERTY()
    float32 DenCrouchSeconds = 1.0f;
}

mixin FMars_Validation Validate(const FMars_PantryRat_Tuning& Self)
{
    auto Result = Self.Guard.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Scent.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Routing.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Theft.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Speeds.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Hop.Validate();
    if (Result.IsValid() == false) { return Result; }

    Result = Self.Rhythm.Validate();
    if (Result.IsValid() == false) { return Result; }

    if (Self.DeathHoldSeconds < 0.0f)
    { return FMars_Validation(f"PantryRat Tuning DeathHoldSeconds [{Self.DeathHoldSeconds}] is negative"); }

    if (Self.CorpseFadeSeconds <= 0.0f || Self.ReturnFadeSeconds <= 0.0f || Self.DenCrouchSeconds < 0.0f)
    {
        return FMars_Validation(f"PantryRat Tuning fades CorpseFadeSeconds [{Self.CorpseFadeSeconds}] / ReturnFadeSeconds "
            + f"[{Self.ReturnFadeSeconds}] must be positive and DenCrouchSeconds [{Self.DenCrouchSeconds}] not negative");
    }

    return FMars_Validation();
}

struct FMars_PantryRat_Spec
{
    UPROPERTY()
    FMars_PantryRat_Links Links;

    UPROPERTY()
    FMars_PantryRat_Tuning Tuning;

    // The body zone's box round the rat's body (root frame, centred on the root; the root rides utils_pantry_rat::k_Clearance
    // above the floor). R02 body: rump 26.2 cm behind the root, nose 30.7 ahead, 31 wide, back top 35.2 above the floor, so
    // the box spans 0.5..35.5 cm up and stops 2.2 cm short of the nose tip (R01: (20, 15, 17)).
    UPROPERTY()
    FVector HurtboxHalfExtents = FVector(28.5, 15.5, 17.5);
}

mixin FMars_Validation Validate(const FMars_PantryRat_Spec& Self)
{
    const auto Links = Self.Links.Validate();
    if (Links.IsValid() == false)
    { return Links; }

    const auto Tuning = Self.Tuning.Validate();
    if (Tuning.IsValid() == false)
    { return Tuning; }

    if (Self.HurtboxHalfExtents.X <= 0.0 || Self.HurtboxHalfExtents.Y <= 0.0 || Self.HurtboxHalfExtents.Z <= 0.0)
    { return FMars_Validation(f"PantryRat HurtboxHalfExtents [{Self.HurtboxHalfExtents.ToString()}] has a non-positive extent"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_PantryRat_Params
{
    UPROPERTY()
    FMars_PantryRat_Spec Spec;

    UPROPERTY()
    FCk_Handle_Monster Monster;

    UPROPERTY()
    FCk_Handle_SurfaceNavigator Navigator;

    // The capacity-1 pocket on a child entity the rat owns (its lifetime owner is the rat root).
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Pocket;

    // The node AttachPoint.Mars.RatMouth names (the jaw socket's rest frame; the assembly re-parents it to Carry_Mouth).
    UPROPERTY()
    FCk_Handle_Transform MouthNode;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The slot the rat works and what it may take (copied from its lease).
struct FMars_PantryRat_Target
{
    UPROPERTY()
    FCk_Handle_WorldItem Pack;

    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    FCk_Handle_Item ExpectedItem;

    UPROPERTY()
    FCk_Handle_Inventory_DataOnly SourceInventory;

    UPROPERTY()
    int32 Token = 0;

    FMars_PantryRat_Target() {}

    FMars_PantryRat_Target(FCk_Handle_WorldItem InPack, const FMars_PantryRaid_Lease& InLease)
    {
        Pack = InPack;
        Slot = InLease.Slot;
        ExpectedItem = InLease.ExpectedItem;
        SourceInventory = InLease.SourceInventory;
        Token = InLease.Token;
    }
}

// The nearest chef as the rat's hysteresis sees it (Tick).
struct FMars_PantryRat_Threat
{
    UPROPERTY()
    bool Active = false;

    UPROPERTY()
    FCk_Handle Chef;

    UPROPERTY()
    FVector ChefLocation = FVector::ZeroVector;

    UPROPERTY()
    float32 Distance = 0.0f;
}

struct FMars_PantryRat_Route
{
    UPROPERTY()
    FVector Goal = FVector::ZeroVector;

    // Bumped by every MoveTo the drain resolves; a navigator answer for another goal is stale.
    UPROPERTY()
    int32 Epoch = 0;

    UPROPERTY()
    EMars_PantryRat_RouteStatus Status = EMars_PantryRat_RouteStatus::Idle;

    UPROPERTY()
    EMars_PantryRat_RoutePurpose Purpose = EMars_PantryRat_RoutePurpose::Approach;

    // The phase the move was issued in: a route answer counts only in the phase that asked for it.
    UPROPERTY()
    EMars_PantryRat_Phase IssuedIn = EMars_PantryRat_Phase::Emerge;

    // The navigator's PathMode once it took the move (Provider is the only admitted mode).
    UPROPERTY()
    EMars_SurfaceNavigator_PathMode PathMode = EMars_SurfaceNavigator_PathMode::Provider;
}

// The burst / pause rhythm the drain plans as a phase starts (seeded by the operation id).
struct FMars_PantryRat_Rhythm
{
    UPROPERTY()
    int32 BurstsPlanned = 0;

    UPROPERTY()
    float32 PauseDeadline = 0.0f;

    // Every phase entry so far: the salt of the rhythm's variation.
    UPROPERTY()
    int32 Entries = 0;
}

// The death and loot-release receipts.
struct FMars_PantryRat_Death
{
    UPROPERTY()
    bool LethalPending = false;

    // Bumped by every accepted lethal hit (once: further hits are ignored).
    UPROPERTY()
    int32 Sequence = 0;

    // Bumped by every release the rat issues; one per death.
    UPROPERTY()
    int32 ReleaseOperationId = 0;

    UPROPERTY()
    bool ReleaseReceipt = false;

    // Persistent loot: its own world item; transient loot: the world item spawned to adopt it.
    UPROPERTY()
    FCk_Handle ReleaseHolder;

    // The rat's clock at its death (the corpse's hold counts from here, not from the drop's receipt).
    UPROPERTY()
    float32 DiedAt = 0.0f;

    // DiedAt + DeathHoldSeconds: CorpseFade is admitted at or after it, and only with the loot's receipt.
    UPROPERTY()
    float32 CorpseDeadline = 0.0f;

    // The accepted lethal hit's impulse (world): the assembly picks the topple side from it.
    UPROPERTY()
    FVector HitImpulse = FVector::ZeroVector;

    // The faded corpse's one destroy request.
    UPROPERTY()
    bool DestroyRequested = false;

    UPROPERTY()
    FString BlockedReason;
}

// Written only by the rat's request drain and its Tick (receipts, clocks, threat); composed by Add.
struct FMars_Fragment_PantryRat
{
    UPROPERTY()
    EMars_PantryRat_Phase Phase = EMars_PantryRat_Phase::Emerge;

    UPROPERTY()
    float32 PhaseStartedAt = 0.0f;

    // The rat's own monotonic seconds.
    UPROPERTY()
    float32 Clock = 0.0f;

    UPROPERTY()
    TOptional<FMars_PantryRat_Target> Target;

    UPROPERTY()
    FMars_PantryRat_Threat Threat;

    UPROPERTY()
    FMars_PantryRat_Route Route;

    UPROPERTY()
    FMars_PantryRat_Rhythm Rhythm;

    // The exact item in the pocket (invalid while empty).
    UPROPERTY()
    FCk_Handle_Item Loot;

    // Transient loot's one Visual world item on the mouth node.
    UPROPERTY()
    FCk_Handle CarryVisual;

    UPROPERTY()
    bool CarryReceipt = false;

    UPROPERTY()
    FMars_PantryRat_Death Death;

    // The one fade clock of every rat surface (presentation copies it to CPD 14 each frame it changes): 1 = solid, 0 = gone.
    // Ramped only by the kernel Tick (DenEnter after the crouch, CorpseFade); never while the pocket holds anything.
    UPROPERTY()
    float32 FadeAlpha = 1.0f;

    // The empty return finished its fade: the presentation hides every rat primitive (FadeAlpha is reset to 1 while hidden).
    UPROPERTY()
    bool Hidden = false;

    // The rat's clock when it went DormantInDen (the den's admission answer is waited on from here).
    UPROPERTY()
    float32 HiddenAt = 0.0f;

    // The hidden rat asked its raid to retire it (once; the den's admission normally retires it first).
    UPROPERTY()
    bool HomeAsked = false;

    // Every request a loaded rat refused for wanting it home, faded or retired (logged once, counted always).
    UPROPERTY()
    int32 LoadedVetoes = 0;

    // Raid clock-free: the rat's clock since the raid last offered it no target (unset while it has one).
    UPROPERTY()
    TOptional<float32> NoTargetSince;

    UPROPERTY()
    EMars_PantryRat_ClaimResult LastClaimResult = EMars_PantryRat_ClaimResult::None;

    // Every claim transfer the rat issued to an inventory (tests: a guarded pack never sees one).
    UPROPERTY()
    int32 ClaimTransfersIssued = 0;

    // Every Advance the edge table refused (a loaded rat's return / fade, a stale From).
    UPROPERTY()
    int32 RejectedAdvances = 0;

    // Every request ignored as stale (a claim result outside ClaimTransfer, a navigator answer for another goal).
    UPROPERTY()
    int32 StaleResults = 0;

    // The last utils_pantry_rat::k_FleeGoalHistory flee goals the drain admitted, in order (tests read the den-mouth
    // keep-out from it).
    UPROPERTY()
    TArray<FVector> FleeGoals;

    UPROPERTY()
    int32 PhaseChanges = 0;

    // Face requests the drain sent the navigator (Inspect / ClaimTell entry, the claim): the thief turns to the slot.
    UPROPERTY()
    int32 FacesIssued = 0;

    // Every phase step this pass took, in order (Set_Phase appends; the drain and the Tick log and broadcast each one, then
    // clear): a pass that goes FleeWithLoot -> Dying -> LootReleasePending reports both steps, Dying included.
    UPROPERTY()
    TArray<EMars_PantryRat_Phase> StepFrom;

    UPROPERTY()
    TArray<EMars_PantryRat_Phase> StepTo;
}

// The Setup processor binds the navigator's signals and the body zone's hits, then removes this tag.
struct FMars_Tag_PantryRat_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_PantryRat_OnPhaseChanged(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew);
event void FMars_Delegate_PantryRat_OnPhaseChanged_MC(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew);

delegate void FMars_Delegate_PantryRat_OnClaimResolved(FCk_Handle_PantryRat InRat, EMars_PantryRat_ClaimResult InResult, FCk_Handle_Item InItem);
event void FMars_Delegate_PantryRat_OnClaimResolved_MC(FCk_Handle_PantryRat InRat, EMars_PantryRat_ClaimResult InResult, FCk_Handle_Item InItem);

struct FMars_Fragment_PantryRat_Signals
{
    FMars_Delegate_PantryRat_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_PantryRat_OnClaimResolved_MC OnClaimResolved;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// The control layer's phase change: applied only when the rat is still in From and the edge table allows From -> To for
// its load (a loaded rat never returns, enters a den or fades). Target rides an Inspect.
struct FMars_Request_PantryRat_Advance
{
    UPROPERTY()
    EMars_PantryRat_Phase From = EMars_PantryRat_Phase::Observe;

    UPROPERTY()
    EMars_PantryRat_Phase To = EMars_PantryRat_Phase::Observe;

    UPROPERTY()
    TOptional<FMars_PantryRat_Target> Target;

    FMars_Request_PantryRat_Advance() {}

    FMars_Request_PantryRat_Advance(EMars_PantryRat_Phase InFrom, EMars_PantryRat_Phase InTo)
    {
        From = InFrom;
        To = InTo;
    }

    FMars_Request_PantryRat_Advance(EMars_PantryRat_Phase InFrom, EMars_PantryRat_Phase InTo, const FMars_PantryRat_Target& InTarget)
    {
        From = InFrom;
        To = InTo;
        Target = TOptional<FMars_PantryRat_Target>(InTarget);
    }
}

// A move admitted only on a real provider route (Try_FindPathSync Success); a flee goal of a loaded rat also keeps
// LoadedPortalKeepOutCm from every den portal along the whole route.
struct FMars_Request_PantryRat_MoveTo
{
    UPROPERTY()
    FVector Goal = FVector::ZeroVector;

    UPROPERTY()
    float32 Speed = 100.0f;

    UPROPERTY()
    EMars_PantryRat_RoutePurpose Purpose = EMars_PantryRat_RoutePurpose::Approach;

    FMars_Request_PantryRat_MoveTo() {}

    FMars_Request_PantryRat_MoveTo(FVector InGoal, float32 InSpeed, EMars_PantryRat_RoutePurpose InPurpose)
    {
        Goal = InGoal;
        Speed = InSpeed;
        Purpose = InPurpose;
    }
}

struct FMars_Request_PantryRat_Stop
{
    // AngelScript rejects a TArray of an empty struct.
    UPROPERTY()
    bool Requested = true;
}

// At ClaimTell's deadline: issue the guarded transfer of the leased item into the pocket (never a CargoSlot Take).
struct FMars_Request_PantryRat_Claim
{
    UPROPERTY()
    int32 Token = 0;

    FMars_Request_PantryRat_Claim() {}

    FMars_Request_PantryRat_Claim(int32 InToken)
    {
        Token = InToken;
    }
}

// The inventory's answer to a claim transfer (enqueued by the transfer callback).
struct FMars_Request_PantryRat_ClaimResult
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FCk_Handle_Item NewItemInTarget;

    UPROPERTY()
    ECk_Inventory_OperationResult_Transfer Result = ECk_Inventory_OperationResult_Transfer::Success;

    FMars_Request_PantryRat_ClaimResult() {}

    FMars_Request_PantryRat_ClaimResult(FCk_Handle_Item InItem, FCk_Handle_Item InNewItemInTarget, ECk_Inventory_OperationResult_Transfer InResult)
    {
        Item = InItem;
        NewItemInTarget = InNewItemInTarget;
        Result = InResult;
    }
}

// The body zone's scaled hit (bound in Setup). Lethal only for a positive weapon hit: Causer an item with a Strike trait,
// Instigator a chef root (a Hotbar).
struct FMars_Request_PantryRat_TakeHit
{
    UPROPERTY()
    FMars_DamageEvent Event;

    FMars_Request_PantryRat_TakeHit() {}

    FMars_Request_PantryRat_TakeHit(FMars_DamageEvent InEvent)
    {
        Event = InEvent;
    }
}

// The monster's OnDied (bound in Setup).
struct FMars_Request_PantryRat_Died
{
    UPROPERTY()
    FMars_DamageEvent Cause;

    FMars_Request_PantryRat_Died() {}

    FMars_Request_PantryRat_Died(FMars_DamageEvent InCause)
    {
        Cause = InCause;
    }
}

// The navigator's OnArrived / OnFailed (bound in Setup); counted only for the route's own goal.
struct FMars_Request_PantryRat_NavResult
{
    UPROPERTY()
    FVector Goal = FVector::ZeroVector;

    UPROPERTY()
    bool Arrived = false;

    FMars_Request_PantryRat_NavResult() {}

    FMars_Request_PantryRat_NavResult(FVector InGoal, bool InArrived)
    {
        Goal = InGoal;
        Arrived = InArrived;
    }
}

// The loot's world item refused the rat's release.
struct FMars_Request_PantryRat_ReleaseRefused
{
    UPROPERTY()
    FCk_Handle WorldItem;

    UPROPERTY()
    EMars_WorldItem_ReleaseRefusal Reason = EMars_WorldItem_ReleaseRefusal::NotMounted;

    FMars_Request_PantryRat_ReleaseRefused() {}

    FMars_Request_PantryRat_ReleaseRefused(FCk_Handle InWorldItem, EMars_WorldItem_ReleaseRefusal InReason)
    {
        WorldItem = InWorldItem;
        Reason = InReason;
    }
}

// Drain priority (DESIGN_TECH_SPEC section 13): destruction guard -> TakeHit / Died -> ClaimResult / ReleaseRefused ->
// Stop -> NavResult -> Advance -> MoveTo -> Claim.
struct FMars_Fragment_PantryRat_Requests
{
    UPROPERTY()
    TArray<FMars_Request_PantryRat_TakeHit> TakeHitRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRat_Died> DiedRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRat_ClaimResult> ClaimResultRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRat_ReleaseRefused> ReleaseRefusedRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRat_Stop> StopRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRat_NavResult> NavResultRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRat_Advance> AdvanceRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRat_MoveTo> MoveToRequests;

    UPROPERTY()
    TArray<FMars_Request_PantryRat_Claim> ClaimRequests;
}
