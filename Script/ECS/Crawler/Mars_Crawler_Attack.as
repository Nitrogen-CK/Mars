// The attack query and the clip vocabulary the kernel shares with the editor's clip builder. The clip action owns the
// motion's timing; the accepted intervals the query sweeps are UMars_Processor_Crawler_AttackResolve's, and the phases
// they report drive UMars_Processor_Crawler_AttackTick.
//
// Every attack query sets CollideWithBackFaces for convex bodies: Jolt keeps a convex cast hit only when that flag is set
// or the contact normal points along the cast direction, so without it a zero-travel query, or a sweep that starts inside
// a body, reports nothing for that body. With it, a body the sphere already overlaps at the start of a sample is reported
// at fraction 0 with the fallback up normal: a target there is a hit (the damage event carries that up normal), and a
// world body there blocks the sample, which closes the damage window and cancels the attack as Obstructed.

namespace utils_crawler
{
    // Windup, Strike or Recover: the phases that may still damage, and that every direct guard watches.
    bool Get_IsOffensivePhase(EMars_Crawler_AttackPhase InPhase)
    {
        return InPhase == EMars_Crawler_AttackPhase::Windup || InPhase == EMars_Crawler_AttackPhase::Strike ||
            InPhase == EMars_Crawler_AttackPhase::Recover;
    }

    // The reference clips' phase that poses InPhase; None for the phases a clip does not pose.
    FName Get_ClipPhaseId(EMars_Crawler_AttackPhase InPhase)
    {
        switch (InPhase)
        {
            case EMars_Crawler_AttackPhase::Windup: return n"Windup";
            case EMars_Crawler_AttackPhase::Strike: return n"Strike";
            case EMars_Crawler_AttackPhase::Recover: return n"Recover";
            default: return NAME_None;
        }
    }

    // The reference clips' window over [Windup 0, Recover 1): accepted motion inside it may sweep and hit.
    FName Get_OffenseWindowId()
    {
        return n"Offense";
    }

    // The sum of a rig leg's segment lengths.
    float32 Get_ChainReach(const FCk_ProceduralLeg_Spec& InLeg)
    {
        const auto Lengths = InLeg.Get_Chain().Get_SegmentLengths();
        float32 Reach = 0.0f;
        for (int32 Index = 0; Index < Lengths.Num(); ++Index)
        { Reach += Lengths[Index]; }

        return Reach;
    }

    FString Get_FirstDiagnosticText(const FCk_ProceduralAction_ValidationReport& InReport)
    {
        const auto& Diagnostics = InReport.Get_Diagnostics();
        if (Diagnostics.Num() == 0)
        { return "no diagnostic"; }

        const auto& First = Diagnostics[0];
        return f"{First.Get_Code()} at [{First.Get_FieldPath()}] (expected [{First.Get_Expected()}], actual [{First.Get_Actual()}])";
    }

    // The slot the right claw (the rig's first leg) is bound to.
    FName Get_RightClawSlotId()
    {
        return n"ClawRight";
    }

    // The slot the left claw (the rig's last leg) is bound to.
    FName Get_LeftClawSlotId()
    {
        return n"ClawLeft";
    }

    // The whole clip's length.
    float64 Get_ClipSeconds(UCk_ProceduralAction_Data InClip)
    {
        float64 Seconds = 0.0;
        for (const auto& Phase : InClip.Get_Phases())
        { Seconds += Phase.Get_Duration().Get_Seconds(); }

        return Seconds;
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
