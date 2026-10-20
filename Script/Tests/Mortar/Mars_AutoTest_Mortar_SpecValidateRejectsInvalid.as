// Validate() accepts the default spec and the bounds of its ranges, and rejects every rule broken one at a time: a
// non-positive or non-finite clock, a window outside (0, 0.5], a marker off the bar, no crushes needed. Each rejection
// names the field it broke.
class UMars_AutoTest_Mortar_SpecValidateRejectsInvalid : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the default spec, its bounds and the broken ones", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Default = FMars_Mortar_Spec().Validate();
        Assert_True(Default.IsValid(), f"the default spec is accepted (error: {Default.Get_Error()})");

        auto Bounds = FMars_Mortar_Spec();
        Bounds.Timing.WindowHalfWidth = 0.5f;
        Bounds.Timing.Marker = 0.0f;
        Bounds.CrushesNeeded = 1;
        Assert_True(Bounds.Validate().IsValid(), "a half-bar window, the marker at the left end and one crush are accepted");
        Bounds.Timing.Marker = 1.0f;
        Assert_True(Bounds.Validate().IsValid(), "the marker at the right end is accepted");

        const auto NotANumber = float32(Math::Sqrt(-1.0));
        Assert_True(Math::IsNaN(NotANumber), "the test input is NaN");

        auto ZeroSweep = FMars_Mortar_Spec();
        ZeroSweep.Timing.SweepSeconds = 0.0f;
        AssertRejected(ZeroSweep, "SweepSeconds", "a zero SweepSeconds");

        auto NaNSweep = FMars_Mortar_Spec();
        NaNSweep.Timing.SweepSeconds = NotANumber;
        AssertRejected(NaNSweep, "SweepSeconds", "a NaN SweepSeconds");

        auto NoWindow = FMars_Mortar_Spec();
        NoWindow.Timing.WindowHalfWidth = 0.0f;
        AssertRejected(NoWindow, "WindowHalfWidth", "a zero WindowHalfWidth");

        auto WideWindow = FMars_Mortar_Spec();
        WideWindow.Timing.WindowHalfWidth = 0.51f;
        AssertRejected(WideWindow, "WindowHalfWidth", "a WindowHalfWidth over 0.5");

        auto NaNWindow = FMars_Mortar_Spec();
        NaNWindow.Timing.WindowHalfWidth = NotANumber;
        AssertRejected(NaNWindow, "WindowHalfWidth", "a NaN WindowHalfWidth");

        auto MarkerLeft = FMars_Mortar_Spec();
        MarkerLeft.Timing.Marker = -0.01f;
        AssertRejected(MarkerLeft, "Marker", "a Marker left of the bar");

        auto MarkerRight = FMars_Mortar_Spec();
        MarkerRight.Timing.Marker = 1.01f;
        AssertRejected(MarkerRight, "Marker", "a Marker right of the bar");

        auto NaNMarker = FMars_Mortar_Spec();
        NaNMarker.Timing.Marker = NotANumber;
        AssertRejected(NaNMarker, "Marker", "a NaN Marker");

        auto NoCrushes = FMars_Mortar_Spec();
        NoCrushes.CrushesNeeded = 0;
        AssertRejected(NoCrushes, "CrushesNeeded", "zero CrushesNeeded");

        auto ZeroGrind = FMars_Mortar_Spec();
        ZeroGrind.GrindSeconds = 0.0f;
        AssertRejected(ZeroGrind, "GrindSeconds", "a zero GrindSeconds");

        auto NaNGrind = FMars_Mortar_Spec();
        NaNGrind.GrindSeconds = NotANumber;
        AssertRejected(NaNGrind, "GrindSeconds", "a NaN GrindSeconds");

        auto ZeroStrike = FMars_Mortar_Spec();
        ZeroStrike.StrikeSeconds = 0.0f;
        AssertRejected(ZeroStrike, "StrikeSeconds", "a zero StrikeSeconds");

        auto NaNStrike = FMars_Mortar_Spec();
        NaNStrike.StrikeSeconds = NotANumber;
        AssertRejected(NaNStrike, "StrikeSeconds", "a NaN StrikeSeconds");
    }

    private void AssertRejected(const FMars_Mortar_Spec& InSpec, const FString& InField, const FString& InLabel)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InLabel} is rejected");
        Assert_True(Result.Get_Error().Contains(InField), f"{InLabel} is rejected naming {InField} (error: {Result.Get_Error()})");
    }
}
