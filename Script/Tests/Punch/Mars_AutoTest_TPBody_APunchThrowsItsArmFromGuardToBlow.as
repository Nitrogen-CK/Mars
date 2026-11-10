// The body carries the fists' jabs through its arms: a fist at home leaves its arm in the locomotion pose (alpha 0); a
// fist at the blow puts its hand at the spec's Blow, laid out in the hold's hand frame, at full weight; in between the
// hand travels from Guard to Blow and the arm's weight comes in over the spec's RaiseFraction. The left arm mirrors the
// right across the body, and each hand takes the punch rotation it is given. A RaiseFraction of zero does not validate.
class UMars_AutoTest_TPBody_APunchThrowsItsArmFromGuardToBlow : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a jab throws its arm from guard to blow", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = FMars_TPBody_PunchQuery();
        Query.Hold = FMars_TPBody_Hold();
        Query.Punch = FMars_TPBody_Punch();
        const auto& Punch = Query.Punch;
        const auto& Frame = Query.Hold.HandFrame;

        // Both fists home: neither arm is raised.
        const auto Home = utils_held_view::Make_PunchFrame(Query);
        Assert_Equals_Float(Home.Right.Alpha, 0.0f, 0.0001f, "a right fist at home leaves its arm alone");
        Assert_Equals_Float(Home.Left.Alpha, 0.0f, 0.0001f, "a left fist at home leaves its arm alone");
        Assert_True(Home.Right.HandLocation.Equals(Frame.TransformPosition(Punch.Guard), 0.01), "a fist at home sits at the guard");

        // The right at the blow, the left half way through its raise.
        auto Thrown = Query;
        Thrown.Right.Alpha = 1.0f;
        Thrown.Left.Alpha = Punch.RaiseFraction * 0.5f;
        const auto Jab = utils_held_view::Make_PunchFrame(Thrown);

        Assert_Equals_Float(Jab.Right.Alpha, 1.0f, 0.0001f, "the arm of a fist at the blow has full weight");
        Assert_True(Jab.Right.HandLocation.Equals(Frame.TransformPosition(Punch.Blow), 0.01),
            f"the right hand is at the blow, laid out in the hand frame (got [{Jab.Right.HandLocation}])");
        Assert_True(Jab.Right.ElbowTarget.Equals(Query.Hold.ElbowOffset_R, 0.0001), "the right elbow keeps the hold's pole target");

        const auto GuardLeft = FVector(Punch.Guard.X, -Punch.Guard.Y, Punch.Guard.Z);
        const auto BlowLeft = FVector(Punch.Blow.X, -Punch.Blow.Y, Punch.Blow.Z);
        const auto ExpectedLeft = Frame.TransformPosition(Math::Lerp(GuardLeft, BlowLeft, float(Thrown.Left.Alpha)));
        Assert_Equals_Float(Jab.Left.Alpha, 0.5f, 0.0001f, "half way through the raise the arm has half its weight");
        Assert_True(Jab.Left.HandLocation.Equals(ExpectedLeft, 0.01),
            f"the left hand travels the mirrored guard-to-blow line (got [{Jab.Left.HandLocation}], expected [{ExpectedLeft}])");
        Assert_True(Jab.Left.ElbowTarget.Equals(Query.Hold.ElbowOffset_L, 0.0001), "the left elbow keeps the hold's pole target");

        // The hand frame's Y is the chef's right, component -X: the two guards sit either side of the body.
        Assert_True(Home.Right.HandLocation.X < 0.0 && Home.Left.HandLocation.X > 0.0,
            f"the right guard is on the chef's right and the left on its left (right x [{Home.Right.HandLocation.X}], left x [{Home.Left.HandLocation.X}])");

        // A punch rotation turns the hand.
        auto Turned = Thrown;
        Turned.Right.GripRotation = FQuat(FRotator(0.0, 0.0, 90.0));
        const auto TurnedJab = utils_held_view::Make_PunchFrame(Turned);
        Assert_True(TurnedJab.Right.HandRotation.Equals(Jab.Right.HandRotation, 0.01) == false, "a punch rotation turns the hand");
        Assert_True(TurnedJab.Right.HandLocation.Equals(Jab.Right.HandLocation, 0.01), "and leaves it where it was");

        Assert_True(FMars_TPBody_Punch().Validate().IsValid(), "the default punch validates");
        Assert_True(mars::Mars_PlayerCharacter_Config.TPBody.Punch.Validate().IsValid(), "the player's configured punch validates");
        auto NoRaise = FMars_TPBody_Punch();
        NoRaise.RaiseFraction = 0.0f;
        Assert_False(NoRaise.Validate().IsValid(), "a zero raise fraction does not validate");
    }
}
