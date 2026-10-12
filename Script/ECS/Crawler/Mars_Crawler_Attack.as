// The body jab's compiled clip and its hit query. The clip action owns the motion's timing; the accepted intervals the
// query sweeps are UMars_Processor_Crawler_AttackResolve's, and the phases they report drive
// UMars_Processor_Crawler_AttackTick.
//
// Every attack query sets CollideWithBackFaces for convex bodies: Jolt keeps a convex cast hit only when that flag is set
// or the contact normal points along the cast direction, so without it a zero-travel query, or a sweep that starts inside
// a body, reports nothing for that body. With it, a body the sphere already overlaps at the start of a sample is reported
// at fraction 0 with the fallback up normal: a target there is a hit (the damage event carries that up normal), and a
// world body there blocks the sample, which closes the damage window and cancels the attack as Obstructed.

// One posed phase of the attack clip: the body offset it moves from and to, over Seconds, eased by Easing.
struct FMars_Crawler_ClipPhase
{
    EMars_Crawler_AttackPhase Phase = EMars_Crawler_AttackPhase::Windup;
    float32 Seconds = 0.0f;
    ECk_ProceduralAction_Easing Easing = ECk_ProceduralAction_Easing::Linear;
    FTransform From = FTransform::Identity;
    FTransform To = FTransform::Identity;

    FMars_Crawler_ClipPhase() {}

    FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase InPhase, float32 InSeconds, ECk_ProceduralAction_Easing InEasing, FTransform InFrom, FTransform InTo)
    {
        Phase = InPhase;
        Seconds = InSeconds;
        Easing = InEasing;
        From = InFrom;
        To = InTo;
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

    // The clip phase that poses InPhase; None for the phases the clip does not pose.
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

    // The attack phase an accepted interval's PhaseId poses; Idle for any other id.
    EMars_Crawler_AttackPhase Find_ClipPhase(FName InPhaseId)
    {
        if (InPhaseId == Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup))
        { return EMars_Crawler_AttackPhase::Windup; }

        if (InPhaseId == Get_ClipPhaseId(EMars_Crawler_AttackPhase::Strike))
        { return EMars_Crawler_AttackPhase::Strike; }

        if (InPhaseId == Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover))
        { return EMars_Crawler_AttackPhase::Recover; }

        return EMars_Crawler_AttackPhase::Idle;
    }

    // The clip window over [Windup 0, Recover 1): accepted motion inside it may sweep and hit.
    FName Get_OffenseWindowId()
    {
        return n"Offense";
    }

    // A declared clip easing: Linear or one of the Quad and Cubic presets.
    bool Get_IsClipEasing(ECk_ProceduralAction_Easing InEasing)
    {
        return InEasing == ECk_ProceduralAction_Easing::Linear ||
            InEasing == ECk_ProceduralAction_Easing::InQuad || InEasing == ECk_ProceduralAction_Easing::OutQuad ||
            InEasing == ECk_ProceduralAction_Easing::InOutQuad || InEasing == ECk_ProceduralAction_Easing::InCubic ||
            InEasing == ECk_ProceduralAction_Easing::OutCubic || InEasing == ECk_ProceduralAction_Easing::InOutCubic;
    }

    // The jab as a clip on the body channel (identity offset at the start): Windup moves identity to the windup key,
    // Strike the windup key to the strike key, Recover the strike key back to identity, each linear in space and eased by
    // its pose easing; Offense spans all three. Built once per immutable combat spec into a new clip outered to InOwner,
    // which must keep it referenced (a UPROPERTY). A timing or pose that Validate rejects builds nothing: Add reports
    // that rejection.
    UCk_ProceduralAction_Data Make_AttackClip(const FMars_Crawler_Combat& InCombat, UObject InOwner)
    {
        if (InCombat.Timing.Validate().IsValid() == false || InCombat.Pose.Validate().IsValid() == false)
        { return nullptr; }

        const auto& Timing = InCombat.Timing;
        const auto& Pose = InCombat.Pose;
        auto Draft = FCk_ProceduralAction_ClipDraft();

        auto Body = FCk_ProceduralAction_BodyChannel();
        Body.Set_Enabled(true);
        Body.Set_InitialSource(ECk_ProceduralAction_InitialSource::IdentityOffset);
        auto Reports = TArray<FCk_ProceduralAction_ValidationReport>();
        Reports.Add(utils_procedural_action_builder::Set_BodyChannel(Draft, Body));

        AddPosedPhase(Draft, FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Windup, Timing.WindupSeconds, Pose.WindupEasing,
            FTransform::Identity, Pose.Windup), Reports);
        AddPosedPhase(Draft, FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Strike, Timing.StrikeSeconds, Pose.StrikeEasing,
            Pose.Windup, Pose.Strike), Reports);
        AddPosedPhase(Draft, FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Recover, Timing.RecoverSeconds, Pose.RecoverEasing,
            Pose.Strike, FTransform::Identity), Reports);

        Reports.Add(utils_procedural_action_builder::Add_Window(Draft, FCk_ProceduralAction_Window(Get_OffenseWindowId(),
            FCk_ProceduralAction_TimeRef(Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup), FCk_FloatRange_0to1(0.0f)),
            FCk_ProceduralAction_TimeRef(Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover), FCk_FloatRange_0to1(1.0f)))));

        auto Clip = Cast<UCk_ProceduralAction_Data>(NewObject(InOwner, UCk_ProceduralAction_Data));
        if (ck::EnsureIfNot(ck::IsValid(Clip), "[Crawler] could not create the attack clip object"))
        { return nullptr; }

        Reports.Add(utils_procedural_action_builder::Build_Into(Draft, Clip));
        for (const auto& Report : Reports)
        {
            const auto Built = Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid;
            if (ck::EnsureIfNot(Built, f"[Crawler] the attack clip did not build: {Get_FirstDiagnosticText(Report)}"))
            { return nullptr; }
        }

        return Clip;
    }

    FString Get_FirstDiagnosticText(const FCk_ProceduralAction_ValidationReport& InReport)
    {
        const auto& Diagnostics = InReport.Get_Diagnostics();
        if (Diagnostics.Num() == 0)
        { return "no diagnostic"; }

        const auto& First = Diagnostics[0];
        return f"{First.Get_Code()} at [{First.Get_FieldPath()}] (expected [{First.Get_Expected()}], actual [{First.Get_Actual()}])";
    }

    // One posed phase of the attack clip: its two body keys at 0 and 1, eased by InPhase.Easing.
    void AddPosedPhase(FCk_ProceduralAction_ClipDraft& InOutDraft, const FMars_Crawler_ClipPhase& InPhase,
        TArray<FCk_ProceduralAction_ValidationReport>& OutReports)
    {
        const auto PhaseId = Get_ClipPhaseId(InPhase.Phase);
        auto Phase = FCk_ProceduralAction_Phase(PhaseId, FCk_Time(float64(InPhase.Seconds)));
        Phase.Set_Easing(InPhase.Easing);
        OutReports.Add(utils_procedural_action_builder::Add_Phase(InOutDraft, Phase));
        OutReports.Add(utils_procedural_action_builder::Add_BodyKey(InOutDraft, PhaseId, FCk_ProceduralAction_TransformKey(
            FCk_FloatRange_0to1(0.0f), InPhase.From.GetLocation(), InPhase.From.GetRotation())));
        OutReports.Add(utils_procedural_action_builder::Add_BodyKey(InOutDraft, PhaseId, FCk_ProceduralAction_TransformKey(
            FCk_FloatRange_0to1(1.0f), InPhase.To.GetLocation(), InPhase.To.GetRotation())));
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
