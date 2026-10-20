// The body carries the hand swing through its hold frame: a swing offset (hand space, world cm) moves both hands by that
// offset laid out in the hand frame and shrunk to body units, so the body's hands travel where the owner's gloves do;
// the elbow pole targets follow SwingElbowFollow of that displacement; a swing rotation turns the hands; an identity
// swing changes nothing.
class UMars_AutoTest_TPBody_SwingMovesTheHoldFrame : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the swing moves the hold frame", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Grip = FMars_HeldView_Grip();
        Grip.Kind = EMars_FPHands_HoldKind::TwoHanded;
        Grip.RightFaceY = 15.0;
        Grip.LeftFaceY = -15.0;

        auto Query = FMars_TPBody_HoldQuery();
        Query.Grips = utils_held_view::Get_GripTargets(FMars_FPHands_Spec(), Grip);
        Query.Kind = EMars_FPHands_HoldKind::TwoHanded;
        Query.Hold = FMars_TPBody_Hold();
        Query.BodyScale = 1.6453f;

        // Rest is the query as built (no swing set); the identity query sets the swing explicitly.
        const auto Rest = utils_held_view::Make_HoldFrame(Query);
        auto Identity = Query;
        Identity.Swing = FTransform::Identity;
        const auto IdentityFrame = utils_held_view::Make_HoldFrame(Identity);
        Assert_True(IdentityFrame.Right.HandLocation.Equals(Rest.Right.HandLocation, 0.0001) &&
            IdentityFrame.Left.HandLocation.Equals(Rest.Left.HandLocation, 0.0001), "an identity swing leaves both hands");
        Assert_True(IdentityFrame.Right.HandRotation.Equals(Rest.Right.HandRotation, 0.0001) &&
            IdentityFrame.Left.HandRotation.Equals(Rest.Left.HandRotation, 0.0001), "an identity swing leaves both hand rotations");
        Assert_True(IdentityFrame.Right.ElbowTarget.Equals(Rest.Right.ElbowTarget, 0.0001) &&
            IdentityFrame.Left.ElbowTarget.Equals(Rest.Left.ElbowTarget, 0.0001), "an identity swing leaves both elbows");

        const auto SwingLocation = FVector(10.0, 0.0, 20.0);
        auto Swung = Query;
        Swung.Swing = FTransform(FRotator::ZeroRotator, SwingLocation, FVector::OneVector);
        const auto Frame = utils_held_view::Make_HoldFrame(Swung);

        // Hand +X is the chef's forward (component +Y), hand +Z is up; the hand frame's yaw lays the offset out.
        const auto Expected = Query.Hold.HandFrame.TransformVector(SwingLocation / float(Query.BodyScale));
        const auto DeltaR = Frame.Right.HandLocation - Rest.Right.HandLocation;
        const auto DeltaL = Frame.Left.HandLocation - Rest.Left.HandLocation;
        Assert_True(DeltaR.Equals(Expected, 0.01), f"the right hand moves by the swing in body units (got [{DeltaR}], expected [{Expected}])");
        Assert_True(DeltaL.Equals(Expected, 0.01), f"the left hand moves with it (got [{DeltaL}])");
        Assert_True(Frame.Right.HandRotation.Equals(Rest.Right.HandRotation, 0.01), "a pure translation leaves the hand rotation");

        const auto ElbowDelta = Frame.Right.ElbowTarget - Rest.Right.ElbowTarget;
        Assert_True(ElbowDelta.Equals(Expected * Query.Hold.SwingElbowFollow, 0.01),
            f"the elbow follows SwingElbowFollow of the displacement (got [{ElbowDelta}])");

        auto Turned = Query;
        Turned.Swing = FTransform(FRotator(-50.0, 0.0, 0.0), FVector::ZeroVector, FVector::OneVector);
        const auto TurnedFrame = utils_held_view::Make_HoldFrame(Turned);
        Assert_True(TurnedFrame.Right.HandRotation.Equals(Rest.Right.HandRotation, 0.01) == false, "a swing rotation turns the hand");
        Assert_True(TurnedFrame.Right.ElbowTarget.Equals(Rest.Right.ElbowTarget, 0.0001), "a pure rotation leaves the elbow");

        auto Hold = FMars_TPBody_Hold();
        Hold.SwingElbowFollow = 1.5f;
        Assert_False(Hold.Validate().IsValid(), "an elbow follow past 1 does not validate");
    }
}
