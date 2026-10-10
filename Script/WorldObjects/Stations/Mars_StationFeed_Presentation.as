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

// What one presentation frame reads: the feed, the station's operator (invalid while nobody operates), the station root's
// world transform and the frame's real time.
struct FMars_StationFeed_Frame
{
    FCk_Handle_CookingFeed Feed;
    FCk_Handle Operator;
    FTransform RootWorld;
    float32 DeltaSeconds = 0.0f;

    FMars_StationFeed_Frame() {}

    FMars_StationFeed_Frame(FCk_Handle_CookingFeed InFeed, FCk_Handle InOperator, FTransform InRootWorld, float32 InDeltaSeconds)
    {
        Feed = InFeed;
        Operator = InOperator;
        RootWorld = InRootWorld;
        DeltaSeconds = InDeltaSeconds;
    }
}

// The station script owns one and advances it from its dressing tick. It samples the feed (never writes it) and keeps no
// clock of its own: the left glove's pose override follows the feed's phase. The glove follows the feed's hand node
// (Station.Node.Feed), which the feed moves itself by its hand geometry.
struct FMars_StationFeed_Presentation
{
    // The override last sent to PosedOperator's left glove.
    TOptional<EMars_HandGripPose> AppliedPose;

    FCk_Handle PosedOperator;
}

// Sets the operator's LEFT pose override: Open while reaching and returning, Cradle from Grasp through AwaitAdmission,
// cleared once idle.
mixin void Advance(FMars_StationFeed_Presentation& Self, const FMars_StationFeed_Frame& InFrame)
{
    if (ck::Is_NOT_Valid(InFrame.Feed))
    { return; }

    Self.Apply_Pose(InFrame.Operator, Self.Get_Pose(InFrame.Feed.Get_Phase()));
}

// Exit or teardown: the override is cleared on the gloves it was sent to (else InOperator's).
mixin void Clear(FMars_StationFeed_Presentation& Self, FCk_Handle InOperator)
{
    if (ck::Is_NOT_Valid(Self.PosedOperator))
    { Self.PosedOperator = InOperator; }

    Self.Clear_PoseOverride();
}

// Unset = no override (idle).
mixin TOptional<EMars_HandGripPose> Get_Pose(const FMars_StationFeed_Presentation& Self, EMars_CookingFeed_Phase InPhase)
{
    if (InPhase == EMars_CookingFeed_Phase::Idle)
    { return TOptional<EMars_HandGripPose>(); }

    if (InPhase == EMars_CookingFeed_Phase::Reach || InPhase == EMars_CookingFeed_Phase::Return)
    { return TOptional<EMars_HandGripPose>(EMars_HandGripPose::Open); }

    return TOptional<EMars_HandGripPose>(EMars_HandGripPose::Cradle);
}

// Sends the override only when it changes; a different operator first gets the old one cleared.
mixin void Apply_Pose(FMars_StationFeed_Presentation& Self, FCk_Handle InOperator, TOptional<EMars_HandGripPose> InPose)
{
    if (Self.PosedOperator != InOperator)
    { Self.Clear_PoseOverride(); }

    if (InPose == Self.AppliedPose)
    { return; }

    auto Hands = InOperator.As_FPHands(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(Hands))
    { return; }

    Hands.Request_SetPoseOverride(FMars_Request_FPHands_SetPoseOverride(EMars_Hand::Left, InPose));
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
        { Hands.Request_SetPoseOverride(FMars_Request_FPHands_SetPoseOverride(EMars_Hand::Left, TOptional<EMars_HandGripPose>())); }
    }

    Self.AppliedPose.Reset();
    Self.PosedOperator = FCk_Handle();
}
