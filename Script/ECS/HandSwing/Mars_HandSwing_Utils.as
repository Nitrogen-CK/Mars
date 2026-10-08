namespace constants_hand_swing
{
    // A recovery never collapses below this, so a cancel or a short request still eases the hand back.
    const float32 k_MinRecoverSeconds = 0.05f;
}

namespace utils_hand_swing
{
    // The swing of InOwner's hand. Nothing in the spec can be invalid: the node is optional.
    FCk_Handle_HandSwing Add(FCk_Handle& InOwner, FMars_HandSwing_Spec InSpec)
    {
        auto Params = FMars_Fragment_HandSwing_Params();
        Params.Node = InSpec.Node;

        InOwner.Add_Fragment(FMars_Feature_HandSwing());
        InOwner.Add_Fragment(Params);
        InOwner.Add_Fragment(FMars_Fragment_HandSwing());
        return InOwner.As_HandSwing();
    }

    // The phase boundaries for a swing of InArc whose blow lands InImpactSeconds from its start and whose hand is back at
    // rest InRecoverySeconds after that. The strike travel is placed so its impact fraction falls on the impact; a windup
    // that would start before the swing collapses to nothing (the strike then leaves from the current pose).
    FMars_HandSwing_Timeline Make_Timeline(const FMars_HandSwing_Arc& InArc, float32 InImpactSeconds, float32 InRecoverySeconds)
    {
        auto Timeline = FMars_HandSwing_Timeline();
        Timeline.WindupEnd = Math::Max(InImpactSeconds - InArc.StrikeSeconds * InArc.ImpactFraction, 0.0f);
        Timeline.StrikeEnd = Timeline.WindupEnd + InArc.StrikeSeconds;
        Timeline.RecoverEnd = Math::Max(InImpactSeconds + InRecoverySeconds, Timeline.StrikeEnd + constants_hand_swing::k_MinRecoverSeconds);
        return Timeline;
    }

    EMars_HandSwing_Phase Get_PhaseAt(const FMars_HandSwing_Timeline& InTimeline, float32 InElapsed)
    {
        if (InElapsed < InTimeline.WindupEnd)
        { return EMars_HandSwing_Phase::Windup; }

        if (InElapsed < InTimeline.StrikeEnd)
        { return EMars_HandSwing_Phase::Strike; }

        if (InElapsed < InTimeline.RecoverEnd)
        { return EMars_HandSwing_Phase::Recover; }

        return EMars_HandSwing_Phase::None;
    }

    // The hand's offset InElapsed seconds into a swing that left InStartPose: through the windup and strike keys and back
    // to identity. Each segment eases with its destination key's easing (the recovery with the arc's).
    FTransform Evaluate(const FMars_HandSwing_Arc& InArc, const FMars_HandSwing_Timeline& InTimeline,
                        const FTransform& InStartPose, float32 InElapsed)
    {
        const auto WindupPose = Make_Pose(InArc.Windup);
        const auto StrikePose = Make_Pose(InArc.Strike);

        if (InElapsed < InTimeline.WindupEnd)
        {
            const auto T = InElapsed / InTimeline.WindupEnd;
            return Blend(InStartPose, WindupPose, Ease(InArc.Windup.Easing, T));
        }

        if (InElapsed < InTimeline.StrikeEnd)
        {
            const auto From = InTimeline.WindupEnd > 0.0f ? WindupPose : InStartPose;
            const auto T = (InElapsed - InTimeline.WindupEnd) / Math::Max(InTimeline.StrikeEnd - InTimeline.WindupEnd, KINDA_SMALL_NUMBER);
            return Blend(From, StrikePose, Ease(InArc.Strike.Easing, T));
        }

        if (InElapsed < InTimeline.RecoverEnd)
        {
            const auto T = (InElapsed - InTimeline.StrikeEnd) / Math::Max(InTimeline.RecoverEnd - InTimeline.StrikeEnd, KINDA_SMALL_NUMBER);
            return Blend(StrikePose, FTransform::Identity, Ease(InArc.RecoverEasing, T));
        }

        return FTransform::Identity;
    }

    FTransform Make_Pose(const FMars_HandSwing_Key& InKey)
    {
        return FTransform(InKey.Rotation, InKey.Location, FVector::OneVector);
    }

    FTransform Blend(const FTransform& InFrom, const FTransform& InTo, float32 InAlpha)
    {
        auto Result = FTransform();
        Result.SetLocation(Math::Lerp(InFrom.GetLocation(), InTo.GetLocation(), float(InAlpha)));
        Result.SetRotation(FQuat::Slerp(InFrom.GetRotation(), InTo.GetRotation(), float(InAlpha)));
        return Result;
    }

    float32 Ease(ECk_TweenEasing InEasing, float32 InT)
    {
        return utils_tween::Get_EasedProgress(InEasing, FCk_FloatRange_0to1(Math::Clamp(InT, 0.0f, 1.0f)));
    }

    bool Get_IsFinite(const FVector& InVector)
    {
        return Math::IsFinite(InVector.X) && Math::IsFinite(InVector.Y) && Math::IsFinite(InVector.Z);
    }

    bool Get_IsFinite(const FRotator& InRotator)
    {
        return Math::IsFinite(InRotator.Pitch) && Math::IsFinite(InRotator.Yaw) && Math::IsFinite(InRotator.Roll);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Authored arcs for the sandbox tools. Hand space: X forward, Y right, Z up.
    //----------------------------------------------------------------------------------------------------------------------

    // A cleaver: pulled back and up, then pitched down and forward (the arc's defaults).
    FMars_HandSwing_Arc Make_ChopArc()
    {
        return FMars_HandSwing_Arc();
    }

    // A mallet: drawn back and high overhead, then brought down far out in front.
    FMars_HandSwing_Arc Make_OverheadArc()
    {
        auto Arc = FMars_HandSwing_Arc();
        Arc.Windup = FMars_HandSwing_Key(FVector(-18.0, 4.0, 26.0), FRotator(70.0, -8.0, 0.0), ECk_TweenEasing::OutCubic);
        Arc.Strike = FMars_HandSwing_Key(FVector(40.0, -4.0, -22.0), FRotator(-85.0, 6.0, 0.0), ECk_TweenEasing::InQuad);
        Arc.StrikeSeconds = 0.14f;
        Arc.ImpactFraction = 0.7f;
        return Arc;
    }

    // A pan: cocked back to the right, then swiped out and across to the left.
    FMars_HandSwing_Arc Make_SwipeArc()
    {
        auto Arc = FMars_HandSwing_Arc();
        Arc.Windup = FMars_HandSwing_Key(FVector(-10.0, 20.0, 6.0), FRotator(6.0, 50.0, -18.0), ECk_TweenEasing::OutCubic);
        Arc.Strike = FMars_HandSwing_Key(FVector(32.0, -28.0, -4.0), FRotator(-10.0, -65.0, 18.0), ECk_TweenEasing::InQuad);
        Arc.StrikeSeconds = 0.13f;
        Arc.ImpactFraction = 0.6f;
        return Arc;
    }
}

// Positive strike travel, an impact fraction within 0..1 and finite keys.
mixin FMars_Validation Validate(const FMars_HandSwing_Arc& Self)
{
    if ((Self.StrikeSeconds > 0.0f) == false)
    { return FMars_Validation(f"StrikeSeconds [{Self.StrikeSeconds}] must be positive"); }

    if ((Self.ImpactFraction >= 0.0f && Self.ImpactFraction <= 1.0f) == false)
    { return FMars_Validation(f"ImpactFraction [{Self.ImpactFraction}] is outside [0, 1]"); }

    if ((utils_hand_swing::Get_IsFinite(Self.Windup.Location) && utils_hand_swing::Get_IsFinite(Self.Windup.Rotation)) == false)
    { return FMars_Validation(f"Windup key [{Self.Windup.Location}] / [{Self.Windup.Rotation}] is not finite"); }

    if ((utils_hand_swing::Get_IsFinite(Self.Strike.Location) && utils_hand_swing::Get_IsFinite(Self.Strike.Rotation)) == false)
    { return FMars_Validation(f"Strike key [{Self.Strike.Location}] / [{Self.Strike.Rotation}] is not finite"); }

    return FMars_Validation();
}

// A valid arc, a non-negative impact time and a positive recovery.
mixin FMars_Validation Validate(const FMars_Request_HandSwing_Start& Self)
{
    const auto Arc = Self.Arc.Validate();
    if (Arc.IsValid() == false)
    { return FMars_Validation(f"Arc: {Arc.Get_Error()}"); }

    if ((Self.ImpactSeconds >= 0.0f) == false)
    { return FMars_Validation(f"ImpactSeconds [{Self.ImpactSeconds}] must not be negative"); }

    if ((Self.RecoverySeconds > 0.0f) == false)
    { return FMars_Validation(f"RecoverySeconds [{Self.RecoverySeconds}] must be positive"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_HandSwing_Phase Get_Phase(const FCk_Handle_HandSwing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HandSwing).Phase;
}

mixin bool Get_IsSwinging(const FCk_Handle_HandSwing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HandSwing).Phase != EMars_HandSwing_Phase::None;
}

// The hand's current offset in its own space; identity at rest.
mixin FTransform Get_Pose(const FCk_Handle_HandSwing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HandSwing).Pose;
}

mixin float32 Get_Elapsed(const FCk_Handle_HandSwing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HandSwing).Elapsed;
}

mixin FMars_HandSwing_Timeline Get_Timeline(const FCk_Handle_HandSwing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HandSwing).Timeline;
}

// The arc in flight (or last flown). After a cancel its Strike key is the pose the recovery left from.
mixin FMars_HandSwing_Arc Get_Arc(const FCk_Handle_HandSwing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HandSwing).Arc;
}

mixin FCk_Handle_SceneNode Get_Node(const FCk_Handle_HandSwing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HandSwing_Params).Node;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Start(FCk_Handle_HandSwing& Self, const FMars_Request_HandSwing_Start& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HandSwing_Requests);
    Requests.StartRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_HandSwing& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HandSwing_Requests);
    Requests.CancelRequests.Add(FMars_Request_HandSwing_Cancel());
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_HandSwing& Self, FMars_Delegate_HandSwing_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_HandSwing_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_HandSwing& Self, FMars_Delegate_HandSwing_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_HandSwing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_HandSwing_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
