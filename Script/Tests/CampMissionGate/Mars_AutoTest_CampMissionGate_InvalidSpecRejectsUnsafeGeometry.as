// Authoring rejects unsafe geometry before the placeable creates a Gate, visual or physics body. Pure validation emits no ensure.
class UMars_AutoTest_CampMissionGate_InvalidSpecRejectsUnsafeGeometry : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("default and valid boundary geometry passes", n"Step_ValidBoundaries");
        Add_Step("invalid opening, bars, motion and look fail", n"Step_InvalidGroups");
        Add_Step("non-finite dimensions fail", n"Step_NonFinite");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ValidBoundaries(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = FMars_CampMissionGate_Spec();
        Assert_True(Spec.Validate().IsValid(), "default geometry is valid at 25cm bar pitch");
        Spec.Motion.Duration = 0.0f;
        Spec.Motion.Clearance = 0.0;
        Assert_True(Spec.Validate().IsValid(), "instant motion and zero extra clearance are supported");
        Spec.Opening.Width = 50.0;
        Spec.Bars.Count = 2;
        Assert_True(Spec.Validate().IsValid(), "minimum count with safe pitch is valid");
        Spec.Opening.Width = 6400.0;
        Spec.Bars.Count = 256;
        Assert_True(Spec.Validate().IsValid(), "maximum count with safe pitch is valid");
    }

    UFUNCTION()
    private void Step_InvalidGroups(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = FMars_CampMissionGate_Spec();
        Spec.Opening.Width = 0.0;
        Reject(Spec, "Opening dimensions");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Opening.Height = -1.0;
        Reject(Spec, "Opening dimensions");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Opening.FrameThickness = 0.0;
        Reject(Spec, "Opening dimensions");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Opening.FrameDepth = 0.0;
        Reject(Spec, "Opening dimensions");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Bars.Count = 1;
        Reject(Spec, "Bars need");
        Spec.Bars.Count = 257;
        Reject(Spec, "Bars need");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Bars.Thickness = 0.0;
        Reject(Spec, "Bars need");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Bars.RailHeight = 0.0;
        Reject(Spec, "Bars need");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Bars.Thickness = 25.0;
        Reject(Spec, "Bar thickness and rails");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Bars.RailHeight = Spec.Opening.Height * 0.4;
        Reject(Spec, "Bar thickness and rails");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Opening.Width = 401.0;
        Reject(Spec, "Bar pitch exceeds");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Motion.Duration = -0.1f;
        Reject(Spec, "Motion duration");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Motion.Clearance = -0.1;
        Reject(Spec, "Motion duration");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Motion.ThresholdDepth = 0.0;
        Reject(Spec, "Motion duration");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Look.UnitBox = TSoftObjectPtr<UStaticMesh>();
        Reject(Spec, "Look.UnitBox");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Look.Material = TSoftObjectPtr<UMaterialInterface>();
        Reject(Spec, "Look.UnitBox");
    }

    UFUNCTION()
    private void Step_NonFinite(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto NaN = Math::Sqrt(-1.0);
        auto Spec = FMars_CampMissionGate_Spec();
        Spec.Opening.Width = NaN;
        Reject(Spec, "must be finite");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Opening.Height = NaN;
        Reject(Spec, "must be finite");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Bars.Thickness = NaN;
        Reject(Spec, "must be finite");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Motion.Duration = float32(NaN);
        Reject(Spec, "must be finite");
        Spec = FMars_CampMissionGate_Spec();
        Spec.Motion.ThresholdDepth = NaN;
        Reject(Spec, "must be finite");
    }

    private void Reject(const FMars_CampMissionGate_Spec& InSpec, const FString& InRule)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"rejects unsafe geometry: {InRule}");
        Assert_True(Validation.Get_Error().Contains(InRule), f"reports [{InRule}], got [{Validation.Get_Error()}]");
    }
}
