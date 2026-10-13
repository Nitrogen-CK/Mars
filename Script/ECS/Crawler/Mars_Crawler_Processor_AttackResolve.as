// The attack's observer (armed crawlers only), in FGroup_Overlap after the probe processors have pushed this frame's
// transforms into the probe bodies, so a target moved this frame is queried where it now is. It writes only the
// observations mailbox; the attack tick consumes it on the next frame.
//
// A sample is acknowledged only by this action's accepted receipt with a new subject-pose revision; the presentation must
// then sit exactly on the settled transform. The receipt's clip interval is the attack's only clock: its PhaseId is the
// posed phase the attack tick enters, and the Offense window's exit in its events ends the posed motion. While the
// interval is inside the Offense window and no cancel closed the attack's damage window, the accepted hit centre is
// checked for displacement first (non-finite, a jump beyond MaxSampleTravel, the root beyond MaxRootDrift from its start
// or turned beyond the facing tolerance), and a displaced sample is never swept. Otherwise the sphere is swept from the
// previous accepted centre to this one, ignoring the crawler's own hurtboxes: a world body is an obstruction in any posed
// phase; in a Strike interval, before any damage was committed, the first hurtbox of the attack's target becomes the one
// candidate, and any other hurtbox (a bystander, a friend) is an obstruction. Validity of the target and the crawler is
// the attack tick's to judge at commit.

// One accepted receipt of a read page. Only the page's latest can match the presentation as it stands now.
struct FMars_Crawler_AcceptedReceipt
{
    FCk_ProceduralAction_Receipt Receipt;
    bool Latest = false;

    FMars_Crawler_AcceptedReceipt() {}

    FMars_Crawler_AcceptedReceipt(FCk_ProceduralAction_Receipt InReceipt, bool InLatest)
    {
        Receipt = InReceipt;
        Latest = InLatest;
    }
}

class UMars_Processor_Crawler_AttackResolve : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Overlap";
    default _RunAfter.Add(n"FProcessor_Probe_Setup");
    default _RunAfter.Add(n"FProcessor_Probe_HandleRequests");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateShape");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateTransform");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateTransform_LinearCast");

    private const float64 k_PresentationToleranceCm = 0.05;
    private const float64 k_PresentationToleranceDegrees = 0.05;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Crawler);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Self = InHandle.As_Crawler();
        auto& Attack = Self.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.ActionIdentity.Get_Value() == 0 || Attack.TerminalSeen || ck::Is_NOT_Valid(Self.Get_ActionPlayer()))
        { return; }

        if (utils_crawler::Get_IsAttackActionLost(Self))
        {
            Attack.WindowClosed = true;
            InObservations.ActionStreamFailed = true;
            InObservations.Candidate.Reset();
        }

        const auto Page = Self.Get_ActionPlayer().Read_Receipts(Attack.ActionIdentity, Attack.ReceiptCursor, 16);
        if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::Gap ||
            Page.Get_Result() == ECk_ProceduralAction_ReadResult::StreamExpired ||
            Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidCursor ||
            Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidPlayer)
        { InObservations.ActionStreamFailed = true; }

        const auto& Records = Page.Get_Records();
        auto LatestAccepted = -1;
        for (int32 Index = 0; Index < Records.Num(); ++Index)
        {
            if (Records[Index].Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose)
            { LatestAccepted = Index; }
        }

        for (int32 Index = 0; Index < Records.Num(); ++Index)
        {
            const auto& Record = Records[Index];
            if (Record.Get_Identity().Get_Value() != Attack.ActionIdentity.Get_Value())
            { InObservations.ActionStreamFailed = true; continue; }

            if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose &&
                InObservations.ActionStreamFailed == false)
            { ResolveAccepted(Self, FMars_Crawler_AcceptedReceipt(Record.Get_Receipt(), Index == LatestAccepted), InObservations); }
            else if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
            {
                Attack.TerminalSeen = true;
                if (Record.Get_Result().Get_Recovery() == ECk_ProceduralAction_Recovery::Failed)
                { InObservations.ActionStreamFailed = true; }
            }
        }

        if (Page.Get_LastStreamSequence() > Attack.ReceiptCursor)
        { Attack.ReceiptCursor = Page.Get_LastStreamSequence(); }
        if (Page.Get_Records().Num() > 0)
        {
            utils_procedural_action_player::Request_ConsumeReceipts(Self.Get_ActionPlayer(),
                FCk_Request_ProceduralActionPlayer_ConsumeReceipts(Attack.ActionIdentity, Attack.ReceiptCursor));
        }
    }

    private void ResolveAccepted(FCk_Handle_Crawler& Self, const FMars_Crawler_AcceptedReceipt& InAccepted,
        FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        const auto& Receipt = InAccepted.Receipt;
        if (Receipt.Get_HasAcceptedPose() == false ||
            Receipt.Get_Stamp().Get_SubjectPoseRevision() <= InObservations.AckRevision ||
            Receipt.Get_CurrentPose().Get_HasBodyPresentation() == false)
        { return; }

        const auto SampleId = Receipt.Get_Stamp().Get_SampleSequence();
        const auto Accepted = Receipt.Get_CurrentPose().Get_BodyPresentation();
        if (InAccepted.Latest)
        {
            const auto Presented = utils_transform::Get_EntityCurrentTransform(Self.Get_Presentation());
            const auto LocationError = (Presented.GetLocation() - Accepted.GetLocation()).Size();
            const auto AngleError = Math::RadiansToDegrees(Presented.GetRotation().AngularDistance(Accepted.GetRotation()));
            if (ck::EnsureIfNot(LocationError <= k_PresentationToleranceCm && AngleError <= k_PresentationToleranceDegrees,
                f"[Crawler] [{Self.ToString()}] the presentation [{Presented.GetLocation().ToString()}] is not the accepted action receipt [{Accepted.GetLocation().ToString()}] ({LocationError :.4} cm, {AngleError :.4} deg); sample [{SampleId}] stays unacknowledged"))
            { return; }
        }

        const auto Interval = Receipt.Get_Interval();
        InObservations.AckSampleId = SampleId;
        InObservations.AckRevision = Receipt.Get_Stamp().Get_SubjectPoseRevision();
        InObservations.AcceptedWorld = Accepted;
        InObservations.AcceptedInterval = Interval;
        ObservePhase(Interval, InObservations);

        const auto Combat = Self.Get_Spec().Combat;
        const auto Previous = InObservations.PreviousHitCenter;
        const auto Center = utils_crawler::Get_HitCenter(Accepted, Combat.Hit.LocalCenter);
        InObservations.PreviousHitCenter = Center;
        InObservations.AcceptedHitCenter = Center;

        if (Interval.Get_Windows().Contains(utils_crawler::Get_OffenseWindowId()) == false ||
            Self.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed)
        { return; }

        const auto Phase = utils_crawler::Find_ClipPhase(Interval.Get_PhaseId());

        if (Get_IsDisplaced(Self, Previous, Center))
        {
            InObservations.Displaced = TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Displaced);
            return;
        }

        InObservations.LongestSweep = Math::Max(InObservations.LongestSweep, float32((Center - Previous).Size()));

        auto Settings = utils_crawler::Make_AttackQuery(Previous, Center, Combat.Hit.Radius);
        Settings.Set_IgnoredEntities(Self.Get_AttackIgnoredEntities());
        FCk_Handle Tracer = Self;
        const auto Result = utils_probe_trace::Request_SingleShapeTrace(Tracer, Settings);

        if (Result.Get_HitKind() == ECk_ProbeTrace_HitKind::World)
        {
            InObservations.Obstructed = true;
            return;
        }

        if (ck::Is_NOT_Valid(Result.Get_HitEntity()) || Phase != EMars_Crawler_AttackPhase::Strike)
        { return; }

        if (Self.Get_AttackDamageCommitted() || InObservations.Candidate.IsSet())
        { return; }

        const auto Zone = utils_hit_zone::TryGet_Zone(Result.Get_HitEntity());
        auto Target = Self.Get_AttackTarget();
        const auto TargetZone = Target.As_HitZone(ECk_SanityCheck::UnChecked);
        FCk_Handle ZoneEntity = Zone;
        FCk_Handle TargetZoneEntity = TargetZone;
        if (ck::Is_NOT_Valid(Zone) || ck::Is_NOT_Valid(TargetZone) || ZoneEntity != TargetZoneEntity)
        {
            InObservations.Obstructed = true;
            return;
        }

        auto Candidate = FMars_Crawler_HitCandidate();
        Candidate.HitEntity = Result.Get_HitEntity();
        Candidate.Zone = Zone;
        Candidate.Target = Target;
        Candidate.Location = Result.Get_HitLocation();
        Candidate.Normal = Result.Get_SurfaceNormal();
        Candidate.Generation = Self.Get_AttackGeneration();
        Candidate.SampleId = SampleId;
        Candidate.HurtCount = Self.Get_HurtCount();
        InObservations.Candidate = TOptional<FMars_Crawler_HitCandidate>(Candidate);
    }

    // The posed phase only advances within an action (records arrive in order); the Offense exit is an event at the end
    // of the interval that reaches Recover's end.
    private void ObservePhase(const FCk_ProceduralAction_Interval& InInterval, FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        const auto Phase = utils_crawler::Find_ClipPhase(InInterval.Get_PhaseId());
        if (utils_crawler::Get_IsOffensivePhase(Phase) && int32(Phase) > int32(InObservations.AcceptedPhase))
        { InObservations.AcceptedPhase = Phase; }

        for (const auto& Event : InInterval.Get_Events())
        {
            if (Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowExit && Event.Get_Id() == utils_crawler::Get_OffenseWindowId())
            { InObservations.OffenseEnded = true; }
        }
    }

    private bool Get_IsDisplaced(const FCk_Handle_Crawler& InSelf, FVector InPrevious, FVector InCenter)
    {
        if (utils_crawler::Get_IsFinite(InCenter) == false)
        { return true; }

        const auto Combat = InSelf.Get_Spec().Combat;
        if ((InCenter - InPrevious).Size() > Combat.Hit.MaxSampleTravel)
        { return true; }

        const auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        const auto Root = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());
        if ((Root.GetLocation() - Attack.RootAtStart).Size() > Combat.Hit.MaxRootDrift)
        { return true; }

        const auto Up = utils_surface_motion::Get_SupportNormal(InSelf.Get_Motion()).GetSafeNormal();
        return utils_crawler::Get_PlanarAngleDegrees(Root.GetRotation().GetForwardVector(), Attack.CommittedDirection, Up) > Combat.Prepare.FacingToleranceDegrees;
    }
}
