//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_TrapHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Trap";
    RequiredFragments.Add(FMars_Feature_Trap);
    Description = "A cycle-driven trap that arms a hazard and optionally moves a part per phase";
}
struct FMars_Feature_Trap {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// How an optional MechanismSink on the same entity gates the trap's motion.
enum EMars_PoweredBehavior
{
    RunWhilePowered,
    SuppressWhilePowered
}

struct FMars_Trap_PhaseAction
{
    UPROPERTY(meta = (Categories = "Mechanism.Phase"))
    FGameplayTag Phase;

    UPROPERTY()
    TOptional<bool> MoverAtEnd;

    UPROPERTY()
    TOptional<bool> HazardArmed;
}

struct FMars_Trap_Spec
{
    UPROPERTY()
    FMars_Cycle_Spec Cycle;

    UPROPERTY()
    TArray<FMars_Trap_PhaseAction> Actions;

    UPROPERTY()
    EMars_PoweredBehavior Powered = EMars_PoweredBehavior::SuppressWhilePowered;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Trap_Params
{
    UPROPERTY()
    TArray<FMars_Trap_PhaseAction> Actions;

    UPROPERTY()
    EMars_PoweredBehavior Powered = EMars_PoweredBehavior::SuppressWhilePowered;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Trap
{
    UPROPERTY()
    FCk_Handle_Cycle Cycle;

    UPROPERTY()
    FCk_Handle_Hazard Hazard;

    // Invalid when the trap moves no part.
    UPROPERTY()
    FCk_Handle_Mover Mover;
}

struct FMars_Tag_Trap_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Trap_OnTriggered(FCk_Handle_Trap InTrap, FCk_Handle InEntity);
event void FMars_Delegate_Trap_OnTriggered_MC(FCk_Handle_Trap InTrap, FCk_Handle InEntity);

struct FMars_Fragment_Trap_Signals
{
    FMars_Delegate_Trap_OnTriggered_MC OnTriggered;
}
