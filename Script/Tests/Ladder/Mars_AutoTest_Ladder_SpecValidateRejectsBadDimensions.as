// Validate() accepts the default ladder and rejects one with no height, no standoff or no top exit.
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
        AssertInvalid(NoHeight, "Height 0");

        auto NoStandoff = FMars_Ladder_Spec();
        NoStandoff.Standoff = 0.0f;
        AssertInvalid(NoStandoff, "Standoff 0");

        auto NoTopExit = FMars_Ladder_Spec();
        NoTopExit.TopExitDepth = 0.0f;
        AssertInvalid(NoTopExit, "TopExitDepth 0");
    }

    private void AssertValid(const FMars_Ladder_Spec& InSpec, const FString& InCase)
    {
        const auto Validation = InSpec.Validate();
        Assert_True(Validation.IsValid, f"{InCase} is accepted (error: {Validation.Get_Error()})");
    }

    private void AssertInvalid(const FMars_Ladder_Spec& InSpec, const FString& InCase)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid, f"{InCase} is rejected");
        Assert_True(Validation.Get_Error().Len() > 0, f"{InCase} names its rule (error: {Validation.Get_Error()})");
    }
}
