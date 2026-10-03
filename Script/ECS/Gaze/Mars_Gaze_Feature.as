// Who an eye node should look at: the nearest owner of a detected probe that publishes the aim attach point, inside a
// range shell and a cone around the node's +X, held against challengers that are not clearly closer. Gaze only picks
// the target and its yaw/pitch; whatever looks (eyes, a head) reads them.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_GazeHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Gaze";
    RequiredFragments.Add(FMars_Feature_Gaze);
    Description = "An eye node that picks the nearest detected owner in range and in front to look at, and exposes its yaw/pitch";
}
struct FMars_Feature_Gaze {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Gaze_Spec
{
    // Probe names that count as something to look at. Empty is rejected: an empty filter detects every probe.
    UPROPERTY(meta = (Categories = "Probe"))
    FGameplayTagContainer DetectionFilter;

    // Attach point on the detected owner that is the point to look at.
    UPROPERTY(meta = (Categories = "AttachPoint"))
    FGameplayTag AimPoint;

    UPROPERTY()
    float32 RangeCm = 900.0f;

    UPROPERTY()
    float32 MinRangeCm = 20.0f;

    // Half-angle of the cone around the eye node's +X inside which a target is eligible.
    UPROPERTY()
    float32 ConeHalfAngleDeg = 80.0f;

    // A challenger replaces the current target only when it is closer by at least this fraction of the current distance.
    UPROPERTY()
    float32 SwitchCloserRatio = 0.15f;
}

// All-or-nothing: a filter, an aim point, finite numbers, 0 <= MinRangeCm < RangeCm, ConeHalfAngleDeg in (0, 180],
// SwitchCloserRatio in [0, 1). Reports the first failing rule.
mixin FMars_Validation Validate(const FMars_Gaze_Spec& Self)
{
    if (Self.DetectionFilter.IsEmpty())
    { return FMars_Validation("DetectionFilter is empty - an empty filter detects every probe"); }

    if (Self.AimPoint.IsValid() == false)
    { return FMars_Validation("AimPoint has no tag"); }

    // A NaN passes every comparison below, so finiteness is checked first.
    if (Math::IsFinite(Self.RangeCm) == false)
    { return FMars_Validation(f"RangeCm [{Self.RangeCm}] is not finite"); }

    if (Math::IsFinite(Self.MinRangeCm) == false)
    { return FMars_Validation(f"MinRangeCm [{Self.MinRangeCm}] is not finite"); }

    if (Math::IsFinite(Self.ConeHalfAngleDeg) == false)
    { return FMars_Validation(f"ConeHalfAngleDeg [{Self.ConeHalfAngleDeg}] is not finite"); }

    if (Math::IsFinite(Self.SwitchCloserRatio) == false)
    { return FMars_Validation(f"SwitchCloserRatio [{Self.SwitchCloserRatio}] is not finite"); }

    if (Self.MinRangeCm < 0.0f)
    { return FMars_Validation(f"MinRangeCm [{Self.MinRangeCm}] is negative"); }

    if (Self.RangeCm <= Self.MinRangeCm)
    { return FMars_Validation(f"RangeCm [{Self.RangeCm}] does not exceed MinRangeCm [{Self.MinRangeCm}]"); }

    if (Self.ConeHalfAngleDeg <= 0.0f || Self.ConeHalfAngleDeg > 180.0f)
    { return FMars_Validation(f"ConeHalfAngleDeg [{Self.ConeHalfAngleDeg}] is outside (0, 180]"); }

    if (Self.SwitchCloserRatio < 0.0f || Self.SwitchCloserRatio >= 1.0f)
    { return FMars_Validation(f"SwitchCloserRatio [{Self.SwitchCloserRatio}] is outside [0, 1)"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// DetectionFilter only shapes the sense trigger at Add; the select pass reads the rest.
struct FMars_Fragment_Gaze_Params
{
    UPROPERTY()
    FMars_Gaze_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Sense is composed by utils_gaze::Add; Target, AimYawPitchDeg and ReportedOwnersWithoutAim are written only by
// UMars_Processor_Gaze_Select.
struct FMars_Fragment_Gaze
{
    // Sphere trigger on a child node of the eye node. Its entities are re-read every pass, never mirrored.
    UPROPERTY()
    FCk_Handle_Trigger Sense;

    // Sensed owners that publish no AimPoint and have already been reported, so each is reported once while it stays
    // sensed. Pruned every pass to the owners still resolved from the sense trigger's contents.
    UPROPERTY()
    TArray<FCk_Handle> ReportedOwnersWithoutAim;

    // The aim-point node being looked at; invalid when none.
    UPROPERTY()
    FCk_Handle_Transform Target;

    // Relative to the eye node's +X: yaw positive to the right, pitch positive up. Zero when there is no target.
    UPROPERTY()
    FVector2D AimYawPitchDeg;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Gaze_OnTargetChanged(FCk_Handle_Gaze InGaze, FCk_Handle_Transform InPrevious, FCk_Handle_Transform InCurrent);
event void FMars_Delegate_Gaze_OnTargetChanged_MC(FCk_Handle_Gaze InGaze, FCk_Handle_Transform InPrevious, FCk_Handle_Transform InCurrent);

struct FMars_Fragment_Gaze_Signals
{
    FMars_Delegate_Gaze_OnTargetChanged_MC OnTargetChanged;
}
