// A dock spec with the dock's prompt is accepted; rejected, each naming its rule: a zero, negative or NaN ProbeRadius, a
// prompt with no input action, and a NaN MountLocal.
class UMars_AutoTest_PlatterDock_SpecValidateRejectsInvalid : UCk_AutoTest_Base
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
        const auto Good = Make_Spec().Validate();
        Assert_True(Good.IsValid(), f"a dock with the dock prompt is valid ({Good.Get_Error()})");

        auto NoRadius = Make_Spec();
        NoRadius.ProbeRadius = 0.0f;
        AssertRejected(NoRadius, "ProbeRadius", "a zero ProbeRadius");

        auto NegativeRadius = Make_Spec();
        NegativeRadius.ProbeRadius = -1.0f;
        AssertRejected(NegativeRadius, "ProbeRadius", "a negative ProbeRadius");

        auto NaNRadius = Make_Spec();
        NaNRadius.ProbeRadius = float32(Math::Sqrt(-1.0));
        AssertRejected(NaNRadius, "ProbeRadius", "a NaN ProbeRadius");

        auto NoPrompt = Make_Spec();
        NoPrompt.Prompt = FMars_InteractPrompt_Spec();
        AssertRejected(NoPrompt, "prompt input action", "a prompt with no input action");

        auto NaNMount = Make_Spec();
        NaNMount.MountLocal.SetTranslation(FVector(Math::Sqrt(-1.0), 0.0, 0.0));
        AssertRejected(NaNMount, "MountLocal", "a NaN MountLocal");
    }

    private FMars_PlatterDock_Spec Make_Spec() const
    {
        auto Spec = FMars_PlatterDock_Spec();
        Spec.Prompt = utils_platter_dock::Make_PromptSpec();
        return Spec;
    }

    private void AssertRejected(const FMars_PlatterDock_Spec& InSpec, const FString& InRule, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Contains(InRule), f"the rejection of {InWhat} names [{InRule}] (got [{Result.Get_Error()}])");
    }
}
