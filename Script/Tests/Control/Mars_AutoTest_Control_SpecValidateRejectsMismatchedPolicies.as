// Validate() accepts each completion policy at its defaults and rejects a spec whose policy-specific tuning cannot work:
// a Timed hold of no time, a manipulation that never engages, never moves or gains energy, a Momentary pulse of no time.
class UMars_AutoTest_Control_SpecValidateRejectsMismatchedPolicies : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate each policy against good and bad tuning", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Instant = FMars_Control_Spec();
        AssertValid(Instant, "Instant at defaults");

        auto TimedNoHold = FMars_Control_Spec();
        TimedNoHold.Interaction = ECk_Interaction_CompletionPolicy::Timed;
        TimedNoHold.HoldSeconds = 0.0f;
        AssertInvalid(TimedNoHold, "Timed with HoldSeconds 0");

        auto Timed = FMars_Control_Spec();
        Timed.Interaction = ECk_Interaction_CompletionPolicy::Timed;
        Timed.HoldSeconds = 1.5f;
        AssertValid(Timed, "Timed with HoldSeconds 1.5");

        auto Manual = FMars_Control_Spec();
        Manual.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        AssertValid(Manual, "ManuallyCompleted at defaults");

        auto ManualNoEngage = Manual;
        ManualNoEngage.Manipulation.EngageAlpha = 0.0f;
        AssertInvalid(ManualNoEngage, "ManuallyCompleted with EngageAlpha 0");

        auto ManualPastEnd = Manual;
        ManualPastEnd.Manipulation.EngageAlpha = 1.2f;
        AssertInvalid(ManualPastEnd, "ManuallyCompleted with EngageAlpha 1.2");

        auto ManualNoTravel = Manual;
        ManualNoTravel.Manipulation.AlphaPerDegree = 0.0f;
        AssertInvalid(ManualNoTravel, "ManuallyCompleted with AlphaPerDegree 0");

        auto ManualNoSpring = Manual;
        ManualNoSpring.Manipulation.Stiffness = 0.0f;
        AssertInvalid(ManualNoSpring, "ManuallyCompleted with Stiffness 0");

        auto ManualPushingDamper = Manual;
        ManualPushingDamper.Manipulation.Damping = -1.0f;
        AssertInvalid(ManualPushingDamper, "ManuallyCompleted with Damping -1");

        auto MomentaryNoPulse = FMars_Control_Spec();
        MomentaryNoPulse.Behavior = EMars_Control_Behavior::Momentary;
        MomentaryNoPulse.ActiveSeconds = 0.0f;
        AssertInvalid(MomentaryNoPulse, "Momentary with ActiveSeconds 0");
    }

    private void AssertValid(const FMars_Control_Spec& InSpec, const FString& InCase)
    {
        const auto Validation = InSpec.Validate();
        Assert_True(Validation.IsValid(), f"{InCase} is accepted (error: {Validation.Get_Error()})");
    }

    private void AssertInvalid(const FMars_Control_Spec& InSpec, const FString& InCase)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"{InCase} is rejected");
        Assert_True(Validation.Get_Error().Len() > 0, f"{InCase} names its rule (error: {Validation.Get_Error()})");
    }
}
