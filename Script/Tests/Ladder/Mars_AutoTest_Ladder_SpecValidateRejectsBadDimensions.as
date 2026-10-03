// Validate() accepts the default ladder and rejects one with no height, no standoff, no top exit or no zone height padding,
// each with an error naming the field it rejected.
class UMars_AutoTest_Ladder_SpecValidateRejectsBadDimensions : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the default ladder and each bad dimension", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertValid(FMars_Ladder_Spec(), "the default ladder");

        auto NoHeight = FMars_Ladder_Spec();
        NoHeight.Height = 0.0f;
        AssertRejectedField(NoHeight, "Height");

        auto NoStandoff = FMars_Ladder_Spec();
        NoStandoff.Standoff = 0.0f;
        AssertRejectedField(NoStandoff, "Standoff");

        auto NoTopExit = FMars_Ladder_Spec();
        NoTopExit.TopExitDepth = 0.0f;
        AssertRejectedField(NoTopExit, "TopExitDepth");

        auto NoZonePadding = FMars_Ladder_Spec();
        NoZonePadding.ZoneHeightPadding = 0.0f;
        AssertRejectedField(NoZonePadding, "ZoneHeightPadding");
    }

    private void AssertValid(const FMars_Ladder_Spec& InSpec, const FString& InCase)
    {
        const auto Validation = InSpec.Validate();
        Assert_True(Validation.IsValid(), f"{InCase} is accepted (error: {Validation.Get_Error()})");
    }

    // InField set to 0 is rejected by its own rule: the error names the field followed by its bracketed value, so
    // "Height [" cannot match the ZoneHeightPadding rule.
    private void AssertRejectedField(const FMars_Ladder_Spec& InSpec, const FString& InField)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"Validate() rejects {InField} 0");
        Assert_True(Validation.Get_Error().Contains(f"{InField} ["),
            f"Validate() on {InField} 0 names [{InField}] as the rejected field (got [{Validation.Get_Error()}])");
    }
}
