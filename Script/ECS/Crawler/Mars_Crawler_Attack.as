// The body jab's clip, rebuilt at every admission with the claws the attack claims, and its hit query. The clip action
// owns the motion's timing; the accepted intervals the query sweeps are UMars_Processor_Crawler_AttackResolve's, and the
// phases they report drive UMars_Processor_Crawler_AttackTick.
//
// Every attack query sets CollideWithBackFaces for convex bodies: Jolt keeps a convex cast hit only when that flag is set
// or the contact normal points along the cast direction, so without it a zero-travel query, or a sweep that starts inside
// a body, reports nothing for that body. With it, a body the sphere already overlaps at the start of a sample is reported
// at fraction 0 with the fallback up normal: a target there is a hit (the damage event carries that up normal), and a
// world body there blocks the sample, which closes the damage window and cancels the attack as Obstructed.

// One posed phase of the attack clip: the body offset it moves from and to, over Seconds, eased by Easing, and each claw
// slot's target at its start (ClawsFrom) and end (ClawsTo); no claw targets for a body-only jab.
struct FMars_Crawler_ClipPhase
{
    EMars_Crawler_AttackPhase Phase = EMars_Crawler_AttackPhase::Windup;
    float32 Seconds = 0.0f;
    ECk_ProceduralAction_Easing Easing = ECk_ProceduralAction_Easing::Linear;
    FTransform From = FTransform::Identity;
    FTransform To = FTransform::Identity;
    TArray<FCk_ProceduralAction_LimbPoseTarget> ClawsFrom;
    TArray<FCk_ProceduralAction_LimbPoseTarget> ClawsTo;

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

// What one attack's clip is built from: the combat profile's timing, body keys and pincer keys, and the claws the attack
// claimed, each with its Home set; no claws for a body-only jab.
struct FMars_Crawler_ClipBuild
{
    FMars_Crawler_Combat Combat;
    TArray<FMars_Crawler_AttackClaw> Claws;
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

    // The claw slot InClaw's leg is bound to: ClawRight for the right claw, ClawLeft for the left.
    FName Get_ClawSlotId(const FMars_Crawler_AttackClaw& InClaw)
    {
        return InClaw.Side > 0.0f ? n"ClawRight" : n"ClawLeft";
    }

    // The jab as a clip, built into InClip (which the caller keeps referenced). The body channel starts from the identity
    // offset: Windup moves it to the windup key, Strike to the strike key, Recover back to identity, each linear in space
    // and eased by its pose easing. Each claimed claw gets a slot whose keys are in the root's frame at the action's start
    // (the simulation body's, so they do not ride the body keys): Windup moves the foot from its Home to the windup key
    // on its side, Strike to the strike key, Recover back Home, eased like the body. Offense spans all three phases.
    // Returns the first rejected step's report, or Build_Into's; InClip is untouched unless the whole draft compiled.
    FCk_ProceduralAction_ValidationReport Build_AttackClip(const FMars_Crawler_ClipBuild& InBuild, UCk_ProceduralAction_Data InClip)
    {
        const auto& Timing = InBuild.Combat.Timing;
        const auto& Pose = InBuild.Combat.Pose;
        const auto& Pincer = InBuild.Combat.Pincer;
        auto Draft = FCk_ProceduralAction_ClipDraft();

        auto Body = FCk_ProceduralAction_BodyChannel();
        Body.Set_Enabled(true);
        Body.Set_InitialSource(ECk_ProceduralAction_InitialSource::IdentityOffset);
        auto Reports = TArray<FCk_ProceduralAction_ValidationReport>();
        Reports.Add(utils_procedural_action_builder::Set_BodyChannel(Draft, Body));

        auto Windup = FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Windup, Timing.WindupSeconds, Pose.WindupEasing,
            FTransform::Identity, Pose.Windup);
        auto Strike = FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Strike, Timing.StrikeSeconds, Pose.StrikeEasing,
            Pose.Windup, Pose.Strike);
        auto Recover = FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Recover, Timing.RecoverSeconds, Pose.RecoverEasing,
            Pose.Strike, FTransform::Identity);

        for (const auto& Claw : InBuild.Claws)
        {
            const auto Slot = Get_ClawSlotId(Claw);
            Reports.Add(utils_procedural_action_builder::Add_Slot(Draft, FCk_ProceduralAction_Slot(Slot)));

            const auto Home = FCk_ProceduralAction_LimbPoseTarget(Slot, Claw.Home.GetValue());
            const auto WindupKey = FCk_ProceduralAction_LimbPoseTarget(Slot, Make_ClawKey(Claw, Pincer.Windup));
            const auto StrikeKey = FCk_ProceduralAction_LimbPoseTarget(Slot, Make_ClawKey(Claw, Pincer.Strike));
            Windup.ClawsFrom.Add(Home);
            Windup.ClawsTo.Add(WindupKey);
            Strike.ClawsFrom.Add(WindupKey);
            Strike.ClawsTo.Add(StrikeKey);
            Recover.ClawsFrom.Add(StrikeKey);
            Recover.ClawsTo.Add(Home);
        }

        AddPosedPhase(Draft, Windup, Reports);
        AddPosedPhase(Draft, Strike, Reports);
        AddPosedPhase(Draft, Recover, Reports);

        for (const auto& Claw : InBuild.Claws)
        {
            Reports.Add(utils_procedural_action_builder::Set_SlotFrame(Draft, Get_ClawSlotId(Claw),
                ECk_ProceduralAction_TrackSpace::RootAtStart, NAME_None));
        }

        Reports.Add(utils_procedural_action_builder::Add_Window(Draft, FCk_ProceduralAction_Window(Get_OffenseWindowId(),
            FCk_ProceduralAction_TimeRef(Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup), FCk_FloatRange_0to1(0.0f)),
            FCk_ProceduralAction_TimeRef(Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover), FCk_FloatRange_0to1(1.0f)))));

        for (const auto& Report : Reports)
        {
            if (Report.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
            { return Report; }
        }

        return utils_procedural_action_builder::Build_Into(Draft, InClip);
    }

    // A pincer key on InClaw's side of the body.
    FVector Make_ClawKey(const FMars_Crawler_AttackClaw& InClaw, FVector InRightKey)
    {
        return FVector(InRightKey.X, InRightKey.Y * InClaw.Side, InRightKey.Z);
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

    FString Get_FirstDiagnosticText(const FCk_ProceduralAction_ValidationReport& InReport)
    {
        const auto& Diagnostics = InReport.Get_Diagnostics();
        if (Diagnostics.Num() == 0)
        { return "no diagnostic"; }

        const auto& First = Diagnostics[0];
        return f"{First.Get_Code()} at [{First.Get_FieldPath()}] (expected [{First.Get_Expected()}], actual [{First.Get_Actual()}])";
    }

    // One posed phase of the attack clip: its two pose keys at 0 and 1, each writing the body and every claw slot at once,
    // eased by InPhase.Easing.
    void AddPosedPhase(FCk_ProceduralAction_ClipDraft& InOutDraft, const FMars_Crawler_ClipPhase& InPhase,
        TArray<FCk_ProceduralAction_ValidationReport>& OutReports)
    {
        const auto PhaseId = Get_ClipPhaseId(InPhase.Phase);
        auto Phase = FCk_ProceduralAction_Phase(PhaseId, FCk_Time(float64(InPhase.Seconds)));
        Phase.Set_Easing(InPhase.Easing);
        OutReports.Add(utils_procedural_action_builder::Add_Phase(InOutDraft, Phase));

        auto Start = FCk_ProceduralAction_PoseKey(FCk_FloatRange_0to1(0.0f));
        Start.Set_BodyMode(ECk_ProceduralAction_ValueMode::Set);
        Start.Set_Body(InPhase.From);
        Start.Set_Limbs(InPhase.ClawsFrom);
        OutReports.Add(utils_procedural_action_builder::Add_PoseKey(InOutDraft, PhaseId, Start));

        auto End = FCk_ProceduralAction_PoseKey(FCk_FloatRange_0to1(1.0f));
        End.Set_BodyMode(ECk_ProceduralAction_ValueMode::Set);
        End.Set_Body(InPhase.To);
        End.Set_Limbs(InPhase.ClawsTo);
        OutReports.Add(utils_procedural_action_builder::Add_PoseKey(InOutDraft, PhaseId, End));
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
