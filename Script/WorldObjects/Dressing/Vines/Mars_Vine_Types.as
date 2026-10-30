// Shared types of the vine and root generator (AMars_Vine, AMars_HeroRoot): layouts, endings, the solved-path cache and
// the query structs the solver passes between its primitives. The authoring contract is VINES.md beside this file.
//
// Spaces: the solver traces in world space and stores every path point and normal actor-local, so a vine moves rigidly
// with its actor and a cached solve survives a move while Freeze is on. A zero normal marks a free (hanging) point.

enum EMars_VineLayout
{
    // The Guide spline, clinging to surfaces within the profile's ClingRadius and free beyond it.
    Spline,
    // A surface walk up a wall or pipe from the nearest surface to the actor.
    Creep,
    // One strand hanging from the ceiling above the actor.
    Drop,
    // Strands that wrap a lip in front of the actor (+X outward, local Y along the edge) and hang below it.
    Curtain,
    // A coil round a pier or pipe about the actor's local Z axis.
    Wrap,
    // Clumped strands hanging from the underside above a disc round the actor.
    Patch
}

// What a free end does: reach the floor and creep along it (roots fork into fingers), or stop in the air above it.
enum EMars_VineEnd
{
    Ground,
    Air
}

enum EMars_VineCollision
{
    // The profile's Rendering.Collision.
    FromProfile,
    Off,
    On
}

enum EMars_VinePathKind
{
    // A main stem or root.
    Stem,
    // A side shoot of an ivy stem.
    Branch,
    // A short curled tip, no traces.
    Tendril,
    // A root finger: a ground or ceiling flare.
    Finger,
    // A stemless card (moss strand, rootlet, cobweb): two points, top and bottom.
    Strand
}

enum EMars_VineStemRender
{
    // No stem: the profile draws strand cards only.
    None,
    // One instanced chord per resampled step (thin stems).
    Instanced,
    // One spline-mesh segment per resampled step (roots).
    SplineMesh
}

enum EMars_VinePreset
{
    Ivy,
    GiantRoot,
    ThinRoot,
    HangingMoss,
    Rootlets,
    Cobweb
}

// One random stream per purpose, so changing one knob (leaf density) never reshuffles another (the path).
enum EMars_VineStream
{
    Strand,
    Len,
    Meander,
    Branch,
    Leaf,
    Card,
    Knot,
    Finger,
    Tint,
    Roll,
    Litter
}

// The layout knobs of one vine.
struct FMars_Vine_Shape
{
    // Creep: the climb; Drop / Patch: an Air strand's length cap (0 = the profile's).
    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 LengthCm = 0.0f;

    // Curtain: the edge length the strands spread over.
    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 WidthCm = 160.0f;

    // Curtain strands; Creep and Wrap stems (1 to 3). 0 = the profile's range.
    UPROPERTY(meta = (ClampMin = "0"))
    int32 StrandCount = 0;

    // Wrap: full turns round the pier.
    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 Turns = 2.0f;

    // Wrap / Creep: the height climbed (0 = traced to the ceiling, capped at 600 cm; Creep: 400 cm).
    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 HeightCm = 0.0f;

    // Patch: the disc the strands hang over.
    UPROPERTY(meta = (ClampMin = "0.0"))
    float32 PatchRadiusCm = 90.0f;

    // The share of free ends that reach the floor; below 0 it follows End (Ground 1, Air 0).
    UPROPERTY(meta = (ClampMax = "1.0"))
    float32 GroundShare = -1.0f;
}

// One solved polyline, actor-local.
struct FMars_Vine_Path
{
    UPROPERTY()
    TArray<FVector> Points;

    // Per point: the surface normal it clings to, or zero where it hangs free.
    UPROPERTY()
    TArray<FVector> Normals;

    UPROPERTY()
    EMars_VinePathKind Kind = EMars_VinePathKind::Stem;

    // Radius at the first and the last point (cm); strands: the card width factor in StartCm.
    UPROPERTY()
    FVector2D RadiusCm = FVector2D(1.0, 1.0);

    // The free end reached the floor.
    UPROPERTY()
    bool Grounded = false;

    // The strand / stem this path belongs to (twin strands share it), or its parent path for branches and fingers.
    UPROPERTY()
    int32 Group = 0;
}

// The cached solve: rebuilt only when the inputs hash changes or a Reattach is asked for.
struct FMars_Vine_Solved
{
    UPROPERTY()
    int32 InputHash = 0;

    UPROPERTY()
    TArray<FMars_Vine_Path> Paths;

    UPROPERTY()
    int32 TraceCount = 0;

    // Ground strands that found no floor within MaxDropCm and ended in the air instead.
    UPROPERTY()
    int32 NoFloorCount = 0;

    UPROPERTY()
    int32 EffectiveSeed = 0;

    UPROPERTY()
    bool Valid = false;
}

struct FMars_Vine_SurfaceHit
{
    bool Hit = false;
    FVector P;
    FVector N;
    float Distance = 0.0;
}

struct FMars_Vine_ProbeQuery
{
    FVector P;
    // Zero: the nearest of 14 rays; else one ray along -HintN through P.
    FVector HintN;
    float RadiusCm = 60.0;

    FMars_Vine_ProbeQuery() {}

    FMars_Vine_ProbeQuery(FVector InP, FVector InHintN, float InRadiusCm)
    {
        P = InP;
        HintN = InHintN;
        RadiusCm = InRadiusCm;
    }
}

// How a creep steers: toward Bias (projected onto the surface) with BiasWeight, plus a seeded meander.
struct FMars_Vine_CreepSteer
{
    FVector Bias;
    float BiasWeight = 0.0;
    float MeanderDeg = 0.0;
    // Stop when the walk wraps onto a downward-facing surface (curtains hang from a ledge bottom instead).
    bool StopOnUnderside = false;
}

struct FMars_Vine_CreepQuery
{
    // Start point on the surface (world) and its normal.
    FMars_Vine_SurfaceHit Start;
    FVector Dir;
    float LengthCm = 100.0;
    float StepCm = 10.0;
    // Centreline height above the surface (radius + gap; negative sinks a root in).
    float LiftCm = 1.0;
    FMars_Vine_CreepSteer Steer;
}

// What a creep did: where it ended and whether it left the surface there.
struct FMars_Vine_CreepResult
{
    FMars_Vine_SurfaceHit Last;
    FVector Dir;
    bool LeftSurface = false;
    float WalkedCm = 0.0;
}

// A free end to finish, world space.
struct FMars_Vine_EndQuery
{
    FVector From;
    // Radius at the end (cm).
    float RadiusCm = 1.0;
    // Air: the length frac / clearance stream index (curtains pass their correlated fraction, < 0 = draw one).
    float LengthFrac = -1.0;
    // The cap on an air strand (cm, 0 = none).
    float CapCm = 0.0;
}

// The worst-case work a request can cost, checked against the budgets before a solve (the editor's 1 s script limit).
struct FMars_Vine_Budget
{
    int32 Traces = 0;
    int32 Segments = 0;
    int32 Leaves = 0;
    int32 Cards = 0;
    int32 Chords = 0;
}

struct FMars_Vine_Report
{
    int32 Traces = 0;
    int32 Paths = 0;
    int32 Segments = 0;
    int32 Leaves = 0;
    int32 Cards = 0;
    int32 Chords = 0;
    bool Cached = false;

    FString ToString() const
    {
        const FString How = Cached ? "cached" : "solved";
        return f"{Traces} traces, {Paths} paths, {Segments} segments, {Chords} chords, {Leaves} leaves, {Cards} cards, {How}";
    }
}

namespace utils_vine
{
    const FName EmittedTag = n"Mars.Vine.Emitted";
    const FName JoltNoBakeTag = n"Ck.Jolt.NoBake";

    // Per-actor budgets (VINES.md): the editor stops a construction script after 1 s.
    const int32 k_MaxTraces = 3000;
    const int32 k_MaxSegments = 64;
    const int32 k_MaxLeaves = 4000;
    const int32 k_MaxCards = 1500;
    const int32 k_MaxChords = 3000;
}
