// A flame: bare (Open) or behind glass (Enclosed), lit or snuffed. A lit flame with measured fuel burns one measure every
// SecondsPerMeasure; the last GutterSeconds of the last measure gutter, then it is spent until refuelled (or for good when
// its fuel is not refuelable). A flame with no fuel block burns forever once lit. Its light is a pool that follows where it
// is: in a hand (Held), stowed on its carrier's carry point (Stowed), or anywhere else (World); stowing a flame that
// Snuffs puts it out, one that StaysLit keeps burning at its Stowed radius. Only an Open lit flame passes fire, and only
// to an Open flame. A MechanismSource on the flame's own entity is asserted while it is lit. The kernel owns the fuel
// clock, the ignite rules and the light radius (the gameplay sphere whatever reads the light overlaps); it knows no
// light component, mesh, colour or words (the entity scripts draw it, the control layer words it).

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_FlameHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Flame";
    RequiredFragments.Add(FMars_Feature_Flame);
    Description = "A flame, bare or behind glass: lit or snuffed, burning measures of fuel or none, lighting a pool that follows where it is carried";
}
struct FMars_Feature_Flame {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// What the flame is set to; a Lit flame burns only while it has fuel.
enum EMars_Flame_Ignition
{
    Lit,
    Snuffed
}

enum EMars_Flame_Condition
{
    Steady,
    // The last GutterSeconds of the last measure: the warning before it goes out.
    Guttering,
    // Measured fuel only: none left; a Lit flame shows nothing.
    Spent
}

// Open passes fire both ways; Enclosed neither.
enum EMars_Flame_Enclosure
{
    Open,
    Enclosed
}

// SelfLighting: a Lit request needs no Source.
enum EMars_Flame_Lighting
{
    SelfLighting,
    NeedsAFlame
}

// What being stowed on its own carry point (the belt) does to a lit flame.
enum EMars_Flame_OnStow
{
    StaysLit,
    Snuffs
}

enum EMars_Flame_Refuel
{
    Refuelable,
    NotRefuelable
}

// Who lights a flame: itself (a shutter, a strike) or another flame it is held to.
enum EMars_Flame_IgnitionOrigin
{
    ByItself,
    FromAFlame
}

// Where the flame is (Get_LightPool), by its world item's mount: in a hand, stowed on its carrier's carry point, or lying,
// hung or packed. A flame without a world item is World.
enum EMars_Flame_Pool
{
    Held,
    Stowed,
    World
}

// What a focuser's held flame and this flame can do for each other (Get_ActionFor).
enum EMars_Flame_Action
{
    // The focuser's held flame lights this one.
    Light,
    // This flame lights the focuser's held (unlit, not spent) flame.
    TakeLight,
    // This flame is unlit; the focuser holds nothing that passes fire.
    Blocked_NeedsAFlame,
    // The focuser holds a flame that cannot pass fire by nature (glass).
    Blocked_Enclosed,
    // The focuser's held flame is spent: nothing to light, nothing to light it with.
    Blocked_Spent,
    // This flame is lit and the focuser holds nothing it could light.
    None
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Flame_Fuel
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
    EMars_Flame_Refuel Refuel = EMars_Flame_Refuel::Refuelable;
}

// At least one measure of positive length, a gutter no longer than a measure, StartMeasures in 0..Measures. Reports the
// first failing rule.
mixin FMars_Validation Validate(const FMars_Flame_Fuel& Self)
{
    if (Self.Measures < 1)
    { return FMars_Validation(f"Measures [{Self.Measures}] must be at least 1"); }

    if (Self.SecondsPerMeasure <= 0.0f)
    { return FMars_Validation(f"SecondsPerMeasure [{Self.SecondsPerMeasure}] must be positive"); }

    if (Self.GutterSeconds < 0.0f || Self.GutterSeconds > Self.SecondsPerMeasure)
    { return FMars_Validation(f"GutterSeconds [{Self.GutterSeconds}] must be in 0..SecondsPerMeasure [{Self.SecondsPerMeasure}]"); }

    if (Self.StartMeasures.IsSet() && (Self.StartMeasures.GetValue() < 0 || Self.StartMeasures.GetValue() > Self.Measures))
    { return FMars_Validation(f"StartMeasures [{Self.StartMeasures.GetValue()}] must be in 0..Measures [{Self.Measures}]"); }

    return FMars_Validation();
}

// The lit radius by pool.
struct FMars_Flame_Radius
{
    UPROPERTY()
    float32 Held = 700.0f;

    // Read only while OnStow is StaysLit.
    UPROPERTY()
    float32 Stowed = 350.0f;

    UPROPERTY()
    float32 World = 900.0f;
}

// The defaults are a bare flame; a lantern names its glass.
struct FMars_Flame_Spec
{
    // Unset: burns forever once lit.
    UPROPERTY()
    TOptional<FMars_Flame_Fuel> Fuel;

    UPROPERTY()
    EMars_Flame_Ignition StartIgnition = EMars_Flame_Ignition::Snuffed;

    UPROPERTY()
    EMars_Flame_Enclosure Enclosure = EMars_Flame_Enclosure::Open;

    UPROPERTY()
    EMars_Flame_Lighting Lighting = EMars_Flame_Lighting::SelfLighting;

    UPROPERTY()
    EMars_Flame_OnStow OnStow = EMars_Flame_OnStow::Snuffs;

    UPROPERTY()
    FMars_Flame_Radius Radius;

    // Optional: the interactable whose Use row lights this flame or takes light from it (fixtures). Invalid: none.
    UPROPERTY()
    FCk_Handle_Interactable Interactable;
}

// The fuel's rules when it has fuel, positive Held and World radii, a positive Stowed radius when it stays lit stowed, and
// no unrefuelable fuel that starts empty (born spent for good). A NeedsAFlame flame may start Lit (data lights a brazier).
// Reports the first failing rule.
mixin FMars_Validation Validate(const FMars_Flame_Spec& Self)
{
    if (Self.Fuel.IsSet())
    {
        const auto FuelValidation = Self.Fuel.GetValue().Validate();
        if (FuelValidation.IsValid() == false)
        { return FuelValidation; }
    }

    if (Self.Radius.Held <= 0.0f || Self.Radius.World <= 0.0f)
    { return FMars_Validation(f"every Radius must be positive (Held [{Self.Radius.Held}], World [{Self.Radius.World}])"); }

    if (Self.OnStow == EMars_Flame_OnStow::StaysLit && Self.Radius.Stowed <= 0.0f)
    { return FMars_Validation(f"Radius.Stowed [{Self.Radius.Stowed}] must be positive for a flame that stays lit when stowed"); }

    if (Self.Fuel.IsSet() && Self.Fuel.GetValue().Refuel == EMars_Flame_Refuel::NotRefuelable
        && Self.Fuel.GetValue().StartMeasures.IsSet() && Self.Fuel.GetValue().StartMeasures.GetValue() == 0)
    { return FMars_Validation("Refuel [NotRefuelable] with StartMeasures [0] is born spent for good"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// The retained spec.
struct FMars_Fragment_Flame_Params
{
    // Unset: burns forever once lit.
    UPROPERTY()
    TOptional<FMars_Flame_Fuel> Fuel;

    UPROPERTY()
    EMars_Flame_Enclosure Enclosure = EMars_Flame_Enclosure::Open;

    UPROPERTY()
    EMars_Flame_Lighting Lighting = EMars_Flame_Lighting::SelfLighting;

    UPROPERTY()
    EMars_Flame_OnStow OnStow = EMars_Flame_OnStow::Snuffs;

    UPROPERTY()
    FMars_Flame_Radius Radius;

    // Invalid: none.
    UPROPERTY()
    FCk_Handle_Interactable Interactable;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the Flame processors and utils_flame::Add.
struct FMars_Fragment_Flame
{
    UPROPERTY()
    EMars_Flame_Ignition Ignition = EMars_Flame_Ignition::Snuffed;

    // Measures still unburnt, Measures..0, the one burning included. 0 and unread while Fuel is unset.
    UPROPERTY()
    int32 MeasuresLeft = 0;

    // Seconds the burning measure has burnt.
    UPROPERTY()
    float32 MeasureElapsed = 0.0f;

    UPROPERTY()
    EMars_Flame_Condition Condition = EMars_Flame_Condition::Steady;

    // The pool of the last Pool pass; unset before the first. The Snuffs rule fires on the edge into Stowed.
    UPROPERTY()
    TOptional<EMars_Flame_Pool> LastPool;

    // The same-entity MechanismSource's last output; unset before the first Source pass or without a source.
    UPROPERTY()
    TOptional<EMars_MechanismSource_Output> LastSourceOutput;
}

// Present while Lit with fuel left (or unlimited fuel); gates UMars_Processor_Flame_Burn.
struct FMars_Tag_Flame_Burning {}

// The light sphere whatever reads the light overlaps: one disabled Probe.Mars.Light probe per pool the flame can light on
// its root (a probe cannot be resized): Held and World, and Stowed only when it stays lit stowed. UMars_Processor_Flame_Pool
// keeps exactly the probe of Get_LightPool enabled while lit and none while dark. Absent on a flame whose entity has no
// transform.
struct FMars_Fragment_Flame_LightProbes
{
    UPROPERTY()
    FCk_Handle_Probe Held;

    // Invalid unless the flame stays lit when stowed.
    UPROPERTY()
    FCk_Handle_Probe Stowed;

    UPROPERTY()
    FCk_Handle_Probe World;

    // The pool whose probe is enabled; unset while every probe is disabled. Written only by the Pool processor.
    UPROPERTY()
    TOptional<EMars_Flame_Pool> Shown;
}

// What the signals compare across one processor pass.
struct FMars_Flame_Reading
{
    UPROPERTY()
    bool IsLit = false;

    UPROPERTY()
    EMars_Flame_Condition Condition = EMars_Flame_Condition::Steady;

    UPROPERTY()
    int32 MeasuresLeft = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Flame_OnLitChanged(FCk_Handle_Flame InFlame, bool InIsLit);
event void FMars_Delegate_Flame_OnLitChanged_MC(FCk_Handle_Flame InFlame, bool InIsLit);

delegate void FMars_Delegate_Flame_OnConditionChanged(FCk_Handle_Flame InFlame, EMars_Flame_Condition InCondition);
event void FMars_Delegate_Flame_OnConditionChanged_MC(FCk_Handle_Flame InFlame, EMars_Flame_Condition InCondition);

delegate void FMars_Delegate_Flame_OnMeasuresChanged(FCk_Handle_Flame InFlame, int32 InMeasuresLeft);
event void FMars_Delegate_Flame_OnMeasuresChanged_MC(FCk_Handle_Flame InFlame, int32 InMeasuresLeft);

struct FMars_Fragment_Flame_Signals
{
    FMars_Delegate_Flame_OnLitChanged_MC OnLitChanged;
    FMars_Delegate_Flame_OnConditionChanged_MC OnConditionChanged;
    FMars_Delegate_Flame_OnMeasuresChanged_MC OnMeasuresChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Absolute: the latest wins. Lit on a NeedsAFlame flame needs a Source (a lit Open flame) and Self Open; Lit from a Source
// on a SelfLighting flame is an ignite too, under the same Source rules. A Lit from a flame that is gone or went out this
// frame is dropped quietly.
struct FMars_Request_Flame_SetIgnition
{
    UPROPERTY()
    EMars_Flame_Ignition Ignition = EMars_Flame_Ignition::Snuffed;

    UPROPERTY()
    EMars_Flame_IgnitionOrigin Origin = EMars_Flame_IgnitionOrigin::ByItself;

    // Read only when Origin is FromAFlame.
    UPROPERTY()
    FCk_Handle_Flame Source;

    FMars_Request_Flame_SetIgnition() {}

    FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition InIgnition)
    {
        Ignition = InIgnition;
    }

    FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition InIgnition, FCk_Handle_Flame InSource)
    {
        Ignition = InIgnition;
        Origin = EMars_Flame_IgnitionOrigin::FromAFlame;
        Source = InSource;
    }
}

// Adds Measures, capped at full. A spent flame starts its new measure from the beginning. Measured, refuelable fuel only.
struct FMars_Request_Flame_Refuel
{
    UPROPERTY()
    int32 Measures = 1;

    FMars_Request_Flame_Refuel() {}

    FMars_Request_Flame_Refuel(int32 InMeasures)
    {
        Measures = InMeasures;
    }
}

// Drain order: every refuel, then the latest ignition (so a refuel and a Lit in one frame light it).
struct FMars_Fragment_Flame_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Flame_Refuel> RefuelRequests;

    UPROPERTY()
    TArray<FMars_Request_Flame_SetIgnition> SetIgnitionRequests;
}
