// The gloves throwing a bare-fisted jab: the glove whose fist the Punch feature (on the same entity) has in flight closes
// and thrusts from where it rests toward the middle of the view, then comes home. Presentation only - the blow is dealt
// on the Punch feature's clock whatever the gloves show - and no phase of the Hands sub-SM: two jabs overlap, one glove
// going out while the other comes back.
struct FMars_FPHands_PunchSpec
{
    // How far the right glove travels at the blow, in the hand node's space (X forward, Y right, Z up): out along the
    // view, in toward its centre line (where the blow's sweep runs) and up from the low rest. The left glove mirrors Y.
    UPROPERTY()
    FVector ThrustOffset = FVector(38.0, -14.0, 10.0);

    // Each glove's grip rotation at the blow: knuckles forward, the palm turned over from the rest's palm-in to face
    // down and in.
    UPROPERTY()
    FQuat GripRotation_R = utils_fphands::Make_GripRotation(EMars_Hand::Right, FVector::ForwardVector, FVector(0.0, -0.7071, -0.7071));

    UPROPERTY()
    FQuat GripRotation_L = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, FVector(0.0, 0.7071, -0.7071));

    // The fist snaps out and eases home, across the Punch feature's own stroke times.
    UPROPERTY()
    ECk_TweenEasing OutEasing = ECk_TweenEasing::OutCubic;

    UPROPERTY()
    ECk_TweenEasing BackEasing = ECk_TweenEasing::InOutSine;

    // The finger pose of a glove whose fist is in flight.
    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Fist;
}

// One glove's share of a jab this frame.
struct FMars_FPHands_HandJab
{
    UPROPERTY()
    EMars_Hand Hand = EMars_Hand::Right;

    // 0 = at rest, 1 = at the blow.
    UPROPERTY()
    float32 Alpha = 0.0f;

    FMars_FPHands_HandJab() {}

    FMars_FPHands_HandJab(EMars_Hand InHand, float32 InAlpha)
    {
        Hand = InHand;
        Alpha = InAlpha;
    }
}

namespace utils_fphands
{
    // 0 = at rest, 1 = at the blow: a stroke's linear progress (the Punch feature's Get_StrokeAlpha) eased out and back.
    float32 Get_PunchAlpha(const FMars_FPHands_PunchSpec& InSpec, EMars_Punch_Stroke InStroke, float32 InStrokeAlpha)
    {
        if (InStroke == EMars_Punch_Stroke::Out)
        { return Ease(InSpec.OutEasing, InStrokeAlpha); }

        if (InStroke == EMars_Punch_Stroke::Back)
        { return 1.0f - Ease(InSpec.BackEasing, InStrokeAlpha); }

        return 0.0f;
    }

    // InHand's glove at the blow, from where it rests (hand node space).
    FTransform Make_PunchGrip(const FMars_FPHands_PunchSpec& InSpec, EMars_Hand InHand, const FTransform& InRestGrip)
    {
        const auto IsRight = InHand == EMars_Hand::Right;
        const auto Thrust = FVector(InSpec.ThrustOffset.X, IsRight ? InSpec.ThrustOffset.Y : -InSpec.ThrustOffset.Y, InSpec.ThrustOffset.Z);
        return FTransform(IsRight ? InSpec.GripRotation_R : InSpec.GripRotation_L, InRestGrip.GetLocation() + Thrust, FVector::OneVector);
    }

    // Lays InJab over its glove's target: the punch grip from where the glove rests, how far along it the fist is, and
    // the fist pose. A glove whose fist is home is left as it is.
    void Punch_Hand(const FMars_FPHands_PunchSpec& InSpec, const FMars_FPHands_HandJab& InJab, FMars_FPHands_HandTarget& InOutHand)
    {
        if (InJab.Alpha <= 0.0f)
        { return; }

        InOutHand.PunchGrip = Make_PunchGrip(InSpec, InJab.Hand, InOutHand.GripInHand);
        InOutHand.PunchAlpha = InJab.Alpha;
        InOutHand.Pose = InSpec.Pose;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Punch targets (read the Punch feature)
//--------------------------------------------------------------------------------------------------------------------------

// Each glove whose fist is in flight gets its punch grip, how far along it the fist is, and the fist pose. InOutTargets
// are the targets already laid out for the hold, a reach or a lean: the anim instance blends the punch over them last.
// Gloves on an entity without the Punch feature are left alone.
mixin void Apply_HandPunch(const FCk_Handle_FPHands& Self, FMars_FPHands_HandTargets& InOutTargets)
{
    FCk_Handle Carrier = Self;
    const auto Punch = Carrier.As_Punch(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(Punch))
    { return; }

    const auto& Spec = Self.Get_Spec().Punch;
    const auto Alpha_R = utils_fphands::Get_PunchAlpha(Spec, Punch.Get_Stroke(EMars_Hand::Right), Punch.Get_StrokeAlpha(EMars_Hand::Right));
    const auto Alpha_L = utils_fphands::Get_PunchAlpha(Spec, Punch.Get_Stroke(EMars_Hand::Left), Punch.Get_StrokeAlpha(EMars_Hand::Left));
    utils_fphands::Punch_Hand(Spec, FMars_FPHands_HandJab(EMars_Hand::Right, Alpha_R), InOutTargets.Right);
    utils_fphands::Punch_Hand(Spec, FMars_FPHands_HandJab(EMars_Hand::Left, Alpha_L), InOutTargets.Left);
}
