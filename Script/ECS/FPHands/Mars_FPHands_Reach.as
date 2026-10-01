// The gloves reaching for an interactable: a small lean while the player looks at it, then a full reach on Use.
// One glove or both, to the grips resolved by utils_fphands::Resolve_ReachTarget (sockets, the object's sides, or its
// interaction point). Instant interactions (pickups, switches) play a quick grab gesture; timed ones keep the gloves on
// the target until the interaction ends. The phase (EMars_FPHands_Phase) is owned by the Hands sub-HFSM.
struct FMars_FPHands_ReachSpec
{
    // Looking at an interactable: the gloves that would reach lean this fraction of their full reach, hands open.
    UPROPERTY(Category = "Focus")
    float32 FocusLean = 0.2f;

    // How quickly the focus lean follows (1/s).
    UPROPERTY(Category = "Focus")
    float32 FocusInterpSpeed = 8.0f;

    // A target this close to the centre line (cm, hand node Y) keeps whichever glove already has it.
    UPROPERTY(Category = "Focus")
    float32 SideSwitchMarginCm = 10.0f;

    // Longest a glove stretches from its rest toward a grip (cm). Stylised long reach.
    UPROPERTY(Category = "Reach")
    float32 MaxReachCm = 60.0f;

    // Point grips (no socket): the glove stops this far short of the interaction point (cm).
    UPROPERTY(Category = "Reach")
    float32 StandoffCm = 6.0f;

    // Unauthored grips: how much of the way the glove turns to point its fingers at the grip, 0..1.
    UPROPERTY(Category = "Reach")
    float32 AimFraction = 0.6f;

    UPROPERTY(Category = "Reach")
    EMars_HandGripPose ApproachPose = EMars_HandGripPose::Open;

    // Contact pose when the target has none of its own (pickups use their item's GripPose).
    UPROPERTY(Category = "Reach")
    EMars_HandGripPose ContactPose = EMars_HandGripPose::Power;

    // Instant interactions: reach out, close the hands, come back (seconds).
    UPROPERTY(Category = "Grab")
    float32 GrabOutSeconds = 0.14f;

    UPROPERTY(Category = "Grab")
    float32 GrabGripSeconds = 0.12f;

    UPROPERTY(Category = "Grab")
    float32 GrabBackSeconds = 0.25f;

    // Curve shape of the reach out and the return, from the CkTween easing table. InOutSine is within two percent
    // of the smoothstep the gloves shipped with.
    UPROPERTY(Category = "Grab")
    ECk_TweenEasing GrabOutEasing = ECk_TweenEasing::InOutSine;

    UPROPERTY(Category = "Grab")
    ECk_TweenEasing GrabBackEasing = ECk_TweenEasing::InOutSine;

    // Timed interactions: reach time, and let-go time when the interaction ends (seconds).
    UPROPERTY(Category = "Hold")
    float32 HoldReachSeconds = 0.16f;

    UPROPERTY(Category = "Hold")
    float32 ReleaseSeconds = 0.22f;

    UPROPERTY(Category = "Hold")
    ECk_TweenEasing HoldReachEasing = ECk_TweenEasing::InOutSine;

    UPROPERTY(Category = "Hold")
    ECk_TweenEasing ReleaseEasing = ECk_TweenEasing::InOutSine;
}

// A picked-up item riding in the gloves: it stays where it lay while the gloves reach and close on it, then travels
// back to its hold offset with the gloves (the held visual otherwise spawns straight at the hold).
struct FMars_FPHands_Carry
{
    UPROPERTY()
    bool IsActive = false;

    UPROPERTY()
    FTransform StartWorld;

    UPROPERTY()
    FTransform HeldOffset;
}

// Where the gloves are in their phase: what the reach math reads from the feature's state.
struct FMars_FPHands_PhaseState
{
    UPROPERTY()
    EMars_FPHands_Phase Phase = EMars_FPHands_Phase::None;

    // Seconds since the phase began.
    UPROPERTY()
    float32 PhaseTime = 0.0f;

    // The reach alpha when Release began.
    UPROPERTY()
    float32 ReleaseFromAlpha = 1.0f;

    FMars_FPHands_PhaseState() {}

    FMars_FPHands_PhaseState(EMars_FPHands_Phase InPhase, float32 InPhaseTime, float32 InReleaseFromAlpha)
    {
        Phase = InPhase;
        PhaseTime = InPhaseTime;
        ReleaseFromAlpha = InReleaseFromAlpha;
    }
}

namespace utils_fphands
{
    // Eased progress of one phase, shaped by the spec's easing; the 0to1 range type clamps InT.
    float32 Ease(ECk_TweenEasing InEasing, float32 InT)
    {
        return utils_tween::Get_EasedProgress(InEasing, FCk_FloatRange_0to1(InT));
    }

    // 0 = gloves at rest, 1 = fully reached. Reach, Grip and Return are the grab's three time slices.
    float32 Get_PhaseAlpha(const FMars_FPHands_PhaseState& InState, const FMars_FPHands_ReachSpec& InSpec)
    {
        const auto T = InState.PhaseTime;
        if (InState.Phase == EMars_FPHands_Phase::Reach)
        { return Ease(InSpec.GrabOutEasing, T / Math::Max(InSpec.GrabOutSeconds, 0.01f)); }

        if (InState.Phase == EMars_FPHands_Phase::Grip)
        { return 1.0f; }

        if (InState.Phase == EMars_FPHands_Phase::Return)
        { return 1.0f - Ease(InSpec.GrabBackEasing, T / Math::Max(InSpec.GrabBackSeconds, 0.01f)); }

        if (InState.Phase == EMars_FPHands_Phase::Hold)
        { return Ease(InSpec.HoldReachEasing, T / Math::Max(InSpec.HoldReachSeconds, 0.01f)); }

        if (InState.Phase == EMars_FPHands_Phase::Release)
        { return InState.ReleaseFromAlpha * (1.0f - Ease(InSpec.ReleaseEasing, T / Math::Max(InSpec.ReleaseSeconds, 0.01f))); }

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

    // Seconds the phase lasts before the sub-SM moves on; Hold and None never time out (0).
    float32 Get_PhaseSeconds(EMars_FPHands_Phase InPhase, const FMars_FPHands_ReachSpec& InSpec)
    {
        if (InPhase == EMars_FPHands_Phase::Reach)
        { return InSpec.GrabOutSeconds; }

        if (InPhase == EMars_FPHands_Phase::Grip)
        { return InSpec.GrabGripSeconds; }

        if (InPhase == EMars_FPHands_Phase::Return)
        { return InSpec.GrabBackSeconds; }

        if (InPhase == EMars_FPHands_Phase::Release)
        { return InSpec.ReleaseSeconds; }

        return 0.0f;
    }

    // The glove's grip (hand node space) when fully reached from InGrip.RestGrip toward InGrip.WorldGrip. Authored
    // grips are matched exactly when in reach; out of reach the glove stretches its maximum toward them.
    FTransform Make_ReachedGrip(const FMars_FPHands_ReachSpec& InSpec, const FMars_FPHands_GripQuery& InGrip)
    {
        const auto TargetInHand = InGrip.HandWorld.InverseTransformPosition(InGrip.WorldGrip.GetLocation());
        const auto ToTarget = TargetInHand - InGrip.RestGrip.GetLocation();
        const auto Distance = ToTarget.Size();
        if (Distance < KINDA_SMALL_NUMBER)
        { return InGrip.RestGrip; }

        const auto Direction = ToTarget / Distance;
        const auto Wanted = Math::Max(Distance - InGrip.Standoff, 0.0);
        const auto Length = Math::Min(Wanted, float(InSpec.MaxReachCm));

        auto Result = InGrip.RestGrip;
        Result.SetLocation(InGrip.RestGrip.GetLocation() + Direction * Length);

        if (InGrip.IsAuthored && Wanted <= InSpec.MaxReachCm + 1.0)
        { Result.SetRotation(InGrip.HandWorld.InverseTransformRotation(InGrip.WorldGrip.GetRotation())); }
        else
        {
            const auto Aim = FQuat::Slerp(FQuat::Identity, FQuat::FindBetweenNormals(FVector::ForwardVector, Direction), InSpec.AimFraction);
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

// 1 = a picked-up item is where it lay, 0 = at its hold offset. Follows the grab.
mixin float32 Get_CarryWeight(const FCk_Handle_FPHands& Self)
{
    return utils_fphands::Get_PhaseCarryWeight(Self.Get_PhaseState(), Self.Get_Spec().Reach);
}

mixin bool Get_IsReaching(const FCk_Handle_FPHands& Self, bool InIsRightHand)
{
    return Self.Get_Phase() != EMars_FPHands_Phase::None && utils_fphands::Get_UsesHand(Self.Get_Target(), InIsRightHand);
}

// Finger pose while reaching; false = keep the glove's own pose.
mixin bool Get_ReachPose(const FCk_Handle_FPHands& Self, EMars_HandGripPose& OutPose)
{
    const auto& Spec = Self.Get_Spec();
    const auto Target = Self.Get_Target();
    const auto Phase = Self.Get_Phase();
    const auto T = Self.Get_PhaseTime();
    const auto Contact = Target.HasContactPose ? Target.ContactPose : Spec.Reach.ContactPose;
    if (Phase == EMars_FPHands_Phase::Reach)
    {
        OutPose = T < Spec.Reach.GrabOutSeconds * 0.7f ? Spec.Reach.ApproachPose : Contact;
        return true;
    }

    if (Phase == EMars_FPHands_Phase::Grip)
    {
        OutPose = Contact;
        return true;
    }

    if (Phase == EMars_FPHands_Phase::Return && T < Spec.Reach.GrabBackSeconds * 0.5f)
    {
        OutPose = Contact;
        return true;
    }

    if (Phase == EMars_FPHands_Phase::Hold)
    {
        OutPose = T < Spec.Reach.HoldReachSeconds * 0.7f ? Spec.Reach.ApproachPose : Contact;
        return true;
    }

    if (Phase == EMars_FPHands_Phase::Release && T < Spec.Reach.ReleaseSeconds * 0.6f)
    {
        OutPose = Spec.Reach.ApproachPose;
        return true;
    }

    return false;
}
