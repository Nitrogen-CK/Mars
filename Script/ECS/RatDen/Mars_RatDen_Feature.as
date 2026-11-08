//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

// Composed on the den's root (its transform is the den frame: +X out of the opening, Z up, origin on the floor at the
// front plane). A den is a service of the PantryRaid that discovers it (TAG_MarsRatDen): it owns its resident slots and
// their emergence operation ids, never a rat's lifetime.
asset Mars_RatDenHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_RatDen";
    RequiredFragments.Add(FMars_Feature_RatDen);
    Description = "A rat den: portal frames, resident slots (dormant, pending, outside, dead cooldown) with emergence operation ids, and the eye occupancy proxy";
}
struct FMars_Feature_RatDen {}

namespace utils_rat_den
{
    // The entity tag a PantryRaid discovers dens by.
    const FName DenTag = n"TAG_MarsRatDen";
}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_RatDen_SlotState
{
    // Hidden in the den: the eye proxy may show it.
    Dormant,
    // An emergence was granted (OnEmergeReady) and its rat is on its way out.
    Pending,
    // Its rat is out in the encounter.
    Outside,
    // Its rat died; a replacement resident is back (Dormant) once the raid's clock passes DeadUntil.
    DeadCooldown
}

// Why an AdmitReturn left the slot as it was (OnReturnRefused).
enum EMars_RatDen_ReturnRefusal
{
    // The returning rat's pocket is not empty: a loaded thief never goes home.
    Loaded,
    // The rat is not a pantry rat, or it is ending.
    NotARat,
    // The slot is out of range or its resident is not Outside / Pending.
    NotOutside
}

enum EMars_RatDen_Portal
{
    EntryPortal,
    ExitPortal,
    OutsideStand,
    ReturnAdmission,
    // Inside the arch: where an empty returning rat crouches (DenEnter) and fades.
    Inside
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The Phase 1 markers in den-local cm (Blender (x, y, z) -> UE (x, -y, z)); all sit on the floor outside the recess, except
// Inside.
struct FMars_RatDen_Portals
{
    UPROPERTY()
    FVector EntryPortal = FVector(24.0, 14.0, 0.0);

    UPROPERTY()
    FVector ExitPortal = FVector(24.0, -14.0, 0.0);

    UPROPERTY()
    FVector OutsideStand = FVector(75.0, 0.0, 0.0);

    UPROPERTY()
    FVector ReturnAdmission = FVector(48.0, 0.0, 0.0);

    // The DenEnter stand, on the den axis behind the front plane (x 0; the arch spans x -47..9.5, the opening 60 wide):
    // the empty rat walks here from ReturnAdmission and crouches and fades only after it arrives. 26 cm in because the
    // rat's navigator accepts an arrival 30 cm short of the goal, so the root stops at x <= 4, inside the arch.
    UPROPERTY()
    FVector Inside = FVector(-26.0, 0.0, 0.0);
}

mixin FMars_Validation Validate(const FMars_RatDen_Portals& Self)
{
    if (Self.EntryPortal.ContainsNaN() || Self.ExitPortal.ContainsNaN() || Self.OutsideStand.ContainsNaN() || Self.ReturnAdmission.ContainsNaN()
        || Self.Inside.ContainsNaN())
    { return FMars_Validation("RatDen Portals has a non-finite marker"); }

    if (Self.Inside.X > 0.0)
    { return FMars_Validation(f"RatDen Portals: Inside [{Self.Inside.X}] must lie behind the front plane (x <= 0)"); }

    if (Self.OutsideStand.X <= Self.ReturnAdmission.X || Self.ReturnAdmission.X <= 0.0)
    {
        return FMars_Validation(f"RatDen Portals: OutsideStand [{Self.OutsideStand.X}] must lie beyond ReturnAdmission [{Self.ReturnAdmission.X}], "
            + "which must lie in front of the opening (+X)");
    }

    return FMars_Validation();
}

// Built by the entity script before Add. Not UPROPERTYs: spawn params never carry handles.
struct FMars_RatDen_Parts
{
    // The paired eye plate in the recess; optional (headless tests pass none).
    FCk_Handle_UnrealComponent EyePlate;
}

struct FMars_RatDen_Spec
{
    UPROPERTY()
    FMars_RatDen_Portals Portals;

    UPROPERTY()
    int32 ResidentCount = 2;

    FMars_RatDen_Parts Parts;

    FMars_RatDen_Spec() {}

    FMars_RatDen_Spec(int32 InResidentCount)
    {
        ResidentCount = InResidentCount;
    }
}

mixin FMars_Validation Validate(const FMars_RatDen_Spec& Self)
{
    if (Self.ResidentCount < 1 || Self.ResidentCount > utils_rat_den::k_MaxResidents)
    { return FMars_Validation(f"RatDen ResidentCount [{Self.ResidentCount}] is outside 1..{utils_rat_den::k_MaxResidents}"); }

    return Self.Portals.Validate();
}

namespace utils_rat_den
{
    const int32 k_MaxResidents = 4;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_RatDen_Params
{
    UPROPERTY()
    FMars_RatDen_Portals Portals;

    UPROPERTY()
    int32 ResidentCount = 2;

    UPROPERTY()
    FCk_Handle_UnrealComponent EyePlate;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_RatDen_Resident
{
    UPROPERTY()
    EMars_RatDen_SlotState State = EMars_RatDen_SlotState::Dormant;

    // The emergence this slot's rat belongs to (0 = none). A MarkOutside, AdmitReturn or ResidentDied naming another is stale.
    UPROPERTY()
    int32 OperationId = 0;

    // DeadCooldown only: the raid clock (seconds) at which a replacement resident is Dormant again.
    UPROPERTY()
    float32 DeadUntil = 0.0f;
}

// Written only by UMars_Processor_RatDen_HandleRequests (and composed by Add).
struct FMars_Fragment_RatDen
{
    UPROPERTY()
    TArray<FMars_RatDen_Resident> Residents;

    // SetEyes(false) hides the proxy whatever the residents are.
    UPROPERTY()
    bool EyesEnabled = true;

    // The Dormant resident the paired eye proxy stands for; unset = the plate is black (vacant). Never a slot whose rat is
    // Pending or Outside, so one resident's proxy and its real head never both show.
    UPROPERTY()
    TOptional<int32> EyeSlot;

    // Every refused AdmitReturn so far (diagnostics and tests).
    UPROPERTY()
    int32 RefusedReturns = 0;

    // Every request ignored as stale (an operation id that is not the slot's).
    UPROPERTY()
    int32 StaleRequests = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// A Dormant slot was granted to an emergence: the raid spawns that resident's rat for InOperationId.
delegate void FMars_Delegate_RatDen_OnEmergeReady(FCk_Handle_RatDen InDen, int32 InSlot, int32 InOperationId);
event void FMars_Delegate_RatDen_OnEmergeReady_MC(FCk_Handle_RatDen InDen, int32 InSlot, int32 InOperationId);

// An empty rat was admitted home: its slot is Dormant again (the raid retires the rat entity).
delegate void FMars_Delegate_RatDen_OnResidentReturned(FCk_Handle_RatDen InDen, int32 InSlot, FCk_Handle InRat);
event void FMars_Delegate_RatDen_OnResidentReturned_MC(FCk_Handle_RatDen InDen, int32 InSlot, FCk_Handle InRat);

delegate void FMars_Delegate_RatDen_OnReturnRefused(FCk_Handle_RatDen InDen, int32 InSlot, FCk_Handle InRat, EMars_RatDen_ReturnRefusal InReason);
event void FMars_Delegate_RatDen_OnReturnRefused_MC(FCk_Handle_RatDen InDen, int32 InSlot, FCk_Handle InRat, EMars_RatDen_ReturnRefusal InReason);

// The proxy changed: InShown, standing for the Dormant resident InEyeSlot; not shown = vacant, black (InEyeSlot is then
// meaningless). The assembly writes the plate.
delegate void FMars_Delegate_RatDen_OnEyesChanged(FCk_Handle_RatDen InDen, bool InShown, int32 InEyeSlot);
event void FMars_Delegate_RatDen_OnEyesChanged_MC(FCk_Handle_RatDen InDen, bool InShown, int32 InEyeSlot);

struct FMars_Fragment_RatDen_Signals
{
    FMars_Delegate_RatDen_OnEmergeReady_MC OnEmergeReady;
    FMars_Delegate_RatDen_OnResidentReturned_MC OnResidentReturned;
    FMars_Delegate_RatDen_OnReturnRefused_MC OnReturnRefused;
    FMars_Delegate_RatDen_OnEyesChanged_MC OnEyesChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Grants the lowest available slot (Dormant, or DeadCooldown whose DeadUntil <= Now) to InOperationId: Pending, then
// OnEmergeReady. No available slot: nothing happens (the raid asks only when Get_AvailableSlot(Now) is set).
struct FMars_Request_RatDen_Emerge
{
    UPROPERTY()
    int32 OperationId = 0;

    // The raid's clock, seconds.
    UPROPERTY()
    float32 Now = 0.0f;

    FMars_Request_RatDen_Emerge() {}

    FMars_Request_RatDen_Emerge(int32 InOperationId, float32 InNow)
    {
        OperationId = InOperationId;
        Now = InNow;
    }
}

// The rat for InOperationId is out: Pending -> Outside.
struct FMars_Request_RatDen_MarkOutside
{
    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    int32 OperationId = 0;

    FMars_Request_RatDen_MarkOutside() {}

    FMars_Request_RatDen_MarkOutside(int32 InSlot, int32 InOperationId)
    {
        Slot = InSlot;
        OperationId = InOperationId;
    }
}

// An empty rat at the ReturnAdmission marker asks to go home. Admitted only when its pocket is empty (read here, from the
// rat itself); otherwise refused, logged, never ensured.
struct FMars_Request_RatDen_AdmitReturn
{
    UPROPERTY()
    FCk_Handle Rat;

    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    int32 OperationId = 0;

    FMars_Request_RatDen_AdmitReturn() {}

    FMars_Request_RatDen_AdmitReturn(FCk_Handle InRat, int32 InSlot, int32 InOperationId)
    {
        Rat = InRat;
        Slot = InSlot;
        OperationId = InOperationId;
    }
}

// The slot's rat died: DeadCooldown until InDeadUntil (raid clock).
struct FMars_Request_RatDen_ResidentDied
{
    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    int32 OperationId = 0;

    UPROPERTY()
    float32 DeadUntil = 0.0f;

    FMars_Request_RatDen_ResidentDied() {}

    FMars_Request_RatDen_ResidentDied(int32 InSlot, int32 InOperationId, float32 InDeadUntil)
    {
        Slot = InSlot;
        OperationId = InOperationId;
        DeadUntil = InDeadUntil;
    }
}

struct FMars_Request_RatDen_SetEyes
{
    UPROPERTY()
    bool Enabled = true;

    FMars_Request_RatDen_SetEyes() {}

    FMars_Request_RatDen_SetEyes(bool InEnabled)
    {
        Enabled = InEnabled;
    }
}

// Drain order: Emerge -> MarkOutside -> AdmitReturn -> ResidentDied -> SetEyes, then the eye proxy is re-derived once.
struct FMars_Fragment_RatDen_Requests
{
    UPROPERTY()
    TArray<FMars_Request_RatDen_Emerge> EmergeRequests;

    UPROPERTY()
    TArray<FMars_Request_RatDen_MarkOutside> MarkOutsideRequests;

    UPROPERTY()
    TArray<FMars_Request_RatDen_AdmitReturn> AdmitReturnRequests;

    UPROPERTY()
    TArray<FMars_Request_RatDen_ResidentDied> ResidentDiedRequests;

    UPROPERTY()
    TArray<FMars_Request_RatDen_SetEyes> SetEyesRequests;
}
