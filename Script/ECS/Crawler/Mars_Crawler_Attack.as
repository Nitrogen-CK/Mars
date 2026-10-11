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
