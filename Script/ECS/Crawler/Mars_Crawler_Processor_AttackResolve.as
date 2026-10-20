// Accepted-only attack geometry, after this frame's probe transforms are published. Every source and active guard is
// validated before any cast. Stable emitter order and earliest contact select one candidate per receipt; any emitter's
// obstruction wipes even a candidate retained from an earlier receipt. This processor writes only the observations
// mailbox; AttackTick owns cancellation, the attack's window and the one damage ledger.

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
        const auto Identity = Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Stream.Identity;
        auto& Stream = InObservations.Stream;
        if (Identity.Get_Value() == 0 || Stream.TerminalSeen)
        { return; }

        if (ck::Is_NOT_Valid(Self.Get_ActionPlayer()))
        {
            HandleUnavailableStream(Self, InObservations);
            return;
        }

        if (utils_crawler::Get_IsAttackActionLost(Self))
        { FailStream(InObservations, n"ActionLost"); }

        for (int32 PageIndex = 0; PageIndex < 4; ++PageIndex)
        {
            const auto Page = Self.Get_ActionPlayer().Read_Receipts(Identity, Stream.Cursor, 16);
            if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidCursor)
            {
                FailStream(InObservations, n"ReceiptGap");
                // Restart at the public stream origin; the next page identifies any consumed high-water gap.
                Stream.Cursor = 0;
                continue;
            }

            if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::StreamExpired || Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidPlayer)
            {
                HandleUnavailableStream(Self, InObservations);
                return;
            }

            // A gap page still carries the records after the consumed interval; the terminal acknowledgement must survive.
            if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::Gap)
            { FailStream(InObservations, n"ReceiptGap"); }

            const auto Records = Page.Get_Records();
            const auto LatestAccepted = utils_crawler::Get_LatestAcceptedIndex(Page);
            for (int32 Index = 0; Index < Records.Num(); ++Index)
            {
                const auto Record = Records[Index];
                if (Record.Get_Identity().Get_Value() != Identity.Get_Value())
                {
                    FailStream(InObservations, n"ReceiptIdentity");
                    continue;
                }

                if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose && Stream.Failed == false)
                { ResolveAccepted(Self, FMars_Crawler_AcceptedReceipt(Record.Get_Receipt(), Index == LatestAccepted), InObservations); }
                else if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
                {
                    Stream.TerminalSeen = true;
                    Stream.Terminal = TOptional<FCk_ProceduralAction_Result>(Record.Get_Result());
                    Stream.TerminalSource = n"Receipt";
                    if (Record.Get_Result().Get_Recovery() == ECk_ProceduralAction_Recovery::Failed)
                    { Stream.Failed = true; }
                }
            }

            if (Page.Get_LastStreamSequence() > Stream.Cursor)
            { Stream.Cursor = Page.Get_LastStreamSequence(); }

            if (Records.Num() > 0)
            {
                utils_procedural_action_player::Request_ConsumeReceipts(Self.Get_ActionPlayer(),
                    FCk_Request_ProceduralActionPlayer_ConsumeReceipts(Identity, Stream.Cursor));
            }

            if (Page.Get_HasMore() == false || Stream.TerminalSeen)
            { break; }
        }
    }

    private void FailStream(FMars_Fragment_Crawler_AttackObservations& InObservations, FName InReason)
    {
        InObservations.Stream.WindowClosed = true;
        InObservations.Stream.Failed = true;
        InObservations.Stream.Failure = InReason;
        InObservations.Hit.Candidate.Reset();
    }

    private void CloseWindow(FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        InObservations.Stream.WindowClosed = true;
        InObservations.Hit.Candidate.Reset();
    }

    private void HandleUnavailableStream(FCk_Handle_Crawler& InSelf, FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        FailStream(InObservations, n"StreamUnavailable");
        InObservations.Stream.Unavailable = true;
        auto Action = InSelf.Get_AttackAction();
        FCk_Handle Entity = Action;
        // No receipt remains to acknowledge. The native player has already finished this owned action; release requests
        // cannot succeed through an invalid player, so dispose of only the finished entity and wait for actual removal.
        if (ck::IsValid(Action) && utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false &&
            Action.Get_State() == ECk_ProceduralAction_State::Finished)
        {
            InObservations.Stream.Terminal = TOptional<FCk_ProceduralAction_Result>(Action.Get_Result());
            InObservations.Stream.TerminalSource = n"FinishedActionSnapshot";
            utils_entity_lifetime::Request_DestroyEntity(Entity);
        }
    }

    private bool Get_IsWindowOpen(const FCk_Handle_Crawler& InSelf, const FMars_Fragment_Crawler_AttackObservations& InObservations) const
    {
        return InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed == false && InObservations.Stream.WindowClosed == false;
    }

    private void ResolveAccepted(FCk_Handle_Crawler& Self, const FMars_Crawler_AcceptedReceipt& InAccepted,
        FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        const auto& Receipt = InAccepted.Receipt;
        const auto Stamp = Receipt.Get_Stamp();
        auto& Stream = InObservations.Stream;
        auto& Hit = InObservations.Hit;
        auto Evidence = FMars_Crawler_ReceiptEvidenceQuery();
        Evidence.ExpectedActionIdentity = Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Stream.Identity;
        Evidence.AckSampleId = Stream.AckSampleId;
        Evidence.AckRevision = Stream.AckRevision;
        Evidence.ContentRevision = Stream.ContentRevision;
        Evidence.TopologyRevision = Stream.TopologyRevision;
        Evidence.Receipt = Receipt;
        const auto EvidenceResult = utils_crawler::Evaluate_AttackReceiptEvidence(Evidence);
        if (EvidenceResult.Skip)
        { return; }

        if (EvidenceResult.Failure.IsNone() == false)
        {
            FailStream(InObservations, EvidenceResult.Failure);
            return;
        }

        auto CueObservation = FMars_Attack_CueObservation();
        CueObservation.Stamp = Stamp;
        CueObservation.Interval = Receipt.Get_Interval();
        CueObservation.ObservationFrame = utils_time::Get_FrameCounter();
        InObservations.PendingCueObservations.Add(CueObservation);
        Stream.ContentRevision = Stamp.Get_ContentRevision();
        Stream.TopologyRevision = Stamp.Get_TopologyRevision();
        if (Self.Get_AttackAdmission().Accepted == false && Stream.FirstAccepted.IsSet() == false)
        { Stream.FirstAccepted = TOptional<FCk_ProceduralAction_Stamp>(Stamp); }

        const auto Failures = utils_crawler::Evaluate_AttackContinuation(Self);
        if (Failures.Num() > 0)
        {
            CloseWindow(InObservations);
            Hit.RequiredPartFailures = Failures;
            return;
        }

        const auto& Attack = Self.Get_Fragment(FMars_Fragment_Crawler_Attack);
        const auto Plan = Attack.Plan;
        auto Query = FMars_Crawler_EmitterQuery();
        Query.Plan = Plan;
        Query.Previous = Receipt.Get_PreviousPose();
        Query.Current = Receipt.Get_CurrentPose();
        Query.Interval = Receipt.Get_Interval();
        Query.Sample.Stamp = Stamp;
        Query.Sample.Generation = Attack.Generation;
        Query.Sample.ObservationFrame = utils_time::Get_FrameCounter();
        Query.GameWindowOpen = Get_IsWindowOpen(Self, InObservations);
        Query.Root.Current = utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
        Query.Root.AtStart = Attack.Start.Root;
        Query.Root.Direction = Attack.Start.Direction;
        Query.Root.SupportNormal = utils_surface_motion::Get_SupportNormal(Self.Get_Motion());
        const auto Extracted = utils_crawler::Extract_AttackEmitters(Query);
        if (Extracted.Failures.Num() > 0)
        {
            Hit.EmitterFailures = Extracted.Failures;
            if (Extracted.Displaced)
            {
                CloseWindow(InObservations);
                Hit.Displaced = TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Displaced);
            }
            else
            { FailStream(InObservations, n"AcceptedSourceMissing"); }

            return;
        }

        if (InAccepted.Latest)
        {
            const auto PresentedFailures = Self.Evaluate_AttackEmitterPresentation(Extracted.Segments);
            if (PresentedFailures.Num() > 0)
            {
                Hit.EmitterFailures = PresentedFailures;
                FailStream(InObservations, n"AcceptedPresentationMismatch");
                return;
            }
        }

        Hit.Emitters = Extracted.Segments;
        Stream.AckSampleId = Stamp.Get_SampleSequence();
        Stream.AckRevision = Stamp.Get_SubjectPoseRevision();
        InObservations.Accepted.Interval = Query.Interval;
        ObservePhase(Query.Interval, Plan.Entry.Definition.Motion, InObservations.Accepted);
        if (Get_IsWindowOpen(Self, InObservations) == false)
        { return; }

        auto Best = TOptional<FMars_Crawler_HitCandidate>();
        for (const auto& Segment : Extracted.Segments)
        {
            if (Segment.Activity.Obstruction == false)
            { continue; }

            Hit.LongestSweep = Math::Max(Hit.LongestSweep, Segment.Geometry.Travel);
            auto Settings = utils_crawler::Make_AttackQuery(Segment.Geometry.From, Segment.Geometry.To, Segment.Emitter.Radius);
            Settings.Set_IgnoredEntities(Self.Get_AttackIgnoredEntities());
            FCk_Handle Tracer = Self;
            const auto Trace = utils_probe_trace::Request_SingleShapeTrace(Tracer, Settings);
            if (Trace.Get_HitKind() == ECk_ProbeTrace_HitKind::World)
            {
                CloseWindow(InObservations);
                Hit.Obstructed = true;
                return;
            }

            if (ck::Is_NOT_Valid(Trace.Get_HitEntity()))
            { continue; }

            // A body emitter lets a bystander through outside its damage window; an endpoint emitter is stricter: any
            // other entity blocks throughout its active sweep window, even before or after its damage window.
            if (Segment.Emitter.Source == EMars_Attack_EmitterSource::Body && Segment.Activity.Damage == false)
            { continue; }

            const auto Zone = utils_hit_zone::TryGet_Zone(Trace.Get_HitEntity());
            auto Target = Self.Get_AttackTarget();
            const auto TargetZone = Target.As_HitZone(ECk_SanityCheck::UnChecked);
            FCk_Handle ZoneEntity = Zone;
            FCk_Handle TargetZoneEntity = TargetZone;
            if (ck::Is_NOT_Valid(Zone) || ck::Is_NOT_Valid(TargetZone) || ZoneEntity != TargetZoneEntity)
            {
                CloseWindow(InObservations);
                Hit.Obstructed = true;
                return;
            }

            if (Segment.Activity.Damage == false || Attack.Ledger.Committed || Hit.Candidate.IsSet())
            { continue; }

            const auto Fraction = Trace.Get_Fraction();
            if (Math::IsFinite(Fraction) == false || Fraction < 0.0f || Fraction > 1.0f ||
                utils_crawler::Get_IsFinite(Trace.Get_HitLocation()) == false || utils_crawler::Get_IsFinite(Trace.Get_SurfaceNormal()) == false)
            {
                Hit.EmitterFailures.Add(utils_attack::Make_Blocker(EMars_Attack_BlockerCode::HitContactInvalid, f"Hit.Emitters[{Segment.Emitter.Id.ToString()}]",
                    FMars_Attack_Comparison("finite contact and fraction 0..1", f"{Fraction}")));
                FailStream(InObservations, n"HitContactInvalid");
                return;
            }

            auto Candidate = FMars_Crawler_HitCandidate();
            Candidate.HitEntity = Trace.Get_HitEntity();
            Candidate.Zone = Zone;
            Candidate.Target = Target;
            Candidate.Location = Trace.Get_HitLocation();
            Candidate.Normal = Trace.Get_SurfaceNormal();
            Candidate.Generation = Attack.Generation;
            Candidate.SampleId = Stamp.Get_SampleSequence();
            Candidate.EmitterContact.EmitterId = Segment.Emitter.Id;
            Candidate.EmitterContact.Fraction = Fraction;
            if (Best.IsSet() == false || utils_crawler::Get_IsEarlierEmitterContact(Candidate.EmitterContact, Best.GetValue().EmitterContact))
            { Best = TOptional<FMars_Crawler_HitCandidate>(Candidate); }
        }

        if (Best.IsSet() && Hit.Candidate.IsSet() == false)
        { Hit.Candidate = Best; }
    }

    private EMars_Crawler_AttackPhase FindPhase(FName InPhase, const FMars_Attack_MotionContract& InMotion) const
    {
        if (InPhase == InMotion.WindupPhase)
        { return EMars_Crawler_AttackPhase::Windup; }

        if (InPhase == InMotion.StrikePhase)
        { return EMars_Crawler_AttackPhase::Strike; }

        if (InPhase == InMotion.RecoverPhase)
        { return EMars_Crawler_AttackPhase::Recover; }

        return EMars_Crawler_AttackPhase::Idle;
    }

    // The posed phase only advances within an action (records arrive in order); the Offense exit is an event at the end
    // of the interval that reaches Recover's end.
    private void ObservePhase(const FCk_ProceduralAction_Interval& InInterval, const FMars_Attack_MotionContract& InMotion, FMars_Crawler_AcceptedProgress& InOutAccepted)
    {
        const auto Phase = FindPhase(InInterval.Get_PhaseId(), InMotion);
        if (utils_crawler::Get_IsOffensivePhase(Phase) && int32(Phase) > int32(InOutAccepted.Phase))
        { InOutAccepted.Phase = Phase; }

        for (const auto& Event : InInterval.Get_Events())
        {
            if (Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowExit && Event.Get_Id() == InMotion.ObstructionWindow)
            { InOutAccepted.OffenseEnded = true; }
        }
    }
}
