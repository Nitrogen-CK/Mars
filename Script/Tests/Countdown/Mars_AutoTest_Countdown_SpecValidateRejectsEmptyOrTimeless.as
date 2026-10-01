// A countdown needs at least one step, each lasting a positive time.
class UMars_AutoTest_Countdown_SpecValidateRejectsEmptyOrTimeless : UCk_AutoTest_Base
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
        const auto Defaults = FMars_Countdown_Spec().Validate();
        Assert_True(Defaults.IsValid, f"the defaults are valid ({Defaults.Get_Error()})");

        const auto OneStep = FMars_Countdown_Spec(1, 0.1f, true).Validate();
        Assert_True(OneStep.IsValid, f"one short step, charged, is valid ({OneStep.Get_Error()})");

        const auto NoSteps = FMars_Countdown_Spec(0, 1.0f, false).Validate();
        Assert_False(NoSteps.IsValid, f"zero steps is rejected ({NoSteps.Get_Error()})");

        const auto NegativeSteps = FMars_Countdown_Spec(-2, 1.0f, false).Validate();
        Assert_False(NegativeSteps.IsValid, f"negative steps is rejected ({NegativeSteps.Get_Error()})");

        const auto Timeless = FMars_Countdown_Spec(3, 0.0f, false).Validate();
        Assert_False(Timeless.IsValid, f"a zero-length step is rejected ({Timeless.Get_Error()})");
    }
}
