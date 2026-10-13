// Every phase must last a positive time: a zero or negative one is rejected and named in the error.
class UMars_AutoTest_Devour_SpecValidateRejectsAPhaseWithNoTime : UCk_AutoTest_Base
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
        const auto Defaults = FMars_Devour_Spec().Validate();
        Assert_True(Defaults.IsValid(), f"the defaults are valid ({Defaults.Get_Error()})");

        auto Timeless = FMars_Devour_Spec();
        Timeless.Timing.GrinSeconds = 0.0f;
        const auto TimelessValidation = Timeless.Validate();
        Assert_False(TimelessValidation.IsValid(), f"a zero-length Grin is rejected ({TimelessValidation.Get_Error()})");
        Assert_True(TimelessValidation.Get_Error().Contains("GrinSeconds"), f"the error names the phase ({TimelessValidation.Get_Error()})");

        auto Negative = FMars_Devour_Spec();
        Negative.Timing.SwallowedSeconds = -1.0f;
        const auto NegativeValidation = Negative.Validate();
        Assert_False(NegativeValidation.IsValid(), f"a negative Swallowed is rejected ({NegativeValidation.Get_Error()})");
        Assert_True(NegativeValidation.Get_Error().Contains("SwallowedSeconds"), f"the error names the phase ({NegativeValidation.Get_Error()})");

        const auto Timing = FMars_Devour_Spec().Timing;
        Assert_True(Timing.Get_Seconds(EMars_Devour_Phase::Idle) == 0.0f, "Idle has no duration");
        Assert_True(Timing.Get_Seconds(EMars_Devour_Phase::Lift) == Timing.LiftSeconds, "Get_Seconds reads each phase's own field");
    }
}
