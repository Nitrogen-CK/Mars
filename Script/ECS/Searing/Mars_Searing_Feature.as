//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_SearingHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Searing";
    RequiredFragments.Add(FMars_Feature_Searing);
    Description = "A searing minigame on a station: a steak cube (a dynamic body) on a hot pan (kinematic bodies the operator's look tilts and lifts); the face on the pan sears";
}
struct FMars_Feature_Searing {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The steak's six faces, by their outward normal in the steak's own frame. int32(Face) indexes the sear ledger.
enum EMars_Searing_Face
{
    PosX,
    NegX,
    PosY,
    NegY,
    PosZ,
    NegZ
}

enum EMars_Searing_Heat
{
    Cold,
    Hot
}

enum EMars_Searing_Sizzle
{
    Quiet,
    Sizzling
}

// NoSteak: between a loss and the respawn (and before the first spawn). OnPan / Airborne: a live steak resting / not
// resting on the pan base. Done: six faces seared; the steak stays, inert, until Reset.
enum EMars_Searing_Phase
{
    NoSteak,
    OnPan,
    Airborne,
    Done
}

struct FMars_Searing_CookSpec
{
    // Seconds of contact with a hot pan that sear one face from raw to done.
    UPROPERTY()
    float32 SecondsPerFace = 3.0f;

    FMars_Searing_CookSpec() {}

    FMars_Searing_CookSpec(float32 InSecondsPerFace)
    {
        SecondsPerFace = InSecondsPerFace;
    }
}

// The steak body: a box of HalfSize, explicit mass and surface. Spawned HalfSize + SpawnLift above the base top.
// Friction combines with the pan's as sqrt(a * b): 0.6 on the pan's 0.3 (an oiled pan) gives 0.42, so a resting steak
// starts sliding past a 23-degree tilt and is well on its way at a 30-degree tilt; 0.8 on 0.8 would need 39 degrees.
struct FMars_Searing_SteakSpec
{
    UPROPERTY()
    float32 HalfSize = 12.0f;

    UPROPERTY()
    float32 MassKg = 0.4f;

    UPROPERTY()
    float32 Friction = 0.6f;

    UPROPERTY()
    float32 Restitution = 0.15f;

    UPROPERTY()
    float32 LinearDamping = 0.05f;

    UPROPERTY()
    float32 AngularDamping = 0.15f;

    UPROPERTY()
    float32 SpawnLift = 2.0f;

    FMars_Searing_SteakSpec() {}

    FMars_Searing_SteakSpec(
        float32 InHalfSize,
        float32 InMassKg,
        float32 InFriction,
        float32 InRestitution,
        float32 InLinearDamping,
        float32 InAngularDamping,
        float32 InSpawnLift)
    {
        HalfSize = InHalfSize;
        MassKg = InMassKg;
        Friction = InFriction;
        Restitution = InRestitution;
        LinearDamping = InLinearDamping;
        AngularDamping = InAngularDamping;
        SpawnLift = InSpawnLift;
    }
}

// The pan's disc, where a steak counts as on it and beyond which it is lost; how long a lost body keeps flying and
// bouncing before it is destroyed; how long the pan stays empty before a fresh steak.
struct FMars_Searing_LossSpec
{
    UPROPERTY()
    float32 PanRadius = 34.0f;

    UPROPERTY()
    float32 LingerSeconds = 2.5f;

    UPROPERTY()
    float32 RespawnSeconds = 0.8f;

    FMars_Searing_LossSpec() {}

    FMars_Searing_LossSpec(float32 InPanRadius, float32 InLingerSeconds, float32 InRespawnSeconds)
    {
        PanRadius = InPanRadius;
        LingerSeconds = InLingerSeconds;
        RespawnSeconds = InRespawnSeconds;
    }
}

// Built by the placing script before Add: the pan is an Implement already composed on the pan node (the kernel drives it
// from the heat and forwards the looks to it), and PanBaseBody is the kinematic disc under that node whose contacts count
// as "on the pan".
struct FMars_Searing_Nodes
{
    UPROPERTY()
    FCk_Handle_Implement Pan;

    UPROPERTY()
    FCk_Handle_JoltBody PanBaseBody;

    FMars_Searing_Nodes() {}

    FMars_Searing_Nodes(FCk_Handle_Implement InPan, FCk_Handle_JoltBody InPanBaseBody)
    {
        Pan = InPan;
        PanBaseBody = InPanBaseBody;
    }
}

struct FMars_Searing_Spec
{
    UPROPERTY()
    FMars_Searing_CookSpec Cook;

    UPROPERTY()
    FMars_Searing_SteakSpec Steak;

    UPROPERTY()
    FMars_Searing_LossSpec Loss;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Searing_Nodes Nodes;

    FMars_Searing_Spec() {}

    FMars_Searing_Spec(
        FMars_Searing_CookSpec InCook,
        FMars_Searing_SteakSpec InSteak,
        FMars_Searing_LossSpec InLoss)
    {
        Cook = InCook;
        Steak = InSteak;
        Loss = InLoss;
    }
}

// A face that never sears, a steak with no size or mass, a restitution outside the physical range, or a pan disc no wider
// than the steak (it would be lost the moment it spawned) each make the minigame unplayable.
mixin FMars_Validation Validate(const FMars_Searing_Spec& Self)
{
    if (Self.Cook.SecondsPerFace <= 0.0f)
    { return FMars_Validation(f"Searing has a non-positive Cook.SecondsPerFace [{Self.Cook.SecondsPerFace}]"); }

    if (Self.Steak.HalfSize <= 0.0f)
    { return FMars_Validation(f"Searing has a non-positive Steak.HalfSize [{Self.Steak.HalfSize}]"); }

    if (Self.Steak.MassKg <= 0.0f)
    { return FMars_Validation(f"Searing has a non-positive Steak.MassKg [{Self.Steak.MassKg}]"); }

    if (Self.Steak.Friction < 0.0f)
    { return FMars_Validation(f"Searing has a negative Steak.Friction [{Self.Steak.Friction}]"); }

    if (Self.Steak.Restitution < 0.0f || Self.Steak.Restitution > 1.0f)
    { return FMars_Validation(f"Searing has Steak.Restitution [{Self.Steak.Restitution}] outside [0, 1]"); }

    if (Self.Steak.LinearDamping < 0.0f)
    { return FMars_Validation(f"Searing has a negative Steak.LinearDamping [{Self.Steak.LinearDamping}]"); }

    if (Self.Steak.AngularDamping < 0.0f)
    { return FMars_Validation(f"Searing has a negative Steak.AngularDamping [{Self.Steak.AngularDamping}]"); }

    if (Self.Steak.SpawnLift < 0.0f)
    { return FMars_Validation(f"Searing has a negative Steak.SpawnLift [{Self.Steak.SpawnLift}]"); }

    if (Self.Loss.PanRadius <= Self.Steak.HalfSize)
    { return FMars_Validation(f"Searing has Loss.PanRadius [{Self.Loss.PanRadius}] not above Steak.HalfSize [{Self.Steak.HalfSize}]"); }

    if (Self.Loss.LingerSeconds < 0.0f)
    { return FMars_Validation(f"Searing has a negative Loss.LingerSeconds [{Self.Loss.LingerSeconds}]"); }

    if (Self.Loss.RespawnSeconds < 0.0f)
    { return FMars_Validation(f"Searing has a negative Loss.RespawnSeconds [{Self.Loss.RespawnSeconds}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Searing_Params
{
    UPROPERTY()
    FMars_Searing_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The live steak (invalid handles while NoSteak). Its entity carries a Resting on the pan base body.
struct FMars_Searing_SteakState
{
    // The steak entity (a lifetime child of the station).
    UPROPERTY()
    FCk_Handle Entity;

    UPROPERTY()
    FCk_Handle_JoltBody Body;

    // Six, 0 raw .. 1 seared, clamped; indexed by int32(EMars_Searing_Face).
    UPROPERTY()
    TArray<float32> FaceSear;

    // NoSteak only: seconds until the next steak.
    UPROPERTY()
    float32 RespawnCountdown = 0.0f;
}

// A steak that left the pan and is still flying/bouncing; destroyed when Age reaches Loss.LingerSeconds.
struct FMars_Searing_LostSteak
{
    UPROPERTY()
    FCk_Handle Entity;

    UPROPERTY()
    float32 Age = 0.0f;

    FMars_Searing_LostSteak() {}

    FMars_Searing_LostSteak(FCk_Handle InEntity)
    {
        Entity = InEntity;
    }
}

struct FMars_Searing_Tally
{
    // Hot and not Done since the last reset.
    UPROPERTY()
    float32 Seconds = 0.0f;

    // Landings of the live steak after at least utils_searing::k_FlipAirSeconds apart from the pan.
    UPROPERTY()
    int32 Flips = 0;

    UPROPERTY()
    int32 Losses = 0;
}

// Written only by the Searing processors (and Add). The station SM and the operator only issue requests.
struct FMars_Fragment_Searing
{
    UPROPERTY()
    EMars_Searing_Phase Phase = EMars_Searing_Phase::NoSteak;

    UPROPERTY()
    FMars_Searing_SteakState Steak;

    UPROPERTY()
    TArray<FMars_Searing_LostSteak> LostSteaks;

    UPROPERTY()
    FMars_Searing_Tally Tally;

    UPROPERTY()
    EMars_Searing_Heat Heat = EMars_Searing_Heat::Cold;

    UPROPERTY()
    EMars_Searing_Sizzle Sizzle = EMars_Searing_Sizzle::Quiet;

    // The last tenth OnSearProgress reported for the face on the pan; -1 forces the next report.
    UPROPERTY()
    int32 LastProgressStep = -1;
}

// On the steak body's entity: the Searing it belongs to (the landing handler resolves the kernel through it).
// Written only by the kernel when it spawns a steak.
struct FMars_Fragment_Searing_SteakLink
{
    UPROPERTY()
    FCk_Handle_Searing Searing;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// A SetHeat that changed it; a Reset that found it Hot.
delegate void FMars_Delegate_Searing_OnHeatChanged(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat);
event void FMars_Delegate_Searing_OnHeatChanged_MC(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat);

// A fresh steak entity exists (its body requested, not yet added): the placing script adds its visuals here.
delegate void FMars_Delegate_Searing_OnSteakSpawned(FCk_Handle_Searing InSearing, FCk_Handle InSteak);
event void FMars_Delegate_Searing_OnSteakSpawned_MC(FCk_Handle_Searing InSearing, FCk_Handle InSteak);

// OnPan <-> Airborne edges (the toss and the landing).
delegate void FMars_Delegate_Searing_OnPanContactChanged(FCk_Handle_Searing InSearing, EMars_Searing_Phase InPhase);
event void FMars_Delegate_Searing_OnPanContactChanged_MC(FCk_Handle_Searing InSearing, EMars_Searing_Phase InPhase);

// Quantized at tenths, for the face on the pan.
delegate void FMars_Delegate_Searing_OnSearProgress(FCk_Handle_Searing InSearing, EMars_Searing_Face InFace, float32 InAlpha);
event void FMars_Delegate_Searing_OnSearProgress_MC(FCk_Handle_Searing InSearing, EMars_Searing_Face InFace, float32 InAlpha);

delegate void FMars_Delegate_Searing_OnFaceSeared(FCk_Handle_Searing InSearing, EMars_Searing_Face InFace);
event void FMars_Delegate_Searing_OnFaceSeared_MC(FCk_Handle_Searing InSearing, EMars_Searing_Face InFace);

// Edge only: Sizzling while Hot, on the pan and the face on the pan is not yet seared.
delegate void FMars_Delegate_Searing_OnSizzleChanged(FCk_Handle_Searing InSearing, EMars_Searing_Sizzle InSizzle);
event void FMars_Delegate_Searing_OnSizzleChanged_MC(FCk_Handle_Searing InSearing, EMars_Searing_Sizzle InSizzle);

// The steak left the pan; InSteak lingers and is destroyed later.
delegate void FMars_Delegate_Searing_OnSteakLost(FCk_Handle_Searing InSearing, FCk_Handle InSteak);
event void FMars_Delegate_Searing_OnSteakLost_MC(FCk_Handle_Searing InSearing, FCk_Handle InSteak);

delegate void FMars_Delegate_Searing_OnCompleted(FCk_Handle_Searing InSearing, FMars_Searing_Tally InTally);
event void FMars_Delegate_Searing_OnCompleted_MC(FCk_Handle_Searing InSearing, FMars_Searing_Tally InTally);

struct FMars_Fragment_Searing_Signals
{
    FMars_Delegate_Searing_OnHeatChanged_MC OnHeatChanged;
    FMars_Delegate_Searing_OnSteakSpawned_MC OnSteakSpawned;
    FMars_Delegate_Searing_OnPanContactChanged_MC OnPanContactChanged;
    FMars_Delegate_Searing_OnSearProgress_MC OnSearProgress;
    FMars_Delegate_Searing_OnFaceSeared_MC OnFaceSeared;
    FMars_Delegate_Searing_OnSizzleChanged_MC OnSizzleChanged;
    FMars_Delegate_Searing_OnSteakLost_MC OnSteakLost;
    FMars_Delegate_Searing_OnCompleted_MC OnCompleted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// One drained InputIntents look delta (degrees; X yaw right+, Y pitch down+). Forwarded to the pan while hot.
struct FMars_Request_Searing_Look
{
    UPROPERTY()
    FVector LookDelta = FVector::ZeroVector;

    FMars_Request_Searing_Look() {}

    FMars_Request_Searing_Look(FVector InLookDelta)
    {
        LookDelta = InLookDelta;
    }
}

// Last wins within a drain.
struct FMars_Request_Searing_SetHeat
{
    UPROPERTY()
    EMars_Searing_Heat Heat = EMars_Searing_Heat::Cold;

    FMars_Request_Searing_SetHeat() {}

    FMars_Request_Searing_SetHeat(EMars_Searing_Heat InHeat)
    {
        Heat = InHeat;
    }
}

// Destroys every steak, resets the pan (level, idle), chills it and zeroes the tally; a fresh steak appears next frame.
// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Searing_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Searing_Reset() {}
}

// Applied Reset -> SetHeat -> Look, so a reset and the first heat and looks of a new session can share a drain.
struct FMars_Fragment_Searing_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Searing_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Searing_SetHeat> SetHeatRequests;

    UPROPERTY()
    TArray<FMars_Request_Searing_Look> LookRequests;
}
