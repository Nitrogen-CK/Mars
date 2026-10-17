// A lantern needs at least one measure of positive length, a gutter no longer than a measure, a start inside its
// measures and positive radii.
class UMars_AutoTest_Lantern_SpecValidateRejectsBadFuelAndRadii : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the spec rules", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Defaults = FMars_Lantern_Spec().Validate();
        Assert_True(Defaults.IsValid(), f"the defaults are valid ({Defaults.Get_Error()})");

        auto NoMeasures = FMars_Lantern_Spec();
        NoMeasures.Measures = 0;
        Assert_False(NoMeasures.Validate().IsValid(), "zero measures is rejected");

        auto Timeless = FMars_Lantern_Spec();
        Timeless.SecondsPerMeasure = 0.0f;
        Assert_False(Timeless.Validate().IsValid(), "a zero-length measure is rejected");

        auto LongGutter = FMars_Lantern_Spec();
        LongGutter.GutterSeconds = LongGutter.SecondsPerMeasure + 1.0f;
        Assert_False(LongGutter.Validate().IsValid(), "a gutter longer than a measure is rejected");

        auto Overfull = FMars_Lantern_Spec();
        Overfull.StartMeasures = TOptional<int32>(Overfull.Measures + 1);
        Assert_False(Overfull.Validate().IsValid(), "starting with more than Measures is rejected");

        auto Empty = FMars_Lantern_Spec();
        Empty.StartMeasures = TOptional<int32>(0);
        Assert_True(Empty.Validate().IsValid(), "starting empty is valid");

        auto Unlit = FMars_Lantern_Spec();
        Unlit.Radius.World = 0.0f;
        Assert_False(Unlit.Validate().IsValid(), "a zero radius is rejected");
    }
}
