// Station-frame authoring of a feeding station: where the free glove rests, the slot poses (where the raw proxies sit; the
// glove grasps each from above), where a held piece sits in the glove's frame, the clearance it lifts to before and after a
// grasp, and the arc height of the carry.
struct FMars_StationFeed_Geometry
{
    // The glove's rest; its rotation is the glove's for the whole transfer.
    UPROPERTY()
    FTransform RestLocal;

    UPROPERTY()
    TArray<FTransform> SlotsLocal;

    // The held piece in the glove node's frame: the glove stops where this puts the piece on a slot or on the release node.
    UPROPERTY()
    FTransform HeldLocal;

    UPROPERTY()
    float32 PickupClearance = 6.0f;

    UPROPERTY()
    float32 CarryArcHeight = 10.0f;
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
// clock of its own: the glove node's offset, the left glove's pose override and which piece rides the glove all follow the
// feed's phase and progress.
struct FMars_StationFeed_Presentation
{
    FMars_StationFeed_Geometry Geometry;

    // The Station.Node.Feed node (created by the station under its root): the free glove's grip follows it.
    FCk_Handle_SceneNode HandNode;

    // The offset last written (written only on change).
    FTransform WrittenHand;

    // Whose proxy rides the glove: Grasp through AwaitAdmission.
    TOptional<FMars_CookingFeed_PieceId> CarriedPiece;

    // The override last sent to PosedOperator's left glove.
    TOptional<EMars_HandGripPose> AppliedPose;

    FCk_Handle PosedOperator;
}

// Moves the glove node (rest -> slot -> clearance -> release node -> rest, InOutSine per segment; the release node is
// re-sampled every frame, the pan moves), sets the operator's LEFT pose override (Open while reaching and returning, Cradle
// from Grasp through AwaitAdmission, cleared once idle) and records which piece rides the glove.
mixin void Advance(FMars_StationFeed_Presentation& Self, const FMars_StationFeed_Frame& InFrame)
{
    if (ck::Is_NOT_Valid(InFrame.Feed))
    { return; }

    const auto Phase = InFrame.Feed.Get_Phase();
    const auto Active = InFrame.Feed.TryGet_ActivePiece();
    const auto IsHolding = Phase == EMars_CookingFeed_Phase::Grasp || Phase == EMars_CookingFeed_Phase::Carry
        || Phase == EMars_CookingFeed_Phase::AwaitAdmission;

    Self.CarriedPiece = IsHolding ? Active : TOptional<FMars_CookingFeed_PieceId>();
    Self.Write_Hand(Self.Get_HandLocal(InFrame));
    Self.Apply_Pose(InFrame.Operator, Self.Get_Pose(Phase));
}

// Exit or teardown: the override is cleared on the gloves it was sent to (else InOperator's), the glove node parks at rest
// and nothing rides it.
mixin void Clear(FMars_StationFeed_Presentation& Self, FCk_Handle InOperator)
{
    if (ck::Is_NOT_Valid(Self.PosedOperator))
    { Self.PosedOperator = InOperator; }

    Self.Clear_PoseOverride();
    Self.CarriedPiece.Reset();

    if (ck::IsValid(Self.HandNode))
    { Self.Write_Hand(Self.Geometry.RestLocal); }
}

// A free slot shows its piece; a taken one hides it, except the reserved slot until the glove grasps its piece.
mixin bool Get_IsSlotVisible(const FMars_StationFeed_Presentation& Self, const FCk_Handle_CookingFeed& InFeed, int32 InSlot)
{
    if (InFeed.Get_IsSlotTaken(InSlot) == false)
    { return true; }

    const auto Active = InFeed.TryGet_ActivePiece();
    return Active.IsSet() && Active.GetValue().StockIndex == InSlot && Self.CarriedPiece.IsSet() == false;
}

// The glove node's offset this frame, in the station frame.
mixin FTransform Get_HandLocal(const FMars_StationFeed_Presentation& Self, const FMars_StationFeed_Frame& InFrame)
{
    const auto& Geometry = Self.Geometry;
    const auto Rotation = Geometry.RestLocal.GetRotation();
    const auto Rest = Geometry.RestLocal.GetLocation();
    const auto Phase = InFrame.Feed.Get_Phase();
    const auto Alpha = float64(InFrame.Feed.Get_PhaseProgress());
    const auto Eased = 0.5 - 0.5 * Math::Cos(PI * Alpha);
    const auto Arc = Math::Sin(PI * Eased);
    const auto Up = FVector::UpVector;
    const auto PickupClearance = float64(Geometry.PickupClearance);

    // Where the glove puts the held piece on a station-frame point.
    const auto HeldOffset = Rotation.RotateVector(Geometry.HeldLocal.GetLocation());
    const auto Grasp = Self.Get_SlotLocal(InFrame.Feed) - HeldOffset;
    const auto Lifted = Grasp + Up * PickupClearance;
    const auto ReleaseWorld = utils_transform::Get_EntityCurrentLocation(InFrame.Feed.Get_ReleaseNode());
    const auto Release = InFrame.RootWorld.InverseTransformPosition(ReleaseWorld) - HeldOffset;

    auto Location = Rest;
    if (Phase == EMars_CookingFeed_Phase::Reach)
    { Location = Math::Lerp(Rest, Grasp, Eased) + Up * (PickupClearance * Arc); }
    else if (Phase == EMars_CookingFeed_Phase::Grasp)
    { Location = Math::Lerp(Grasp, Lifted, Eased); }
    else if (Phase == EMars_CookingFeed_Phase::Carry)
    { Location = Math::Lerp(Lifted, Release, Eased) + Up * (float64(Geometry.CarryArcHeight) * Arc); }
    else if (Phase == EMars_CookingFeed_Phase::AwaitAdmission)
    { Location = Release; }
    else if (Phase == EMars_CookingFeed_Phase::Return)
    { Location = Math::Lerp(Release, Rest, Eased) + Up * (PickupClearance * Arc); }

    return FTransform(Rotation, Location);
}

// The reserved slot's centre (station frame); the rest location without a reservation or an authored slot for it.
mixin FVector Get_SlotLocal(const FMars_StationFeed_Presentation& Self, const FCk_Handle_CookingFeed& InFeed)
{
    const auto Active = InFeed.TryGet_ActivePiece();
    if (Active.IsSet() == false || Self.Geometry.SlotsLocal.IsValidIndex(Active.GetValue().StockIndex) == false)
    { return Self.Geometry.RestLocal.GetLocation(); }

    return Self.Geometry.SlotsLocal[Active.GetValue().StockIndex].GetLocation();
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

mixin void Write_Hand(FMars_StationFeed_Presentation& Self, FTransform InLocal)
{
    if (ck::Is_NOT_Valid(Self.HandNode) || InLocal.Equals(Self.WrittenHand, 0.01))
    { return; }

    utils_scene_node::Request_UpdateOffset(Self.HandNode, FCk_Request_SceneNode_UpdateRelativeTransform(InLocal));
    Self.WrittenHand = InLocal;
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
