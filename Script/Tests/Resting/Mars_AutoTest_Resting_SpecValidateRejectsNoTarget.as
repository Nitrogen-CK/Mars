// Validate() rejects a spec without a target (the default), accepts one with a live target, and rejects a non-positive
// grace and a negative hop time.
class UMars_AutoTest_Resting_SpecValidateRejectsNoTarget : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate a targeted spec and three bad ones", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertRejected(FMars_Resting_Spec().Validate(), "no Target");

        const auto Targeted = FMars_Resting_Spec(InHandle).Validate();
        Assert_True(Targeted.IsValid(), f"a spec with a live target is accepted (error: {Targeted.Get_Error()})");

        AssertRejected(FMars_Resting_Spec(InHandle, 0.0f, 0.12f).Validate(), "GraceSeconds <= 0");
        AssertRejected(FMars_Resting_Spec(InHandle, 0.1f, -1.0f).Validate(), "HopMinSeconds < 0");
    }

    private void AssertRejected(const FMars_Validation& InValidation, const FString& InRule)
    {
        Assert_False(InValidation.IsValid(), f"{InRule} is rejected");
        Assert_True(InValidation.Get_Error().Len() > 0, f"the {InRule} rejection names its rule (error: {InValidation.Get_Error()})");
    }
}
