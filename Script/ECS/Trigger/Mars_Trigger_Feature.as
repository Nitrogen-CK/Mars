//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_TriggerHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Trigger";
    RequiredFragments.Add(FMars_Feature_Trigger);
    Description = "A probe volume entity that tracks the entities inside it and fires OnEntityEntered/OnEntityExited";
}
struct FMars_Feature_Trigger {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Trigger_Shape
{
    Box,
    Sphere
}

struct FMars_Trigger_Spec
{
    UPROPERTY()
    EMars_Trigger_Shape Shape = EMars_Trigger_Shape::Box;

    UPROPERTY()
    FVector BoxHalfExtents = FVector(200.0, 200.0, 100.0);

    UPROPERTY()
    float32 SphereRadius = 200.0f;

    // Non-identity places the probe on a child scene node at this offset.
    UPROPERTY()
    FTransform LocalOffset = FTransform::Identity;

    // Matches the probe names of other entities' probes. Empty detects every probe.
    UPROPERTY(meta = (Categories = "Probe"))
    FGameplayTagContainer DetectionFilter;

    // Set when the volume sits on something that moves, so the probe is kinematic instead of static.
    UPROPERTY()
    bool Moving = false;
}

// A volume with size along every axis of its shape.
mixin FMars_Validation Validate(const FMars_Trigger_Spec& Self)
{
    if (Self.Shape == EMars_Trigger_Shape::Sphere)
    {
        if (Self.SphereRadius <= 0.0f)
        { return FMars_Validation(f"SphereRadius [{Self.SphereRadius}] must be positive"); }

        return FMars_Validation();
    }

    if (Self.BoxHalfExtents.X <= 0.0 || Self.BoxHalfExtents.Y <= 0.0 || Self.BoxHalfExtents.Z <= 0.0)
    { return FMars_Validation(f"BoxHalfExtents [{Self.BoxHalfExtents.ToString()}] must be positive on every axis"); }

    return FMars_Validation();
}

struct FMars_Tag_Trigger_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Trigger
{
    UPROPERTY()
    TArray<FCk_Handle> EntitiesInside;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Trigger_OnEntityEntered(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity);
event void FMars_Delegate_Trigger_OnEntityEntered_MC(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity);

delegate void FMars_Delegate_Trigger_OnEntityExited(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity);
event void FMars_Delegate_Trigger_OnEntityExited_MC(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity);

struct FMars_Fragment_Trigger_Signals
{
    FMars_Delegate_Trigger_OnEntityEntered_MC OnEntityEntered;
    FMars_Delegate_Trigger_OnEntityExited_MC OnEntityExited;
}
