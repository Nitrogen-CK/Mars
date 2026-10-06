// Validate() accepts the default implement spec and rejects a tilt that cannot steer, cannot move or tilts past 80
// degrees, a negative level return, a lift spring with no stiffness or damping, a floor above rest, and an orbit with a
// negative radius, no frequency or an instant ease.
class UMars_AutoTest_Implement_SpecValidateRejectsBadTilts : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the default spec and eleven bad ones", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Default = FMars_Implement_Spec().Validate();
        Assert_True(Default.IsValid(), f"the default spec is accepted (error: {Default.Get_Error()})");

        auto Deaf = FMars_Implement_Spec();
        Deaf.Tilt.TiltPerLookDegree = 0.0f;
        AssertRejected(Deaf.Validate(), "TiltPerLookDegree <= 0");

        auto Frozen = FMars_Implement_Spec();
        Frozen.Tilt.MaxTiltRateDegreesPerSecond = 0.0f;
        AssertRejected(Frozen.Validate(), "MaxTiltRateDegreesPerSecond <= 0");

        auto Steep = FMars_Implement_Spec();
        Steep.Tilt.MaxTiltDegrees = 81.0f;
        AssertRejected(Steep.Validate(), "MaxTiltDegrees > 80");

        auto Flat = FMars_Implement_Spec();
        Flat.Tilt.MaxTiltDegrees = 0.0f;
        AssertRejected(Flat.Validate(), "MaxTiltDegrees <= 0");

        auto Drifting = FMars_Implement_Spec();
        Drifting.Tilt.LevelReturnDegreesPerSecond = -1.0f;
        AssertRejected(Drifting.Validate(), "LevelReturnDegreesPerSecond < 0");

        auto Slack = FMars_Implement_Spec();
        Slack.Lift.SpringHz = 0.0f;
        AssertRejected(Slack.Validate(), "SpringHz <= 0");

        auto Undamped = FMars_Implement_Spec();
        Undamped.Lift.DampingRatio = 0.0f;
        AssertRejected(Undamped.Validate(), "DampingRatio <= 0");

        auto Raised = FMars_Implement_Spec();
        Raised.Lift.MinLift = 1.0f;
        AssertRejected(Raised.Validate(), "MinLift > 0");

        auto Inverted = FMars_Implement_Spec();
        Inverted.Orbit = FMars_Implement_OrbitSpec(-1.0f, 1.0f);
        AssertRejected(Inverted.Validate(), "Orbit.Radius < 0");

        auto Still = FMars_Implement_Spec();
        Still.Orbit = FMars_Implement_OrbitSpec(3.0f, 0.0f);
        AssertRejected(Still.Validate(), "Orbit.Hz <= 0");

        auto Snapping = FMars_Implement_Spec();
        Snapping.Orbit = FMars_Implement_OrbitSpec(3.0f, 1.0f, 0.0f);
        AssertRejected(Snapping.Validate(), "Orbit.EaseSeconds <= 0");
    }

    private void AssertRejected(const FMars_Validation& InValidation, const FString& InRule)
    {
        Assert_False(InValidation.IsValid(), f"{InRule} is rejected");
        Assert_True(InValidation.Get_Error().Len() > 0, f"the {InRule} rejection names its rule (error: {InValidation.Get_Error()})");
    }
}
