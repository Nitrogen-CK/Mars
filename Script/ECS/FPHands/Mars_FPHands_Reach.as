// The gloves reaching for an interactable: a small lean while the player looks at it, then a full reach on Use.
// One glove or both, to the grips resolved by utils_fphands::Resolve_ReachTarget (sockets, the object's sides, or its
// interaction point). Instant interactions (pickups, switches) play a quick grab gesture; timed ones keep the gloves on
// the target until the interaction ends. The phase (EMars_FPHands_Phase) is owned by the Hands sub-HFSM.

// Looking at an interactable.
struct FMars_FPHands_FocusSpec
{
    // The gloves that would reach lean this fraction of their full reach, hands open.
    UPROPERTY()
    float32 Lean = 0.2f;

    // How quickly the lean follows (1/s).
    UPROPERTY()
    float32 InterpSpeed = 8.0f;

    // A target this close to the centre line (cm, hand node Y) keeps whichever glove already has it.
    UPROPERTY()
    float32 SideSwitchMarginCm = 10.0f;
}

// How far and how a glove stretches toward a grip.
struct FMars_FPHands_StretchSpec
{
    // Longest a glove stretches from its rest toward a grip (cm). Unset = uncapped: the first-person gloves reach whatever
    // the player can interact with, so the interaction trace distance is what bounds the reach. Set, it is a stylised look
    // cap (out of reach, the glove stretches this far toward the grip). A grip may carry its own cap:
    // FMars_FPHands_GripEntry.ReachOverrideCm.
    UPROPERTY()
    TOptional<float32> MaxReachCm;

    // Point grips (no socket): the glove stops this far short of the interaction point (cm).
    UPROPERTY()
    float32 StandoffCm = 6.0f;

    // Unauthored grips: how much of the way the glove turns to point its fingers at the grip, 0..1.
    UPROPERTY()
    float32 AimFraction = 0.6f;
}

struct FMars_FPHands_ReachPoseSpec
{
    UPROPERTY()
    EMars_HandGripPose Approach = EMars_HandGripPose::Open;

    // Contact pose when the target has none of its own (pickups use their item's GripPose).
    UPROPERTY()
    EMars_HandGripPose Contact = EMars_HandGripPose::Power;
}

// Instant interactions: reach out, close the hands, come back (seconds).
struct FMars_FPHands_GrabSpec
{
    UPROPERTY()
    float32 OutSeconds = 0.14f;

    UPROPERTY()
    float32 GripSeconds = 0.05f;

    UPROPERTY()
    float32 BackSeconds = 0.25f;

    // Curve shape of the reach out and the return, from the CkTween easing table. InOutSine is within two percent
    // of a smoothstep.
    UPROPERTY()
    ECk_TweenEasing OutEasing = ECk_TweenEasing::InOutSine;

    UPROPERTY()
    ECk_TweenEasing BackEasing = ECk_TweenEasing::InOutSine;
}

// Timed interactions: reach time, and let-go time when the interaction ends (seconds).
struct FMars_FPHands_HoldReachSpec
{
    UPROPERTY()
    float32 ReachSeconds = 0.16f;

    UPROPERTY()
    float32 ReleaseSeconds = 0.22f;

    UPROPERTY()
    ECk_TweenEasing ReachEasing = ECk_TweenEasing::InOutSine;

    UPROPERTY()
    ECk_TweenEasing ReleaseEasing = ECk_TweenEasing::InOutSine;
}

struct FMars_FPHands_ReachSpec
{
    UPROPERTY()
    FMars_FPHands_FocusSpec Focus;

    UPROPERTY()
    FMars_FPHands_StretchSpec Stretch;

    UPROPERTY()
    FMars_FPHands_ReachPoseSpec Poses;

    UPROPERTY()
    FMars_FPHands_GrabSpec Grab;

    UPROPERTY()
    FMars_FPHands_HoldReachSpec Hold;
}

// A picked-up item riding in the gloves: it stays where it lay while the gloves reach and close on it, then travels
// back to its hold offset with the gloves (the held visual otherwise spawns straight at the hold).
struct FMars_FPHands_Carry
{
    UPROPERTY()
    FTransform StartWorld;

    UPROPERTY()
    FTransform HeldOffset;
}

// Where the gloves are in their phase.
struct FMars_FPHands_PhaseState
{
    UPROPERTY()
    EMars_FPHands_Phase Phase = EMars_FPHands_Phase::None;

    // Seconds since the phase began.
    UPROPERTY()
    float32 PhaseTime = 0.0f;

    // The reach alpha when Release began (a release eases back from wherever the gloves were).
    UPROPERTY()
    float32 ReleaseFromAlpha = 1.0f;

    // The reach alpha when Reach or Hold began (0 from rest; where a release or return was when a reach interrupted it).
    UPROPERTY()
    float32 ReachFromAlpha = 0.0f;
}

namespace utils_fphands
{
    // Eased progress of one phase, shaped by the spec's easing; the 0to1 range type clamps InT.
    float32 Ease(ECk_TweenEasing InEasing, float32 InT)
    {
        return utils_tween::Get_EasedProgress(InEasing, FCk_FloatRange_0to1(InT));
    }

    // Reach, Grip and Return: the instant grab, during which a picked-up item rides in with the gloves.
    bool Get_IsGrabbing(EMars_FPHands_Phase InPhase)
    {
        return InPhase == EMars_FPHands_Phase::Reach || InPhase == EMars_FPHands_Phase::Grip || InPhase == EMars_FPHands_Phase::Return;
    }

    // 0 = gloves at rest, 1 = fully reached. Reach, Grip and Return are the grab's three time slices. Reach and Hold
    // ease out from ReachFromAlpha (0 from rest), so a reach that interrupts a release continues from where the gloves are.
    float32 Get_PhaseAlpha(const FMars_FPHands_PhaseState& InState, const FMars_FPHands_ReachSpec& InSpec)
    {
        const auto T = InState.PhaseTime;
        if (InState.Phase == EMars_FPHands_Phase::Reach)
        { return Math::Lerp(InState.ReachFromAlpha, 1.0f, Ease(InSpec.Grab.OutEasing, T / Math::Max(InSpec.Grab.OutSeconds, 0.01f))); }

        if (InState.Phase == EMars_FPHands_Phase::Grip)
        { return 1.0f; }

        if (InState.Phase == EMars_FPHands_Phase::Return)
        { return 1.0f - Ease(InSpec.Grab.BackEasing, T / Math::Max(InSpec.Grab.BackSeconds, 0.01f)); }

        if (InState.Phase == EMars_FPHands_Phase::Hold)
        { return Math::Lerp(InState.ReachFromAlpha, 1.0f, Ease(InSpec.Hold.ReachEasing, T / Math::Max(InSpec.Hold.ReachSeconds, 0.01f))); }

        if (InState.Phase == EMars_FPHands_Phase::Release)
        { return InState.ReleaseFromAlpha * (1.0f - Ease(InSpec.Hold.ReleaseEasing, T / Math::Max(InSpec.Hold.ReleaseSeconds, 0.01f))); }

        return 0.0f;
    }

    // 1 while the item waits where it lay (Reach, Grip), the return alpha during Return, 0 otherwise.
    float32 Get_PhaseCarryWeight(const FMars_FPHands_PhaseState& InState, const FMars_FPHands_ReachSpec& InSpec)
    {
        if (InState.Phase == EMars_FPHands_Phase::Reach || InState.Phase == EMars_FPHands_Phase::Grip)
        { return 1.0f; }

        if (InState.Phase == EMars_FPHands_Phase::Return)
        { return Get_PhaseAlpha(InState, InSpec); }

        return 0.0f;
    }

    // Seconds the phase lasts before the sub-SM moves on. Unset for Hold and None: they never time out.
    TOptional<float32> Get_PhaseSeconds(EMars_FPHands_Phase InPhase, const FMars_FPHands_Spec& InSpec)
    {
        if (InPhase == EMars_FPHands_Phase::Reach)
        { return TOptional<float32>(InSpec.Reach.Grab.OutSeconds); }

        if (InPhase == EMars_FPHands_Phase::Grip)
        { return TOptional<float32>(InSpec.Reach.Grab.GripSeconds); }

        if (InPhase == EMars_FPHands_Phase::Return)
        { return TOptional<float32>(InSpec.Reach.Grab.BackSeconds); }

        if (InPhase == EMars_FPHands_Phase::Release)
        { return TOptional<float32>(InSpec.Reach.Hold.ReleaseSeconds); }

        if (InPhase == EMars_FPHands_Phase::Push)
        { return TOptional<float32>(Get_PushSeconds(InSpec.Push)); }

        return TOptional<float32>();
    }

    // The glove's grip (hand node space) when fully reached from InGrip.RestGrip toward InGrip.WorldGrip. The stretch is
    // capped by the grip's ReachOverrideCm when it has one, else by the spec's MaxReachCm; neither set = the glove reaches
    // the grip. An authored grip's rotation is always matched, even when a cap leaves the glove short of it.
    FTransform Make_ReachedGrip(const FMars_FPHands_ReachSpec& InSpec, const FMars_FPHands_GripQuery& InGrip)
    {
        const auto TargetInHand = InGrip.HandWorld.InverseTransformPosition(InGrip.WorldGrip.GetLocation());
        const auto ToTarget = TargetInHand - InGrip.RestGrip.GetLocation();
        const auto Distance = ToTarget.Size();
        if (Distance < KINDA_SMALL_NUMBER)
        { return InGrip.RestGrip; }

        const auto Direction = ToTarget / Distance;
        const auto Wanted = Math::Max(Distance - InGrip.Standoff, 0.0);
        auto Cap = InSpec.Stretch.MaxReachCm;
        if (InGrip.ReachOverrideCm.IsSet())
        { Cap = InGrip.ReachOverrideCm; }

        const auto Length = Cap.IsSet() ? Math::Min(Wanted, float(Cap.GetValue())) : Wanted;

        auto Result = InGrip.RestGrip;
        Result.SetLocation(InGrip.RestGrip.GetLocation() + Direction * Length);

        if (InGrip.IsAuthored)
        { Result.SetRotation(InGrip.HandWorld.InverseTransformRotation(InGrip.WorldGrip.GetRotation())); }
        else
        {
            const auto Aim = FQuat::Slerp(FQuat::Identity, FQuat::FindBetweenNormals(FVector::ForwardVector, Direction), InSpec.Stretch.AimFraction);
            Result.SetRotation(Aim * InGrip.RestGrip.GetRotation());
        }
        return Result;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Reach state (read the feature)
//--------------------------------------------------------------------------------------------------------------------------

// 0 = gloves at rest, 1 = fully reached.
mixin float32 Get_ReachAlpha(const FCk_Handle_FPHands& Self)
{
    return utils_fphands::Get_PhaseAlpha(Self.Get_PhaseState(), Self.Get_Spec().Reach);
}

// The gloves are on this target and the reach has completed: a device may move with them.
mixin bool Get_IsGrippingTarget(const FCk_Handle_FPHands& Self, FCk_Handle_InteractTarget InTarget)
{
    return Self.Get_Phase() == EMars_FPHands_Phase::Hold
        && Self.Get_IsReachTarget(InTarget)
        && Self.Get_ReachAlpha() >= 0.999f;
}

// 1 = a picked-up item is where it lay, 0 = at its hold offset. Follows the grab.
mixin float32 Get_CarryWeight(const FCk_Handle_FPHands& Self)
{
    return utils_fphands::Get_PhaseCarryWeight(Self.Get_PhaseState(), Self.Get_Spec().Reach);
}

mixin bool Get_IsReaching(const FCk_Handle_FPHands& Self, EMars_Hand InHand)
{
    return Self.Get_Phase() != EMars_FPHands_Phase::None && utils_fphands::Get_UsesHand(Self.Get_Target(), InHand);
}

// One glove's finger pose while reaching; unset = keep the glove's own pose. The contact pose is the glove's grip's
// (a grip-table row), else the target's (a pickup's), else the spec's.
mixin TOptional<EMars_HandGripPose> TryGet_ReachPose(const FCk_Handle_FPHands& Self, EMars_Hand InHand)
{
    const auto& Spec = Self.Get_Spec();
    const auto& Poses = Spec.Reach.Poses;
    const auto Phase = Self.Get_Phase();
    const auto T = Self.Get_PhaseTime();

    auto Contact = Poses.Contact;
    const auto MaybeTarget = Self.Get_Target();
    if (MaybeTarget.IsSet())
    {
        const auto Target = MaybeTarget.GetValue();
        if (Target.ContactPose.IsSet())
        { Contact = Target.ContactPose.GetValue(); }

        const auto HandGrip = Target.Get_HandGrip(InHand);
        if (HandGrip.IsSet() && HandGrip.GetValue().Pose.IsSet())
        { Contact = HandGrip.GetValue().Pose.GetValue(); }
    }

    if (Phase == EMars_FPHands_Phase::Reach)
    { return TOptional<EMars_HandGripPose>(T < Spec.Reach.Grab.OutSeconds * 0.7f ? Poses.Approach : Contact); }

    if (Phase == EMars_FPHands_Phase::Grip)
    { return TOptional<EMars_HandGripPose>(Contact); }

    if (Phase == EMars_FPHands_Phase::Return && T < Spec.Reach.Grab.BackSeconds * 0.5f)
    { return TOptional<EMars_HandGripPose>(Contact); }

    if (Phase == EMars_FPHands_Phase::Hold)
    { return TOptional<EMars_HandGripPose>(T < Spec.Reach.Hold.ReachSeconds * 0.7f ? Poses.Approach : Contact); }

    if (Phase == EMars_FPHands_Phase::Release && T < Spec.Reach.Hold.ReleaseSeconds * 0.6f)
    { return TOptional<EMars_HandGripPose>(Poses.Approach); }

    return TOptional<EMars_HandGripPose>();
}
