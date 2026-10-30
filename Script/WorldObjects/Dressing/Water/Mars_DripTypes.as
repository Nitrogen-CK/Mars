// Shared types of the Mars drip / puddle / wet-surface dressing (Tools/Environment/DRIPS_PLAN.md). Plain AActor dressing,
// visual composition only (like Mars_HangingChain): no ECS, no PCG types.
//
// The custom-data slot enums are the contract with the materials (Shaders/Water/MarsWet.ush reads them by index) and
// with the PCG packers (Tools/Blender/mars_water/water_spec.py); check_drip_parity.py diffs all three orders.

// How a strand behaves (custom data slot Mode).
enum EMars_DripMode
{
    Drops,
    DropsWithThread,
    Stream,
    HangingBead,
    SittingBead
}

// What a strand lands on (custom data slot Surface on the drop cards).
enum EMars_DripSurface
{
    Floor,
    Water,
    Dry,
    Air
}

// The six cards of one strand: four falling-drop / splash slots, the swelling bead, the thread.
enum EMars_DripSlot
{
    Drop0,
    Drop1,
    Drop2,
    Drop3,
    Bead,
    Thread
}

// Per-instance custom data of the drop cards (Drops ISM, 8 floats).
enum EMars_DripCardData
{
    Length,
    Rate,
    Seed,
    Jitter,
    Mode,
    Slot,
    DropScale,
    Surface,
    Count
}

// Per-instance custom data of the ring decals (Rings ISM, 6 floats): slots 0..4 equal the strand's bit for bit.
enum EMars_DripRingData
{
    Length,
    Rate,
    Seed,
    Jitter,
    Mode,
    RingAmp,
    Count
}

// Per-instance custom data of the two puddle layers (PuddleWet and PuddleGloss ISMs, identical values).
enum EMars_PuddleData
{
    Seed,
    Wetness,
    RainRate,
    Aspect,
    Count
}

// Serialized custom primitive data of the still-water surface.
enum EMars_StillWaterData
{
    SizeX,
    SizeY,
    Seed,
    Murk,
    RainRate,
    Count
}

enum EMars_DripLayout
{
    Single,
    Line,
    Cluster
}

enum EMars_DripPreset
{
    CisternDrip,
    VaultLine,
    PipeJoint,
    PipeTrickle,
    OssuarySeep,
    Beads,
    Custom
}

enum EMars_DripTraceMode
{
    // Re-trace on every construction-script run; a miss never overwrites a cached hit.
    Live,
    // Reuse the cached strands and never trace (geometry being edited, unloaded World Partition cells).
    Locked
}

enum EMars_DripTraceState
{
    Hit,
    MissedKeptCached,
    MissedNoCache,
    Air,
    Locked
}

struct FMars_DripTiming
{
    // Drops per second; each strand rolls a log-uniform rate between the two.
    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 RateMin = 0.25f;

    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 RateMax = 0.9f;

    // 0 = a metronome, 1 = irregular releases and skipped drops.
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 Jitter = 0.6f;
}

struct FMars_DripLook
{
    UPROPERTY()
    EMars_DripMode Mode = EMars_DripMode::Drops;

    UPROPERTY(meta = (ClampMin = "0.5", ClampMax = "2.0"))
    float32 DropScale = 1.0f;

    // Unset: Droplet_Mars_MI.
    UPROPERTY()
    UMaterialInterface DropMaterial;
}

struct FMars_DripImpact
{
    // Puddles under strands that land on a floor.
    UPROPERTY()
    bool Puddles = true;

    UPROPERTY(meta = (ClampMin = "5.0"))
    float32 SizeMin = 40.0f;

    UPROPERTY(meta = (ClampMin = "5.0"))
    float32 SizeMax = 110.0f;

    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 Wetness = 0.85f;

    // cm above the floor the puddle quads hover (raised flagstones poking through stay dry).
    UPROPERTY()
    float32 WaterLevelOffset = 1.5f;

    // Ring strength (0 = no rings).
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "2.0"))
    float32 RingAmp = 1.0f;

    // Ambient rain rings per m^2 per second on the puddles.
    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 RainRate = 0.0f;
}

struct FMars_DripTrace
{
    // Trace up from each source point and hang it under the ceiling (soffits, vault ribs).
    UPROPERTY()
    bool AttachUp = true;

    UPROPERTY()
    float32 MaxRise = 800.0f;

    UPROPERTY()
    float32 MaxLength = 1500.0f;

    UPROPERTY()
    float32 MinLength = 20.0f;

    // Drip into darkness: no impact, the drops fade over the last quarter of AirLength.
    UPROPERTY()
    bool Air = false;

    UPROPERTY()
    float32 AirLength = 600.0f;

    UPROPERTY()
    EMars_DripTraceMode Mode = EMars_DripTraceMode::Live;
}

struct FMars_DripStreak
{
    // Project a damp / rust streak down the wall behind the leak (actor +X points out of the wall).
    UPROPERTY()
    bool OnWall = false;

    UPROPERTY()
    float32 WidthCm = 30.0f;

    UPROPERTY()
    float32 MaxLengthCm = 600.0f;

    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 Dampness = 0.45f;

    // cm/s the film beads crawl down (0 = a still damp patch).
    UPROPERTY()
    float32 Flow = 30.0f;

    // Rust / calcite gathered under the source (0..1; the tint lives in the decal material).
    UPROPERTY(meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 Mineral = 0.0f;
}

struct FMars_DripStrandHit
{
    UPROPERTY()
    FVector Point;

    UPROPERTY()
    FVector Normal = FVector::UpVector;

    UPROPERTY()
    EMars_DripSurface Surface = EMars_DripSurface::Floor;
}

// One strand as last traced (world space). Kept on the leak so a later miss can keep it.
struct FMars_DripStrandRecord
{
    UPROPERTY()
    FVector Source;

    UPROPERTY()
    FMars_DripStrandHit Impact;

    // cm, < 0 = Air.
    UPROPERTY()
    float32 Length = 0.0f;

    UPROPERTY()
    float32 Rate = 0.0f;

    UPROPERTY()
    float32 Seed = 0.0f;

    UPROPERTY()
    EMars_DripTraceState State = EMars_DripTraceState::Hit;
}

// Where a wet streak goes: from Origin, along -Out to the wall, then down the wall (AMars_DripLeak, AMars_WetStreak).
struct FMars_DripStreakPlacement
{
    UPROPERTY()
    FVector Origin;

    // Points out of the wall (the placing actor's +X).
    UPROPERTY()
    FVector Out = FVector::ForwardVector;

    UPROPERTY()
    FMars_DripStreak Spec;

    UPROPERTY()
    float32 Seed = 0.0f;
}
