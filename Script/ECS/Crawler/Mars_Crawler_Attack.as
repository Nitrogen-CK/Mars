// The attack's clips, as the combat profile names them (authored assets the entity script loads), what the kernel reads
// from them, and the attack's hit query. The clip action owns the motion's timing; the accepted intervals the query
// sweeps are UMars_Processor_Crawler_AttackResolve's, and the phases they report drive UMars_Processor_Crawler_AttackTick.
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

    // The claw slot InClaw's leg is bound to: ClawRight for the right claw, ClawLeft for the left.
    FName Get_ClawSlotId(const FMars_Crawler_AttackClaw& InClaw)
    {
        return InClaw.Side > 0.0f ? Get_RightClawSlotId() : Get_LeftClawSlotId();
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

    // Jab or Pincer: the clip kind as authored assets and messages name it.
    FString Get_ClipKindName(EMars_Crawler_AttackClipKind InKind)
    {
        return InKind == EMars_Crawler_AttackClipKind::Pincer ? "Pincer" : "Jab";
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

    // The clip's phase that poses InPhase; unset when the clip has none (Validate_AttackClip rejects such a clip).
    TOptional<FCk_ProceduralAction_Phase> Find_Phase(UCk_ProceduralAction_Data InClip, EMars_Crawler_AttackPhase InPhase)
    {
        const auto PhaseId = Get_ClipPhaseId(InPhase);
        for (const auto& Phase : InClip.Get_Phases())
        {
            if (Phase.Get_Id() == PhaseId)
            { return TOptional<FCk_ProceduralAction_Phase>(Phase); }
        }

        return TOptional<FCk_ProceduralAction_Phase>();
    }

    // Where InPhase ends on the clip's timeline: the durations of every phase up to and including it.
    float64 Get_PhaseEndSeconds(UCk_ProceduralAction_Data InClip, EMars_Crawler_AttackPhase InPhase)
    {
        const auto PhaseId = Get_ClipPhaseId(InPhase);
        float64 End = 0.0;
        for (const auto& Phase : InClip.Get_Phases())
        {
            End += Phase.Get_Duration().Get_Seconds();
            if (Phase.Get_Id() == PhaseId)
            { return End; }
        }

        ck::EnsureIfNot(false, f"[Crawler] attack clip [{InClip.GetName()}] has no phase [{PhaseId}]");
        return End;
    }

    // The whole clip's length.
    float64 Get_ClipSeconds(UCk_ProceduralAction_Data InClip)
    {
        float64 Seconds = 0.0;
        for (const auto& Phase : InClip.Get_Phases())
        { Seconds += Phase.Get_Duration().Get_Seconds(); }

        return Seconds;
    }

    // The body offset InPhase's last body key holds, in the simulation body's axes.
    FTransform Get_PhaseEndBody(UCk_ProceduralAction_Data InClip, EMars_Crawler_AttackPhase InPhase)
    {
        const auto Phase = Find_Phase(InClip, InPhase);
        if (ck::EnsureIfNot(Phase.IsSet() && Phase.GetValue().Get_BodyKeys().Num() > 0,
            f"[Crawler] attack clip [{InClip.GetName()}] has no body key in phase [{Get_ClipPhaseId(InPhase)}]"))
        { return FTransform::Identity; }

        const auto Keys = Phase.GetValue().Get_BodyKeys();
        const auto& Key = Keys.Last();
        return FTransform(Key.Get_Rotation(), Key.Get_Translation(), FVector::OneVector);
    }

    // What the kernel relies on in an attack clip, the first broken rule named with the clip: the phases Windup, Strike
    // and Recover in that order, an Offense window, the body channel, the windup's end key pitch-only and the strike's
    // translation-only (the straight sample-to-sample hit sweep then covers the arc the hit centre travels, see
    // Get_IsPitchOnly), and the slots of its kind: none for a jab, exactly ClawRight and ClawLeft for a pincer. The
    // clip's own compiler checks everything else when the action is created.
    FMars_Validation Validate_AttackClip(UCk_ProceduralAction_Data InClip, EMars_Crawler_AttackClipKind InKind)
    {
        const FString Label = f"{Get_ClipKindName(InKind)}Clip";
        const auto Name = InClip.GetName();

        const auto Phases = InClip.Get_Phases();
        auto PhaseIds = FString();
        for (const auto& Phase : Phases)
        { PhaseIds += f" {Phase.Get_Id()}"; }

        if (Phases.Num() != 3 || Phases[0].Get_Id() != Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup) ||
            Phases[1].Get_Id() != Get_ClipPhaseId(EMars_Crawler_AttackPhase::Strike) ||
            Phases[2].Get_Id() != Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover))
        { return FMars_Validation(f"Crawler combat {Label} [{Name}] needs the phases Windup, Strike and Recover in that order (got [{PhaseIds} ])"); }

        auto HasOffense = false;
        for (const auto& Window : InClip.Get_Windows())
        { HasOffense = HasOffense || Window.Get_Id() == Get_OffenseWindowId(); }

        if (HasOffense == false)
        { return FMars_Validation(f"Crawler combat {Label} [{Name}] has no {Get_OffenseWindowId()} window"); }

        if (InClip.Get_BodyChannel().Get_Enabled() == false)
        { return FMars_Validation(f"Crawler combat {Label} [{Name}] does not drive the body channel"); }

        if (Phases[0].Get_BodyKeys().Num() == 0 || Phases[1].Get_BodyKeys().Num() == 0)
        { return FMars_Validation(f"Crawler combat {Label} [{Name}] has no body key in its Windup or Strike phase"); }

        const auto Windup = Get_PhaseEndBody(InClip, EMars_Crawler_AttackPhase::Windup);
        if (Get_IsPitchOnly(Windup) == false)
        { return FMars_Validation(f"Crawler combat {Label} [{Name}] needs a finite, unit-scale Windup end key pitched by at most {MaxWindupPitchDegrees} degrees (got [{Windup.GetLocation().ToString()} {Windup.Rotator().ToString()}])"); }

        const auto Strike = Get_PhaseEndBody(InClip, EMars_Crawler_AttackPhase::Strike);
        if (Get_IsTranslationOnly(Strike) == false)
        { return FMars_Validation(f"Crawler combat {Label} [{Name}] needs a finite, unit-scale, translation-only Strike end key (got [{Strike.GetLocation().ToString()} {Strike.Rotator().ToString()}])"); }

        const auto Slots = InClip.Get_Slots();
        auto SlotIds = FString();
        auto HasRight = false;
        auto HasLeft = false;
        for (const auto& Slot : Slots)
        {
            SlotIds += f" {Slot.Get_Id()}";
            HasRight = HasRight || Slot.Get_Id() == Get_RightClawSlotId();
            HasLeft = HasLeft || Slot.Get_Id() == Get_LeftClawSlotId();
        }

        if (InKind == EMars_Crawler_AttackClipKind::Jab && Slots.Num() != 0)
        { return FMars_Validation(f"Crawler combat {Label} [{Name}] is the body-only jab and declares no slots (got [{SlotIds} ])"); }

        if (InKind == EMars_Crawler_AttackClipKind::Pincer && (Slots.Num() != 2 || HasRight == false || HasLeft == false))
        { return FMars_Validation(f"Crawler combat {Label} [{Name}] needs exactly the slots ClawRight and ClawLeft (got [{SlotIds} ])"); }

        return FMars_Validation();
    }

    // Finite, unit scale, identity rotation: what a clip's strike end key must be.
    bool Get_IsTranslationOnly(const FTransform& InTransform)
    {
        if (Get_IsFinite(InTransform.GetLocation()) == false || Get_IsFinite(InTransform.GetScale3D()) == false || InTransform.ContainsNaN())
        { return false; }

        return (InTransform.GetScale3D() - FVector::OneVector).IsNearlyZero(KINDA_SMALL_NUMBER) &&
            InTransform.GetRotation().IsIdentity(KINDA_SMALL_NUMBER);
    }

    // The most a clip's windup end key may pitch the body (rear it up or dip it, about its own Y axis). The hit centre
    // then travels an arc while the straight sample-to-sample hit query covers its chords; at this limit a whole phase
    // posed in one sample leaves the chord about 4 cm inside the arc for a hit centre 55 cm from the body's origin, well
    // inside the hit sphere. Yaw and roll would swing the hit centre off the committed direction and stay rejected.
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
