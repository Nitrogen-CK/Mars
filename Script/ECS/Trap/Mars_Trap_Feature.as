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

// What the trap does as its cycle enters Phase; an unset field leaves that part alone.
struct FMars_Trap_PhaseAction
{
    UPROPERTY(meta = (Categories = "Mechanism.Phase"))
    FGameplayTag Phase;

    UPROPERTY()
    TOptional<bool> MoverAtEnd;

    UPROPERTY()
    TOptional<bool> HazardArmed;
}

// Spawn params of the placeable trap scripts: per-instance values live in saved maps.
struct FMars_Trap_Spec
{
    UPROPERTY()
    FMars_Cycle_Spec Cycle;

    UPROPERTY()
    TArray<FMars_Trap_PhaseAction> Actions;

    UPROPERTY()
    EMars_PoweredBehavior Powered = EMars_PoweredBehavior::SuppressWhilePowered;
}

// The cycle's own rules, and every action names one of its phases (an action on a missing phase would never run).
mixin FMars_Validation Validate(const FMars_Trap_Spec& Self)
{
    const auto CycleValidation = Self.Cycle.Validate();
    if (CycleValidation.IsValid() == false)
    { return CycleValidation; }

    for (int32 Index = 0; Index < Self.Actions.Num(); ++Index)
    {
        const auto& Action = Self.Actions[Index];

        auto IsCyclePhase = false;
        for (const auto& Phase : Self.Cycle.Phases)
        {
            if (Phase.Phase == Action.Phase)
            { IsCyclePhase = true; }
        }

        if (IsCyclePhase == false)
        { return FMars_Validation(f"Trap action [{Index}] names phase [{Action.Phase.ToString()}], which the cycle does not have"); }
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Trap_Params
{
    UPROPERTY()
    FMars_Trap_Spec Spec;
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
