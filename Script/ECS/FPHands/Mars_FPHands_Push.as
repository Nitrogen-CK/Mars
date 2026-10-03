// The gloves following through a drop or throw: the item launches the moment the button is released, and the gloves
// that held it thrust after it from the hold they had, open, and come back. Presentation only - the launch never waits
// on the gloves. The phase (EMars_FPHands_Phase::Push) is owned by the Hands sub-HFSM.
struct FMars_FPHands_PushSpec
{
    // How far the pushing gloves travel at full extension, in the hand node's space (X forward, Z up).
    UPROPERTY()
    FVector ThrowOffset = FVector(30.0, 0.0, 5.0);

    UPROPERTY()
    FVector DropOffset = FVector(14.0, 0.0, -4.0);

    UPROPERTY()
    float32 OutSeconds = 0.08f;

    UPROPERTY()
    float32 BackSeconds = 0.24f;

    UPROPERTY()
    ECk_TweenEasing OutEasing = ECk_TweenEasing::OutCubic;

    UPROPERTY()
    ECk_TweenEasing BackEasing = ECk_TweenEasing::InOutSine;

    // The fingers let go this far into the thrust (0..1 of OutSeconds), then hold ReleasePose until the push ends.
    UPROPERTY()
    float32 OpenAtOutFraction = 0.4f;

    UPROPERTY()
    EMars_HandGripPose ReleasePose = EMars_HandGripPose::Open;
}

// One glove's share of a push this frame.
struct FMars_FPHands_HandPush
{
    UPROPERTY()
    FVector Offset;

    UPROPERTY()
    float32 Alpha = 0.0f;

    UPROPERTY()
    bool IsReleased = false;

    FMars_FPHands_HandPush() {}

    FMars_FPHands_HandPush(FVector InOffset, float32 InAlpha, bool InIsReleased)
    {
        Offset = InOffset;
        Alpha = InAlpha;
        IsReleased = InIsReleased;
    }
}

namespace utils_fphands
{
    // 0 = at the hold, 1 = fully thrust out: out over OutSeconds, back over BackSeconds.
    float32 Get_PushAlpha(const FMars_FPHands_PushSpec& InSpec, float32 InPhaseTime)
    {
        const auto OutSeconds = Math::Max(InSpec.OutSeconds, 0.01f);
        if (InPhaseTime < OutSeconds)
        { return Ease(InSpec.OutEasing, InPhaseTime / OutSeconds); }

        return 1.0f - Ease(InSpec.BackEasing, (InPhaseTime - OutSeconds) / Math::Max(InSpec.BackSeconds, 0.01f));
    }

    float32 Get_PushSeconds(const FMars_FPHands_PushSpec& InSpec)
    {
        return InSpec.OutSeconds + InSpec.BackSeconds;
    }

    FVector Get_PushOffset(const FMars_FPHands_PushSpec& InSpec, EMars_LaunchKind InKind)
    {
        if (InKind == EMars_LaunchKind::Throw)
        { return InSpec.ThrowOffset; }

        return InSpec.DropOffset;
    }

    // Through the reach channel, which the anim instance blends after its grip easing, so the thrust stays crisp.
    void Push_Hand(const FMars_FPHands_PushSpec& InSpec, const FMars_FPHands_HandPush& InPush, FMars_FPHands_HandTarget& InOutHand)
    {
        InOutHand.ReachGrip = InOutHand.GripInHand;
        InOutHand.ReachGrip.SetLocation(InOutHand.GripInHand.GetLocation() + InPush.Offset);
        InOutHand.ReachAlpha = InPush.Alpha;
        InOutHand.Swing = FVector::ZeroVector;
        if (InPush.IsReleased)
        { InOutHand.Pose = InSpec.ReleasePose; }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Push targets (read the feature)
//--------------------------------------------------------------------------------------------------------------------------

// The gloves that held the launched item thrust along the push offset; the free off-hand of a one-handed hold keeps its
// rest. InOutTargets are the rest targets of the hold being pushed.
mixin void Apply_HandPush(const FCk_Handle_FPHands& Self, FMars_FPHands_HandTargets& InOutTargets)
{
    const auto& Spec = Self.Get_Spec().Push;
    const auto Hold = Self.Get_PushHold();
    const auto PhaseTime = Self.Get_PhaseTime();
    const auto Push = FMars_FPHands_HandPush(
        utils_fphands::Get_PushOffset(Spec, Self.Get_PushKind()),
        utils_fphands::Get_PushAlpha(Spec, PhaseTime),
        PhaseTime >= Spec.OutSeconds * Spec.OpenAtOutFraction);

    utils_fphands::Push_Hand(Spec, Push, InOutTargets.Right);
    if (Hold.Kind != EMars_FPHands_HoldKind::OneHanded)
    { utils_fphands::Push_Hand(Spec, Push, InOutTargets.Left); }
}
