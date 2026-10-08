// Validate() accepts the rig's spec (and the default) and rejects one bad field at a time, each rejection naming the field:
// a reach with no width or height, no look, a hand that never follows or a negative reach time, a target nobody can hover,
// a drum that never turns, has no orbit or a negative length, a repose of 0 or past 90, a slide that never moves, a drum
// with no room and a coating that never grows.
class UMars_AutoTest_Tumbler_SpecValidateRejectsBadSpecs : UMars_AutoTestRig_Tumbler
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the rig's spec, the default and fifteen bad ones", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_TestSpec().Validate();
        Assert_True(Good.IsValid(), f"the rig's spec is accepted (error: {Good.Get_Error()})");

        const auto DefaultSpec = FMars_Tumbler_Spec();
        const auto Default = DefaultSpec.Validate();
        Assert_True(Default.IsValid(), f"the default spec is accepted (error: {Default.Get_Error()})");

        auto NoWidth = Make_TestSpec();
        NoWidth.Hand.HalfExtentY = 0.0f;
        AssertRejected(NoWidth.Validate(), "Hand.HalfExtentY");

        auto NoHeight = Make_TestSpec();
        NoHeight.Hand.HalfExtentZ = 0.0f;
        AssertRejected(NoHeight.Validate(), "Hand.HalfExtentZ");

        auto NoLook = Make_TestSpec();
        NoLook.Hand.CmPerLookDegree = 0.0f;
        AssertRejected(NoLook.Validate(), "Hand.CmPerLookDegree");

        auto NoFollow = Make_TestSpec();
        NoFollow.Hand.FollowRate = 0.0f;
        AssertRejected(NoFollow.Validate(), "Hand.FollowRate");

        auto NegativeReach = Make_TestSpec();
        NegativeReach.Hand.ReachSeconds = -0.1f;
        AssertRejected(NegativeReach.Validate(), "Hand.ReachSeconds");

        auto NoHatchRadius = Make_TestSpec();
        NoHatchRadius.Targets.HatchRadius = 0.0f;
        AssertRejected(NoHatchRadius.Validate(), "Targets.HatchRadius");

        auto NoLeverRadius = Make_TestSpec();
        NoLeverRadius.Targets.LeverRadius = 0.0f;
        AssertRejected(NoLeverRadius.Validate(), "Targets.LeverRadius");

        auto NoArc = Make_TestSpec();
        NoArc.Drum.ArcDegrees = 0.0f;
        AssertRejected(NoArc.Validate(), "Drum.ArcDegrees");

        auto NoOrbit = Make_TestSpec();
        NoOrbit.Drum.InnerRadius = 0.0f;
        AssertRejected(NoOrbit.Validate(), "Drum.InnerRadius");

        auto NegativeLength = Make_TestSpec();
        NegativeLength.Drum.HalfLength = -1.0f;
        AssertRejected(NegativeLength.Validate(), "Drum.HalfLength");

        auto NoRepose = Make_TestSpec();
        NoRepose.Drum.ReposeDegrees = 0.0f;
        AssertRejected(NoRepose.Validate(), "Drum.ReposeDegrees");

        auto SteepRepose = Make_TestSpec();
        SteepRepose.Drum.ReposeDegrees = 91.0f;
        AssertRejected(SteepRepose.Validate(), "Drum.ReposeDegrees");

        auto NoSlide = Make_TestSpec();
        NoSlide.Drum.SlideDegreesPerSecond = 0.0f;
        AssertRejected(NoSlide.Validate(), "Drum.SlideDegreesPerSecond");

        auto NoRoom = Make_TestSpec();
        NoRoom.Drum.Capacity = 0;
        AssertRejected(NoRoom.Validate(), "Drum.Capacity");

        auto NoCoating = Make_TestSpec();
        NoCoating.Coating.CoveragePerDegree = 0.0f;
        AssertRejected(NoCoating.Validate(), "Coating.CoveragePerDegree");
    }

    private void AssertRejected(const FMars_Validation& InValidation, const FString& InField)
    {
        Assert_False(InValidation.IsValid(), f"a bad {InField} is rejected");
        Assert_True(InValidation.Get_Error().Contains(InField), f"the rejection names {InField} (error: {InValidation.Get_Error()})");
    }
}
