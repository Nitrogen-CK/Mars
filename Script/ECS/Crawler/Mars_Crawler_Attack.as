// The body jab's pure evaluation (the shape of utils_hand_swing::Evaluate) and its hit query. The phase clock that drives
// them is UMars_Processor_Crawler_AttackTick's; the samples they query are UMars_Processor_Crawler_AttackResolve's.
//
// Every attack query sets CollideWithBackFaces for convex bodies: Jolt keeps a convex cast hit only when that flag is set
// or the contact normal points along the cast direction, so without it a zero-travel query, or a sweep that starts inside
// a body, reports nothing for that body. With it, a body the sphere already overlaps at the start of a sample is reported
// at fraction 0 with the fallback up normal: a target there is a hit (the damage event carries that up normal), and a
// world body there blocks the sample, which closes the damage window and cancels the attack as Obstructed.

// What Evaluate_ActionOffset needs besides the authored pose.
struct FMars_Crawler_PoseQuery
{
    EMars_Crawler_AttackPhase Phase = EMars_Crawler_AttackPhase::Idle;

    // Phase progress in [0, 1].
    float32 Alpha = 0.0f;

    // Where CancelRecover eases back from.
    FTransform From = FTransform::Identity;

    FMars_Crawler_PoseQuery() {}

    FMars_Crawler_PoseQuery(EMars_Crawler_AttackPhase InPhase, float32 InAlpha, FTransform InFrom)
    {
        Phase = InPhase;
        Alpha = InAlpha;
        From = InFrom;
    }
}

namespace utils_crawler
{
    // Windup, Strike or Recover: the phases that may still damage, and that every direct guard watches.
    bool Get_IsOffensivePhase(EMars_Crawler_AttackPhase InPhase)
    {
        return InPhase == EMars_Crawler_AttackPhase::Windup || InPhase == EMars_Crawler_AttackPhase::Strike ||
            InPhase == EMars_Crawler_AttackPhase::Recover;
    }

    // The authored length of a posed phase; 0 for Idle and Cooldown, which pose nothing.
    float32 Make_PhaseDuration(const FMars_Crawler_AttackTiming& InTiming, EMars_Crawler_AttackPhase InPhase)
    {
        switch (InPhase)
        {
            case EMars_Crawler_AttackPhase::Windup: return InTiming.WindupSeconds;
            case EMars_Crawler_AttackPhase::Strike: return InTiming.StrikeSeconds;
            case EMars_Crawler_AttackPhase::Recover: return InTiming.RecoverSeconds;
            case EMars_Crawler_AttackPhase::CancelRecover: return InTiming.CancelSeconds;
            default: return 0.0f;
        }
    }

    // Windup: identity to the windup key; Strike: windup key to strike key; Recover: strike key to identity;
    // CancelRecover: From to identity (eased like Recover). Unit scale throughout; identity outside the posed phases.
    FTransform Evaluate_ActionOffset(const FMars_Crawler_AttackPose& InPose, const FMars_Crawler_PoseQuery& InQuery)
    {
        switch (InQuery.Phase)
        {
            case EMars_Crawler_AttackPhase::Windup:
                return Blend(FTransform::Identity, InPose.Windup, Ease(InPose.WindupEasing, InQuery.Alpha));
            case EMars_Crawler_AttackPhase::Strike:
                return Blend(InPose.Windup, InPose.Strike, Ease(InPose.StrikeEasing, InQuery.Alpha));
            case EMars_Crawler_AttackPhase::Recover:
                return Blend(InPose.Strike, FTransform::Identity, Ease(InPose.RecoverEasing, InQuery.Alpha));
            case EMars_Crawler_AttackPhase::CancelRecover:
                return Blend(InQuery.From, FTransform::Identity, Ease(InPose.RecoverEasing, InQuery.Alpha));
            default:
                return FTransform::Identity;
        }
    }

    // A pincer key on InClaw's side of the body.
    FVector Make_ClawKey(const FMars_Crawler_AttackClaw& InClaw, FVector InRightKey)
    {
        return FVector(InRightKey.X, InRightKey.Y * InClaw.Side, InRightKey.Z);
    }

    // Where InClaw's foot goes, in the simulation body's frame. Windup: home to the windup key; Strike: windup key to
    // strike key; Recover: strike key to home; CancelRecover: the claw's CancelRecoverStart to home; home outside the
    // posed phases. The easings are the body keys'. Home must be set.
    FVector Evaluate_ClawPoint(const FMars_Crawler_Combat& InCombat, const FMars_Crawler_AttackClaw& InClaw, const FMars_Crawler_PoseQuery& InQuery)
    {
        const auto Home = InClaw.Home.GetValue();
        const auto Windup = Make_ClawKey(InClaw, InCombat.Pincer.Windup);
        const auto Strike = Make_ClawKey(InClaw, InCombat.Pincer.Strike);

        switch (InQuery.Phase)
        {
            case EMars_Crawler_AttackPhase::Windup:
                return Math::Lerp(Home, Windup, float(Ease(InCombat.Pose.WindupEasing, InQuery.Alpha)));
            case EMars_Crawler_AttackPhase::Strike:
                return Math::Lerp(Windup, Strike, float(Ease(InCombat.Pose.StrikeEasing, InQuery.Alpha)));
            case EMars_Crawler_AttackPhase::Recover:
                return Math::Lerp(Strike, Home, float(Ease(InCombat.Pose.RecoverEasing, InQuery.Alpha)));
            case EMars_Crawler_AttackPhase::CancelRecover:
                return Math::Lerp(InClaw.CancelRecoverStart, Home, float(Ease(InCombat.Pose.RecoverEasing, InQuery.Alpha)));
            default:
                return Home;
        }
    }

    // InCombat, authored for the radial box crawler, refitted to InLayout's rig and size: the body keys' translations and
    // the hit's sample-travel tolerance grow with the size, and on a layout other than Radial the pincer's keys move onto
    // its front leg (Fit_PincerToRig) with a ground floor grown with the size. Rotations, timings, the hit sphere and every
    // gameplay number are kept.
    FMars_Crawler_Combat Fit_CombatToLayout(FMars_Crawler_Combat InCombat, EMars_Crawler_Layout InLayout, int32 InLegCount)
    {
        const auto Size = float64(Get_LayoutSizeScale(InLayout));
        auto Combat = InCombat;
        Combat.Pose.Windup = FTransform(InCombat.Pose.Windup.Rotator(), InCombat.Pose.Windup.GetLocation() * Size, FVector::OneVector);
        Combat.Pose.Strike = FTransform(InCombat.Pose.Strike.Rotator(), InCombat.Pose.Strike.GetLocation() * Size, FVector::OneVector);
        Combat.Hit.MaxSampleTravel = float32(InCombat.Hit.MaxSampleTravel * Size);

        auto RigData = Get_LayoutRigData(InLayout, InLegCount);
        if (InLayout != EMars_Crawler_Layout::Radial && ck::IsValid(RigData))
        {
            const auto Fit = FMars_Crawler_PincerFit(RigData, PincerKeyGroundClearance * Size);
            Combat.Pincer = Fit_PincerToRig(InCombat.Pincer, Fit);
        }
        return Combat;
    }

    // InPincer's keys, authored on the radial 6-leg rig's front leg, moved onto InFit's rig: each key keeps its offset from
    // the front hip scaled by the ratio of the two chains' reaches, and stays InFit.GroundClearance over the rest feet's
    // ground (a shorter, lower-slung chain would otherwise strike into the floor). The reach fractions Validate checks are
    // unchanged by the scaling.
    FMars_Crawler_AttackPincer Fit_PincerToRig(FMars_Crawler_AttackPincer InPincer, const FMars_Crawler_PincerFit& InFit)
    {
        const TArray<FCk_ProceduralLeg_Spec> From = utils_crawler::Mars_CrawlerRig6.Get_Legs();
        const TArray<FCk_ProceduralLeg_Spec> To = InFit.RigData.Get_Legs();
        const auto FromHip = From[0].Get_Placement().Get_HipLocal();
        const auto ToHip = To[0].Get_Placement().Get_HipLocal();
        const auto Scale = float64(Get_ChainReach(To[0]) / Get_ChainReach(From[0]));
        const auto Floor = To[0].Get_Placement().Get_RestFootLocal().Z + InFit.GroundClearance;

        auto Pincer = InPincer;
        Pincer.Windup = ToHip + (InPincer.Windup - FromHip) * Scale;
        Pincer.Strike = ToHip + (InPincer.Strike - FromHip) * Scale;
        Pincer.Windup.Z = Math::Max(Pincer.Windup.Z, Floor);
        Pincer.Strike.Z = Math::Max(Pincer.Strike.Z, Floor);
        return Pincer;
    }

    const float64 PincerKeyGroundClearance = 10.0;

    // The sum of a rig leg's segment lengths.
    float32 Get_ChainReach(const FCk_ProceduralLeg_Spec& InLeg)
    {
        const auto Lengths = InLeg.Get_Chain().Get_SegmentLengths();
        float32 Reach = 0.0f;
        for (int32 Index = 0; Index < Lengths.Num(); ++Index)
        { Reach += Lengths[Index]; }

        return Reach;
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

    // Finite, unit scale, identity rotation: the v1 crawler authoring contract for attack keys.
    bool Get_IsTranslationOnly(const FTransform& InTransform)
    {
        if (Get_IsFinite(InTransform.GetLocation()) == false || Get_IsFinite(InTransform.GetScale3D()) == false || InTransform.ContainsNaN())
        { return false; }

        return (InTransform.GetScale3D() - FVector::OneVector).IsNearlyZero(KINDA_SMALL_NUMBER) &&
            InTransform.GetRotation().IsIdentity(KINDA_SMALL_NUMBER);
    }

    // The most a windup key may pitch the body (see FMars_Crawler_AttackPose).
    const float32 MaxWindupPitchDegrees = 45.0f;

    // Finite, unit scale, and rotated about the body's Y axis alone by at most MaxWindupPitchDegrees (identity included).
    bool Get_IsPitchOnly(const FTransform& InTransform)
    {
        if (Get_IsFinite(InTransform.GetLocation()) == false || Get_IsFinite(InTransform.GetScale3D()) == false || InTransform.ContainsNaN())
        { return false; }

        if ((InTransform.GetScale3D() - FVector::OneVector).IsNearlyZero(KINDA_SMALL_NUMBER) == false)
        { return false; }

        const auto Rotation = InTransform.GetRotation();
        if (Math::Abs(Rotation.X) > KINDA_SMALL_NUMBER || Math::Abs(Rotation.Z) > KINDA_SMALL_NUMBER)
        { return false; }

        return Math::RadiansToDegrees(Rotation.AngularDistance(FQuat::Identity)) <= MaxWindupPitchDegrees + KINDA_SMALL_NUMBER;
    }

    // Where an action key puts the hit centre, as an offset from where it sits with no action, in the body's axes.
    FVector Make_HitCenterOffset(const FTransform& InKey, const FVector& InLocalCenter)
    {
        return InKey.GetLocation() + InKey.GetRotation().RotateVector(InLocalCenter) - InLocalCenter;
    }

    bool Get_IsFinite(const FVector& InVector)
    {
        return Math::IsFinite(InVector.X) && Math::IsFinite(InVector.Y) && Math::IsFinite(InVector.Z);
    }

    bool Get_IsPositiveFinite(float32 InValue)
    {
        return Math::IsFinite(InValue) && InValue > 0.0f;
    }

    // The hit sphere's world centre for an accepted presentation transform.
    FVector Get_HitCenter(const FTransform& InAcceptedWorld, const FVector& InLocalCenter)
    {
        return InAcceptedWorld.TransformPosition(InLocalCenter);
    }

    // A sphere from InStart to InEnd filtered on Probe.Mars.HitZone, Blocking world policy (a wall stops it), Silent (a query
    // must not ping the hurtboxes), CollideWithBackFaces for convex bodies (see the file comment).
    FCk_ShapeCast_Settings Make_AttackQuery(FVector InStart, FVector InEnd, float32 InRadius)
    {
        auto Settings = FCk_ShapeCast_Settings(InStart, InEnd,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InRadius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_WorldHitPolicy(ECk_ProbeTrace_WorldHitPolicy::Blocking);
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        Settings.Set_BackFaceModeConvex(ECk_BackFaceMode::CollideWithBackFaces);
        return Settings;
    }

    // The angle between two directions on the plane of InUp, in degrees; 180 when either is degenerate on that plane.
    float64 Get_PlanarAngleDegrees(FVector InA, FVector InB, FVector InUp)
    {
        const auto A = (InA - InUp * InA.DotProduct(InUp)).GetSafeNormal();
        const auto B = (InB - InUp * InB.DotProduct(InUp)).GetSafeNormal();
        if (A.IsNearlyZero() || B.IsNearlyZero())
        { return 180.0; }

        return Math::RadiansToDegrees(Math::Acos(Math::Clamp(A.DotProduct(B), -1.0, 1.0)));
    }
}

// Every entity an attack query must pass through: the crawler root, its body hurtboxes, each leg entity and the
// hurtboxes of each live leg part. Nothing else: walls, floors and other creatures stay in the query.
mixin TArray<FCk_Handle> Get_AttackIgnoredEntities(const FCk_Handle_Crawler& Self)
{
    FCk_Handle Root = Self;
    auto Ignored = TArray<FCk_Handle>();
    Ignored.Add(Root);

    const auto BodyZone = Self.Get_Monster().Get_BodyZone();
    if (ck::IsValid(BodyZone))
    { Ignored.Append(BodyZone.Get_Hurtboxes()); }

    for (const auto& Part : Self.Get_LegParts())
    {
        if (ck::Is_NOT_Valid(Part))
        { continue; }

        FCk_Handle LegEntity = Part;
        Ignored.Add(LegEntity);

        const auto Zone = Part.Get_Zone();
        if (ck::IsValid(Zone))
        { Ignored.Append(Zone.Get_Hurtboxes()); }
    }

    return Ignored;
}
