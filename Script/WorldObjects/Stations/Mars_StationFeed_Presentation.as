// Station-frame authoring of a feeding station: where the free glove rests, where a held piece sits in the glove's frame
// (the station hands it to its feed as Motion.HeldOffset, so the real piece rides the glove there), the clearance it lifts
// to before and after a grasp, and the arc height of the carry. The glove grasps the reserved piece where it lies on the
// source platter, from above. Make_HandGeometry turns it into the feed's hand geometry.
struct FMars_StationFeed_Geometry
{
    // The glove's rest; its rotation is the glove's for the whole transfer.
    UPROPERTY()
    FTransform RestLocal;

    // The held piece's middle in the glove node's frame: the glove stops where this puts it on the reserved piece's middle or
    // on the release node.
    UPROPERTY()
    FTransform HeldLocal;

    UPROPERTY()
    float32 PickupClearance = 6.0f;

    UPROPERTY()
    float32 CarryArcHeight = 10.0f;
}

// The feed's hand geometry for this authoring: the glove rests at RestLocal and keeps its rotation throughout, and stops
// HeldLocal's middle (turned into the station frame by that rotation) short of the piece's middle and of the release node,
// so the held piece's middle lands on them.
mixin FMars_CookingFeed_HandGeometry Make_HandGeometry(const FMars_StationFeed_Geometry& Self)
{
    const auto Rotation = Self.RestLocal.GetRotation();
    const auto HeldOffset = Rotation.RotateVector(Self.HeldLocal.GetLocation());

    auto Hand = FMars_CookingFeed_HandGeometry();
    Hand.RestLocal = Self.RestLocal;
    Hand.GraspLocal = FTransform(Rotation, -HeldOffset);
    Hand.ReleaseLocal = FTransform(Rotation, -HeldOffset);
    Hand.ClearanceCm = Self.PickupClearance;
    Hand.CarryArcCm = Self.CarryArcHeight;
    return Hand;
}

// One glove's pose override, sent only when it changes (InHand: the left glove follows the feed; a station may keep
// another for its own glove). The station script owns it and samples, never writes, what it follows; it keeps no clock.
struct FMars_StationFeed_Presentation
{
    EMars_Hand Hand = EMars_Hand::Left;

    // The override last sent to PosedOperator's glove.
    TOptional<EMars_HandGripPose> AppliedPose;

    FCk_Handle PosedOperator;
}

namespace utils_station
{
    // The feed's glove: Open while reaching and returning, Cradle from Grasp through AwaitAdmission, no override (unset)
    // while idle.
    TOptional<EMars_HandGripPose> Get_FeedGlovePose(EMars_CookingFeed_Phase InPhase)
    {
        if (InPhase == EMars_CookingFeed_Phase::Idle)
        { return TOptional<EMars_HandGripPose>(); }

        if (InPhase == EMars_CookingFeed_Phase::Reach || InPhase == EMars_CookingFeed_Phase::Return)
        { return TOptional<EMars_HandGripPose>(EMars_HandGripPose::Open); }

        return TOptional<EMars_HandGripPose>(EMars_HandGripPose::Cradle);
    }
}

// InOperator's glove follows InFeed's phase (InOperator invalid while nobody operates).
mixin void Advance(FMars_StationFeed_Presentation& Self, FCk_Handle_CookingFeed InFeed, FCk_Handle InOperator)
{
    if (ck::Is_NOT_Valid(InFeed))
    { return; }

    Self.Apply_Pose(InOperator, utils_station::Get_FeedGlovePose(InFeed.Get_Phase()));
}

// Exit or teardown: the override is cleared on the gloves it was sent to (else InOperator's).
mixin void Clear(FMars_StationFeed_Presentation& Self, FCk_Handle InOperator)
{
    if (ck::Is_NOT_Valid(Self.PosedOperator))
    { Self.PosedOperator = InOperator; }

    Self.Clear_PoseOverride();
}

// Sends the override only when it changes; a different operator (or none) first gets the old one cleared.
mixin void Apply_Pose(FMars_StationFeed_Presentation& Self, FCk_Handle InOperator, TOptional<EMars_HandGripPose> InPose)
{
    if (Self.PosedOperator != InOperator)
    { Self.Clear_PoseOverride(); }

    if (InPose == Self.AppliedPose)
    { return; }

    auto Hands = InOperator.As_FPHands(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(Hands))
    { return; }

    Hands.Request_SetPoseOverride(FMars_Request_FPHands_SetPoseOverride(Self.Hand, InPose));
    Self.AppliedPose = InPose;
    Self.PosedOperator = InOperator;
}

// Unsets the override on the gloves it was sent to (gloves already gone need nothing).
mixin void Clear_PoseOverride(FMars_StationFeed_Presentation& Self)
{
    if (Self.AppliedPose.IsSet())
    {
        auto Hands = Self.PosedOperator.As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Hands))
        { Hands.Request_SetPoseOverride(FMars_Request_FPHands_SetPoseOverride(Self.Hand, TOptional<EMars_HandGripPose>())); }
    }

    Self.AppliedPose.Reset();
    Self.PosedOperator = FCk_Handle();
}
