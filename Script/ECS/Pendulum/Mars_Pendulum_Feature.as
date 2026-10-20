//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PendulumHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Pendulum";
    RequiredFragments.Add(FMars_Feature_Pendulum);
    Description = "A swinging hazard: an oscillator whose hazard is armed while it swings";
}
struct FMars_Feature_Pendulum {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The swing and the hazard a pendulum drives, built by its owner before Add. The pendulum finds itself from their signals,
// so the hazard lives on the pendulum's entity and the oscillator on it or on a scene node created directly under it.
struct FMars_Pendulum_Parts
{
    UPROPERTY()
    FCk_Handle_Oscillator Oscillator;

    UPROPERTY()
    FCk_Handle_Hazard Hazard;

    FMars_Pendulum_Parts() {}

    FMars_Pendulum_Parts(FCk_Handle_Oscillator InOscillator, FCk_Handle_Hazard InHazard)
    {
        Oscillator = InOscillator;
        Hazard = InHazard;
    }
}

// Spawn params of the placeable pendulum scripts: per-instance values live in saved maps.
struct FMars_Pendulum_Spec
{
    UPROPERTY()
    EMars_PoweredBehavior Powered = EMars_PoweredBehavior::SuppressWhilePowered;

    // Construction input, never saved: the spawn params and maps do not carry it.
    FMars_Pendulum_Parts Parts;
}

mixin FMars_Validation Validate(const FMars_Pendulum_Spec& Self)
{
    if (ck::Is_NOT_Valid(Self.Parts.Oscillator))
    { return FMars_Validation("Parts.Oscillator must be set: a pendulum without one never swings"); }

    if (ck::Is_NOT_Valid(Self.Parts.Hazard))
    { return FMars_Validation("Parts.Hazard must be set: a pendulum without one never hits"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Pendulum_Params
{
    UPROPERTY()
    EMars_PoweredBehavior Powered = EMars_PoweredBehavior::SuppressWhilePowered;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Pendulum
{
    UPROPERTY()
    FCk_Handle_Oscillator Oscillator;

    UPROPERTY()
    FCk_Handle_Hazard Hazard;
}

struct FMars_Tag_Pendulum_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Pendulum_OnTriggered(FCk_Handle_Pendulum InPendulum, FCk_Handle InEntity);
event void FMars_Delegate_Pendulum_OnTriggered_MC(FCk_Handle_Pendulum InPendulum, FCk_Handle InEntity);

struct FMars_Fragment_Pendulum_Signals
{
    FMars_Delegate_Pendulum_OnTriggered_MC OnTriggered;
}
