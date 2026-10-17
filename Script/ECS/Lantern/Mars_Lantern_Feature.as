// A lantern: a tallow flame behind a shutter. While the shutter is open and tallow is left it burns, one measure every
// SecondsPerMeasure; the last GutterSeconds of the last measure gutter, then the flame is spent until it is refuelled. A
// shuttered lantern neither burns nor lights, and neither does a stowed one (in a hotbar slot that is not selected: the
// Stowed pool), whatever its shutter. The kernel owns the fuel clock and the light radius (the gameplay sphere
// whatever reads the light uses); it knows no light component, mesh or colour (UMars_Lantern_EntityScript draws it).

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_LanternHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Lantern";
    RequiredFragments.Add(FMars_Feature_Lantern);
    Description = "A tallow flame behind a shutter: burns measures of tallow while open, gutters on the last, and lights a radius that follows where it is carried";
}
struct FMars_Feature_Lantern {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Lantern_Shutter
{
    Open,
    Shuttered
}

enum EMars_Lantern_Flame
{
    Steady,
    // The last GutterSeconds of the last measure: the warning before it goes out.
    Guttering,
    // No tallow left; an open shutter shows no flame.
    Spent
}

// Where the flame is (Get_LightPool): in a hand, stowed away in a carrier's hotbar (it lights nothing and burns nothing),
// or lying, hung or packed on a backpack.
enum EMars_Lantern_Pool
{
    Held,
    Stowed,
    World
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_lantern
{
    // Resolved by name: the accessors exist only once a restarted editor has registered the tags.
    FGameplayTag Get_LightProbeName()
    {
        return GameplayTags::ResolveGameplayTag(n"Probe.Mars.Light");
    }

    // A lantern Carried on this point is hung (a sconce, a pack hook) and lights its World radius.
    FGameplayTag Get_HookPoint()
    {
        return GameplayTags::ResolveGameplayTag(n"AttachPoint.Mars.Hook");
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The lit radius by where the lantern is: in a hand, or lying, hung or on a backpack. A stowed lantern lights nothing.
struct FMars_Lantern_Radius
{
    UPROPERTY()
    float32 Held = 700.0f;

    UPROPERTY()
    float32 World = 900.0f;
}

struct FMars_Lantern_Spec
{
    UPROPERTY()
    int32 Measures = 4;

    UPROPERTY()
    float32 SecondsPerMeasure = 60.0f;

    UPROPERTY()
    float32 GutterSeconds = 10.0f;

    // Unset: full.
    UPROPERTY()
    TOptional<int32> StartMeasures;

    UPROPERTY()
    EMars_Lantern_Shutter StartShutter = EMars_Lantern_Shutter::Shuttered;

    UPROPERTY()
    FMars_Lantern_Radius Radius;
}

// At least one measure of positive length, a gutter no longer than a measure, StartMeasures in 0..Measures, positive
// radii. Reports the first failing rule.
mixin FMars_Validation Validate(const FMars_Lantern_Spec& Self)
{
    if (Self.Measures < 1)
    { return FMars_Validation(f"Measures [{Self.Measures}] must be at least 1"); }

    if (Self.SecondsPerMeasure <= 0.0f)
    { return FMars_Validation(f"SecondsPerMeasure [{Self.SecondsPerMeasure}] must be positive"); }

    if (Self.GutterSeconds < 0.0f || Self.GutterSeconds > Self.SecondsPerMeasure)
    { return FMars_Validation(f"GutterSeconds [{Self.GutterSeconds}] must be in 0..SecondsPerMeasure [{Self.SecondsPerMeasure}]"); }

    if (Self.StartMeasures.IsSet() && (Self.StartMeasures.GetValue() < 0 || Self.StartMeasures.GetValue() > Self.Measures))
    { return FMars_Validation(f"StartMeasures [{Self.StartMeasures.GetValue()}] must be in 0..Measures [{Self.Measures}]"); }

    if (Self.Radius.Held <= 0.0f || Self.Radius.World <= 0.0f)
    { return FMars_Validation(f"every Radius must be positive (Held [{Self.Radius.Held}], World [{Self.Radius.World}])"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Lantern_Params
{
    UPROPERTY()
    int32 Measures = 4;

    UPROPERTY()
    float32 SecondsPerMeasure = 60.0f;

    UPROPERTY()
    float32 GutterSeconds = 10.0f;

    UPROPERTY()
    FMars_Lantern_Radius Radius;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the Lantern processors and utils_lantern::Add.
struct FMars_Fragment_Lantern
{
    UPROPERTY()
    EMars_Lantern_Shutter Shutter = EMars_Lantern_Shutter::Shuttered;

    // Measures still unburnt, Measures..0, the one burning included.
    UPROPERTY()
    int32 MeasuresLeft = 0;

    // Seconds the burning measure has burnt.
    UPROPERTY()
    float32 MeasureElapsed = 0.0f;

    UPROPERTY()
    EMars_Lantern_Flame Flame = EMars_Lantern_Flame::Spent;
}

// Present while the shutter is open and tallow is left; gates UMars_Processor_Lantern_Burn (which also skips a stowed
// lantern).
struct FMars_Tag_Lantern_Burning {}

// The light sphere whatever reads the light overlaps: one Probe.Mars.Light probe per lit pool radius (Held, World) on the
// lantern's root, created disabled by utils_lantern::Add (a probe cannot be resized); UMars_Processor_Lantern_LightProbe
// keeps exactly the probe of Get_LightPool enabled while lit and none while dark or stowed. Absent on a lantern whose
// entity has no transform.
struct FMars_Fragment_Lantern_LightProbes
{
    UPROPERTY()
    FCk_Handle_Probe Held;

    UPROPERTY()
    FCk_Handle_Probe World;

    // The pool whose probe is enabled; unset while every probe is disabled. Written only by the LightProbe processor.
    UPROPERTY()
    TOptional<EMars_Lantern_Pool> Shown;
}

// What the signals compare across one processor pass.
struct FMars_Lantern_Reading
{
    UPROPERTY()
    bool IsLit = false;

    UPROPERTY()
    EMars_Lantern_Flame Flame = EMars_Lantern_Flame::Spent;

    UPROPERTY()
    int32 MeasuresLeft = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Lantern_OnLitChanged(FCk_Handle_Lantern InLantern, bool InIsLit);
event void FMars_Delegate_Lantern_OnLitChanged_MC(FCk_Handle_Lantern InLantern, bool InIsLit);

delegate void FMars_Delegate_Lantern_OnFlameChanged(FCk_Handle_Lantern InLantern, EMars_Lantern_Flame InFlame);
event void FMars_Delegate_Lantern_OnFlameChanged_MC(FCk_Handle_Lantern InLantern, EMars_Lantern_Flame InFlame);

delegate void FMars_Delegate_Lantern_OnMeasuresChanged(FCk_Handle_Lantern InLantern, int32 InMeasuresLeft);
event void FMars_Delegate_Lantern_OnMeasuresChanged_MC(FCk_Handle_Lantern InLantern, int32 InMeasuresLeft);

struct FMars_Fragment_Lantern_Signals
{
    FMars_Delegate_Lantern_OnLitChanged_MC OnLitChanged;
    FMars_Delegate_Lantern_OnFlameChanged_MC OnFlameChanged;
    FMars_Delegate_Lantern_OnMeasuresChanged_MC OnMeasuresChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Absolute: the latest wins.
struct FMars_Request_Lantern_SetShutter
{
    UPROPERTY()
    EMars_Lantern_Shutter Shutter = EMars_Lantern_Shutter::Shuttered;

    FMars_Request_Lantern_SetShutter() {}

    FMars_Request_Lantern_SetShutter(EMars_Lantern_Shutter InShutter)
    {
        Shutter = InShutter;
    }
}

// Adds Measures, capped at full. A spent lantern starts its new measure from the beginning.
struct FMars_Request_Lantern_Refuel
{
    UPROPERTY()
    int32 Measures = 1;

    FMars_Request_Lantern_Refuel() {}

    FMars_Request_Lantern_Refuel(int32 InMeasures)
    {
        Measures = InMeasures;
    }
}

// Drain order: every refuel, then the latest shutter request (so a refuel and an open in one frame light it).
struct FMars_Fragment_Lantern_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Lantern_Refuel> RefuelRequests;

    UPROPERTY()
    TArray<FMars_Request_Lantern_SetShutter> SetShutterRequests;
}
