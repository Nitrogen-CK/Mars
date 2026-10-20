// The rest grips, now built with Make_GripRotation from where the fingers point and what the palm faces, are the rotations
// A_FPHands_Ready was authored against: within half a degree of the FRotator literals they replaced, on every axis of
// both gloves. The fingers and palm read back from them are the ones the spec states.
class UMars_AutoTest_FPHands_RestGripsMatchTheReadyPose : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Rest = FMars_FPHands_RestSpec();
        AssertMatches(Rest.GripRotation_R, FQuat(FRotator(65.186, -128.076, 144.583)), "right");
        AssertMatches(Rest.GripRotation_L, FQuat(FRotator(65.186, 128.076, -144.583)), "left");

        const auto FingersR = utils_fphands::Get_GripFingers(EMars_Hand::Right, Rest.GripRotation_R);
        Assert_True(FingersR.Equals(FVector(0.9659, -0.0885, 0.2432), 0.001), f"the right fingers point forward and up (got {FingersR})");
        const auto PalmR = Rest.GripRotation_R.GetUpVector();
        Assert_True(PalmR.Equals(FVector(0.0, -0.9397, -0.342), 0.001), f"the right palm faces in and down (got {PalmR})");

        FinishSuccess();
    }

    // Each axis of InActual within 0.5 degrees of InExpected's.
    private void AssertMatches(const FQuat& InActual, const FQuat& InExpected, const FString& InHand)
    {
        const auto MinDot = Math::Cos(Math::DegreesToRadians(0.5));
        const auto Forward = InActual.GetForwardVector().DotProduct(InExpected.GetForwardVector());
        const auto Right = InActual.GetRightVector().DotProduct(InExpected.GetRightVector());
        const auto Up = InActual.GetUpVector().DotProduct(InExpected.GetUpVector());
        Assert_True(Forward >= MinDot && Right >= MinDot && Up >= MinDot,
            f"the {InHand} rest grip is within 0.5 degrees of the ready pose (axis dots {Forward}, {Right}, {Up})");
    }
}
