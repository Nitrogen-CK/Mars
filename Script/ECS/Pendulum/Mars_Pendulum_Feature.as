//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PendulumHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Pendulum";
    RequiredFragments.Add(FMars_Feature_Pendulum);
    Description = "A swinging hazard: an oscillator whose hazard is armed while it runs";
}
struct FMars_Feature_Pendulum {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Pendulum_Spec
{
    UPROPERTY()
    EMars_PoweredBehavior Powered = EMars_PoweredBehavior::SuppressWhilePowered;
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
