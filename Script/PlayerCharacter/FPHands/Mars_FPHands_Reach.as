// The gloves reaching for an interactable: a small lean while the player looks at it, then a full reach on Use.
// One glove or both, to the grips resolved by mars_fphands_grips (sockets, the object's sides, or its interaction
// point). Instant interactions (pickups, switches) play a quick grab gesture; timed ones keep the gloves on the target
// until the interaction ends.
enum EMars_FPHands_ReachPhase
{
    None,
    Grab,
    Hold,
    Release
}

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

    // Timed interactions: reach time, and let-go time when the interaction ends (seconds).
    UPROPERTY(Category = "Hold")
    float32 HoldReachSeconds = 0.16f;

    UPROPERTY(Category = "Hold")
    float32 ReleaseSeconds = 0.22f;
}

struct FMars_FPHands_Reach
{
    UPROPERTY()
    EMars_FPHands_ReachPhase Phase = EMars_FPHands_ReachPhase::None;

    UPROPERTY()
    FMars_FPHands_ReachTarget Target;

    UPROPERTY()
    FCk_Handle_InteractTarget InteractTarget;

    UPROPERTY()
    float32 Time = 0.0f;

    UPROPERTY()
    float32 ReleaseFromAlpha = 1.0f;

    // What the gloves lean toward while it is looked at, re-resolved when focus changes.
    UPROPERTY()
    FMars_FPHands_ReachTarget FocusTarget;

    UPROPERTY()
    FCk_Handle_Interactable FocusedFor;

    // Smoothed focus lean per glove (each eases on its own, so switching sides cross-fades).
    UPROPERTY()
    float32 FocusAlpha_L = 0.0f;

    UPROPERTY()
    float32 FocusAlpha_R = 0.0f;

    // Single-handed targets near the centre line stay with this glove.
    UPROPERTY()
    bool PreferRightHand = true;
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

namespace mars_fphands_reach
{
    // 1 = the item is where it was picked up, 0 = at its hold offset. Follows the grab: held in place until the gloves
    // have closed on it, then along the gloves' return.
    float32 Get_CarryWeight(const FMars_FPHands_Reach& InReach, const FMars_FPHands_ReachSpec& InSpec)
    {
        if (InReach.Phase != EMars_FPHands_ReachPhase::Grab)
        { return 0.0f; }

        if (InReach.Time < InSpec.GrabOutSeconds + InSpec.GrabGripSeconds)
        { return 1.0f; }

        return Get_Alpha(InReach, InSpec);
    }

    float32 Ease(float32 InT)
    {
        const auto T = Math::Clamp(InT, 0.0f, 1.0f);
        return T * T * (3.0f - 2.0f * T);
    }

    void Start(FMars_FPHands_Reach& InReach, const FCk_Handle_InteractTarget& InInteractTarget,
               const FMars_FPHands_ReachTarget& InTarget, bool InIsInstant)
    {
        InReach.Phase = InIsInstant ? EMars_FPHands_ReachPhase::Grab : EMars_FPHands_ReachPhase::Hold;
        InReach.InteractTarget = InInteractTarget;
        InReach.Target = InTarget;
        InReach.Time = 0.0f;
    }

    // Timed interactions let go when the interaction ends; a grab gesture always finishes on its own.
    void Release(FMars_FPHands_Reach& InReach, const FMars_FPHands_ReachSpec& InSpec)
    {
        if (InReach.Phase != EMars_FPHands_ReachPhase::Hold)
        { return; }

        InReach.ReleaseFromAlpha = Get_Alpha(InReach, InSpec);
        InReach.Phase = EMars_FPHands_ReachPhase::Release;
        InReach.Time = 0.0f;
    }

    void Tick(FMars_FPHands_Reach& InReach, const FMars_FPHands_ReachSpec& InSpec, float32 InDeltaSeconds, bool InHasFocus)
    {
        InReach.Time += InDeltaSeconds;
        mars_fphands_grips::Update(InReach.Target);
        mars_fphands_grips::Update(InReach.FocusTarget);

        if (InReach.Phase == EMars_FPHands_ReachPhase::Grab
            && InReach.Time >= InSpec.GrabOutSeconds + InSpec.GrabGripSeconds + InSpec.GrabBackSeconds)
        { InReach.Phase = EMars_FPHands_ReachPhase::None; }

        if (InReach.Phase == EMars_FPHands_ReachPhase::Release && InReach.Time >= InSpec.ReleaseSeconds)
        { InReach.Phase = EMars_FPHands_ReachPhase::None; }

        // A reach takes the larger of lean and reach, so it launches from and settles back into the lean.
        const auto HasFocus = InHasFocus && InReach.FocusTarget.IsValid;
        const auto LeanAlpha = float32(1.0 - Math::Exp(-InSpec.FocusInterpSpeed * InDeltaSeconds));
        const auto LeanR = HasFocus && InReach.FocusTarget.UsesRight ? InSpec.FocusLean : 0.0f;
        const auto LeanL = HasFocus && InReach.FocusTarget.UsesLeft ? InSpec.FocusLean : 0.0f;
        InReach.FocusAlpha_R += (LeanR - InReach.FocusAlpha_R) * LeanAlpha;
        InReach.FocusAlpha_L += (LeanL - InReach.FocusAlpha_L) * LeanAlpha;
    }

    bool Is_Reaching(const FMars_FPHands_Reach& InReach, bool InIsRightHand)
    {
        return InReach.Phase != EMars_FPHands_ReachPhase::None && mars_fphands_grips::Uses(InReach.Target, InIsRightHand);
    }

    // 0 = gloves at rest, 1 = fully reached.
    float32 Get_Alpha(const FMars_FPHands_Reach& InReach, const FMars_FPHands_ReachSpec& InSpec)
    {
        const auto T = InReach.Time;
        if (InReach.Phase == EMars_FPHands_ReachPhase::Grab)
        {
            if (T < InSpec.GrabOutSeconds)
            { return Ease(T / Math::Max(InSpec.GrabOutSeconds, 0.01f)); }

            if (T < InSpec.GrabOutSeconds + InSpec.GrabGripSeconds)
            { return 1.0f; }

            return 1.0f - Ease((T - InSpec.GrabOutSeconds - InSpec.GrabGripSeconds) / Math::Max(InSpec.GrabBackSeconds, 0.01f));
        }

        if (InReach.Phase == EMars_FPHands_ReachPhase::Hold)
        { return Ease(T / Math::Max(InSpec.HoldReachSeconds, 0.01f)); }

        if (InReach.Phase == EMars_FPHands_ReachPhase::Release)
        { return InReach.ReleaseFromAlpha * (1.0f - Ease(T / Math::Max(InSpec.ReleaseSeconds, 0.01f))); }

        return 0.0f;
    }

    // Finger pose while reaching; false = keep the glove's own pose.
    bool Get_Pose(const FMars_FPHands_Reach& InReach, const FMars_FPHands_ReachSpec& InSpec, EMars_HandGripPose& OutPose)
    {
        const auto Contact = InReach.Target.HasContactPose ? InReach.Target.ContactPose : InSpec.ContactPose;
        const auto T = InReach.Time;
        if (InReach.Phase == EMars_FPHands_ReachPhase::Grab)
        {
            if (T < InSpec.GrabOutSeconds * 0.7f)
            { OutPose = InSpec.ApproachPose; return true; }

            if (T < InSpec.GrabOutSeconds + InSpec.GrabGripSeconds + InSpec.GrabBackSeconds * 0.5f)
            { OutPose = Contact; return true; }

            return false;
        }

        if (InReach.Phase == EMars_FPHands_ReachPhase::Hold)
        {
            OutPose = T < InSpec.HoldReachSeconds * 0.7f ? InSpec.ApproachPose : Contact;
            return true;
        }

        if (InReach.Phase == EMars_FPHands_ReachPhase::Release && T < InSpec.ReleaseSeconds * 0.6f)
        {
            OutPose = InSpec.ApproachPose;
            return true;
        }

        return false;
    }

    // The glove's grip (hand node space) when fully reached toward InWorldGrip from its rest grip. Authored grips are
    // matched exactly when in reach; out of reach the glove stretches its maximum toward them.
    FTransform Make_ReachedGrip(const FMars_FPHands_ReachSpec& InSpec, const FTransform& InRestGrip, const FTransform& InHandWorld,
                                const FTransform& InWorldGrip, bool InIsAuthored, float InStandoff)
    {
        const auto TargetInHand = InHandWorld.InverseTransformPosition(InWorldGrip.GetLocation());
        const auto ToTarget = TargetInHand - InRestGrip.GetLocation();
        const auto Distance = ToTarget.Size();
        if (Distance < KINDA_SMALL_NUMBER)
        { return InRestGrip; }

        const auto Direction = ToTarget / Distance;
        const auto Wanted = Math::Max(Distance - InStandoff, 0.0);
        const auto Length = Math::Min(Wanted, float(InSpec.MaxReachCm));

        auto Result = InRestGrip;
        Result.SetLocation(InRestGrip.GetLocation() + Direction * Length);

        if (InIsAuthored && Wanted <= InSpec.MaxReachCm + 1.0)
        { Result.SetRotation(InHandWorld.InverseTransformRotation(InWorldGrip.GetRotation())); }
        else
        {
            const auto Aim = FQuat::Slerp(FQuat::Identity, FQuat::FindBetweenNormals(FVector::ForwardVector, Direction), InSpec.AimFraction);
            Result.SetRotation(Aim * InRestGrip.GetRotation());
        }
        return Result;
    }
}
