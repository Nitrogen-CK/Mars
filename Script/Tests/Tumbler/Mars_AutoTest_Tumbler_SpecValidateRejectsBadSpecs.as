// Validate() accepts the rig's spec, the default and a shell with no baffles, and rejects one bad field at a time, each
// rejection naming the field: a reach with no width or height, no look, a hand that never follows or a negative reach time,
// a target nobody can hover, a drum that never turns, has no radius or length, no room or no escape margin, a shell with no
// wall, too few panels or no disc gap, a hatch gap of 0 or a half turn, a hatch with no plate, a negative baffle count or a
// flat baffle, a surface with no friction or bounce, a piece with no size, one too big for the drum, no mass, friction,
// bounce or damping, and a coating that never grows or has no dead band.
class UMars_AutoTest_Tumbler_SpecValidateRejectsBadSpecs : UMars_AutoTestRig_Tumbler
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the rig's spec, the default, a baffle-less shell and every bad field", n"Step_Validate");
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

        auto NoBaffles = Make_TestSpec();
        NoBaffles.Shell.Baffles.Count = 0;
        const auto Smooth = NoBaffles.Validate();
        Assert_True(Smooth.IsValid(), f"a shell with no baffles is accepted (error: {Smooth.Get_Error()})");

        Validate_Hand();
        Validate_Drum();
        Validate_Shell();
        Validate_Piece();
        Validate_Coating();
    }

    private void Validate_Hand()
    {
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
    }

    private void Validate_Drum()
    {
        auto NoArc = Make_TestSpec();
        NoArc.Drum.ArcDegrees = 0.0f;
        AssertRejected(NoArc.Validate(), "Drum.ArcDegrees");

        auto NoRadius = Make_TestSpec();
        NoRadius.Drum.InnerRadius = 0.0f;
        AssertRejected(NoRadius.Validate(), "Drum.InnerRadius");

        auto NegativeLength = Make_TestSpec();
        NegativeLength.Drum.HalfLength = -1.0f;
        AssertRejected(NegativeLength.Validate(), "Drum.HalfLength");

        auto NoRoom = Make_TestSpec();
        NoRoom.Drum.Capacity = 0;
        AssertRejected(NoRoom.Validate(), "Drum.Capacity");

        auto NoMargin = Make_TestSpec();
        NoMargin.Drum.EscapeMarginCm = 0.0f;
        AssertRejected(NoMargin.Validate(), "Drum.EscapeMarginCm");
    }

    private void Validate_Shell()
    {
        auto NoWall = Make_TestSpec();
        NoWall.Shell.WallThickness = 0.0f;
        AssertRejected(NoWall.Validate(), "Shell.WallThickness");

        auto FewPanels = Make_TestSpec();
        FewPanels.Shell.PanelCount = 5;
        AssertRejected(FewPanels.Validate(), "Shell.PanelCount");

        auto NoDiscGap = Make_TestSpec();
        NoDiscGap.Shell.DiscGap = 0.0f;
        AssertRejected(NoDiscGap.Validate(), "Shell.DiscGap");

        auto NoGap = Make_TestSpec();
        NoGap.Shell.Gap.HalfDegrees = 0.0f;
        AssertRejected(NoGap.Validate(), "Shell.Gap.HalfDegrees");

        auto HalfTurnGap = Make_TestSpec();
        HalfTurnGap.Shell.Gap.HalfDegrees = 90.0f;
        AssertRejected(HalfTurnGap.Validate(), "Shell.Gap.HalfDegrees");

        auto NoPlate = Make_TestSpec();
        NoPlate.Shell.Gap.PlateSegments = 0;
        AssertRejected(NoPlate.Validate(), "Shell.Gap.PlateSegments");

        auto NegativeBaffles = Make_TestSpec();
        NegativeBaffles.Shell.Baffles.Count = -1;
        AssertRejected(NegativeBaffles.Validate(), "Shell.Baffles.Count");

        auto FlatBaffles = Make_TestSpec();
        FlatBaffles.Shell.Baffles.Height = 0.0f;
        AssertRejected(FlatBaffles.Validate(), "Shell.Baffles.Height");

        auto NoFriction = Make_TestSpec();
        NoFriction.Shell.Surface.Friction = 0.0f;
        AssertRejected(NoFriction.Validate(), "Shell.Surface.Friction");

        auto NoBounce = Make_TestSpec();
        NoBounce.Shell.Surface.Restitution = 0.0f;
        AssertRejected(NoBounce.Validate(), "Shell.Surface.Restitution");
    }

    private void Validate_Piece()
    {
        auto NoSize = Make_TestSpec();
        NoSize.Piece.HalfSize = 0.0f;
        AssertRejected(NoSize.Validate(), "Piece.HalfSize");

        auto TooBig = Make_TestSpec();
        TooBig.Piece.HalfSize = TooBig.Drum.InnerRadius;
        AssertRejected(TooBig.Validate(), "Piece.HalfSize");

        auto NoMass = Make_TestSpec();
        NoMass.Piece.MassKg = 0.0f;
        AssertRejected(NoMass.Validate(), "Piece.MassKg");

        auto NoFriction = Make_TestSpec();
        NoFriction.Piece.Friction = 0.0f;
        AssertRejected(NoFriction.Validate(), "Piece.Friction");

        auto NoBounce = Make_TestSpec();
        NoBounce.Piece.Restitution = 0.0f;
        AssertRejected(NoBounce.Validate(), "Piece.Restitution");

        auto NoLinearDamping = Make_TestSpec();
        NoLinearDamping.Piece.LinearDamping = 0.0f;
        AssertRejected(NoLinearDamping.Validate(), "Piece.LinearDamping");

        auto NoAngularDamping = Make_TestSpec();
        NoAngularDamping.Piece.AngularDamping = 0.0f;
        AssertRejected(NoAngularDamping.Validate(), "Piece.AngularDamping");
    }

    private void Validate_Coating()
    {
        auto NoCoating = Make_TestSpec();
        NoCoating.Coating.CoveragePerCm = 0.0f;
        AssertRejected(NoCoating.Validate(), "Coating.CoveragePerCm");

        auto NoDeadBand = Make_TestSpec();
        NoDeadBand.Coating.MinStepCm = 0.0f;
        AssertRejected(NoDeadBand.Validate(), "Coating.MinStepCm");
    }

    private void AssertRejected(const FMars_Validation& InValidation, const FString& InField)
    {
        Assert_False(InValidation.IsValid(), f"a bad {InField} is rejected");
        Assert_True(InValidation.Get_Error().Contains(InField), f"the rejection names {InField} (error: {InValidation.Get_Error()})");
    }
}
