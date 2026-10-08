// Validate() accepts the rig's spec and rejects a kernel that takes no piece, a piece with no size, a basket with no
// interior, a scoop with no bowl, a dip not below the carry, a face that never goes golden, a piece restitution of 1.5, a
// pot too narrow for the scoop, a receiver that never drains or drops its contact at once, and a reach with no corridor,
// no basket box or no look.
class UMars_AutoTest_Fry_SpecValidateRejectsBadSpecs : UMars_AutoTestRig_Fry
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the rig's spec and thirteen bad ones", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_TestSpec().Validate();
        Assert_True(Good.IsValid(), f"the rig's spec is accepted (error: {Good.Get_Error()})");

        auto NoPieces = Make_TestSpec();
        NoPieces.Supply.MaxPieces = 0;
        AssertRejected(NoPieces.Validate(), "Supply.MaxPieces 0");

        auto NoSize = Make_TestSpec();
        NoSize.Piece.HalfSize = 0.0f;
        AssertRejected(NoSize.Validate(), "a Piece.HalfSize <= 0");

        auto NoInterior = Make_TestSpec();
        NoInterior.Basket.InnerHalfX = 0.0f;
        AssertRejected(NoInterior.Validate(), "a basket InnerHalfX <= 0");

        auto NoBowl = Make_TestSpec();
        NoBowl.Scoop.BowlRadius = 0.0f;
        AssertRejected(NoBowl.Validate(), "a scoop BowlRadius <= 0");

        auto DipAboveCarry = Make_TestSpec();
        DipAboveCarry.Scoop.DipLift = DipAboveCarry.Scoop.CarryLift;
        AssertRejected(DipAboveCarry.Validate(), "a scoop DipLift not below its CarryLift");

        auto NeverGolden = Make_TestSpec();
        NeverGolden.Heat.GoldenSeconds = 0.0f;
        AssertRejected(NeverGolden.Validate(), "Heat.GoldenSeconds <= 0");

        auto Bouncy = Make_TestSpec();
        Bouncy.Piece.Restitution = 1.5f;
        AssertRejected(Bouncy.Validate(), "a Piece.Restitution of 1.5");

        auto NarrowPot = Make_TestSpec();
        NarrowPot.Zones.PotRadius = NarrowPot.Scoop.BowlRadius + NarrowPot.Scoop.LipThickness;
        AssertRejected(NarrowPot.Validate(), "a Zones.PotRadius that leaves the scoop no room");

        auto NeverDrains = Make_TestSpec();
        NeverDrains.Receiver.DrainSeconds = 0.0f;
        AssertRejected(NeverDrains.Validate(), "Receiver.DrainSeconds <= 0");

        auto NoGrace = Make_TestSpec();
        NoGrace.Receiver.SupportGraceSeconds = 0.0f;
        AssertRejected(NoGrace.Validate(), "Receiver.SupportGraceSeconds <= 0");

        auto NoCorridor = Make_TestSpec();
        NoCorridor.Reach.CorridorHalfExtent = FVector2D(0.0, 30.0);
        AssertRejected(NoCorridor.Validate(), "a Reach.CorridorHalfExtent with no width");

        auto NoBasketBox = Make_TestSpec();
        NoBasketBox.Reach.BasketHalfExtent = FVector2D(22.0, 0.0);
        AssertRejected(NoBasketBox.Validate(), "a Reach.BasketHalfExtent with no depth");

        auto NoLook = Make_TestSpec();
        NoLook.Reach.CmPerLookDegree = 0.0f;
        AssertRejected(NoLook.Validate(), "Reach.CmPerLookDegree 0");
    }

    private void AssertRejected(const FMars_Validation& InValidation, const FString& InRule)
    {
        Assert_False(InValidation.IsValid(), f"{InRule} is rejected");
        Assert_True(InValidation.Get_Error().Len() > 0, f"the {InRule} rejection names its rule (error: {InValidation.Get_Error()})");
    }
}
