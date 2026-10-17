// Accepted-only attack geometry, after this frame's probe transforms are published. Every source and active guard is
// validated before any cast. Stable emitter order and earliest contact select one candidate per receipt; any emitter's
// obstruction wipes even a candidate retained from an earlier receipt. AttackTick owns cancellation and the one damage ledger.

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
        auto& Attack = Self.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.ActionIdentity.Get_Value() == 0 || Attack.TerminalSeen)
        { return; }
        if (ck::Is_NOT_Valid(Self.Get_ActionPlayer()))
        { HandleUnavailableStream(Self, InObservations); return; }

        if (utils_crawler::Get_IsAttackActionLost(Self))
        {
            Attack.WindowClosed = true;
            InObservations.ActionStreamFailed = true;
            InObservations.StreamFailure = n"ActionLost";
            InObservations.Candidate.Reset();
        }

        for (int32 PageIndex = 0; PageIndex < 4; ++PageIndex)
        {
            const auto Page = Self.Get_ActionPlayer().Read_Receipts(Attack.ActionIdentity, Attack.ReceiptCursor, 16);
            if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidCursor)
            {
                FailStream(Self, InObservations, n"ReceiptGap");
                // Restart at the public stream origin; the next page identifies any consumed high-water gap.
                Attack.ReceiptCursor = 0;
                continue;
            }
            if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::StreamExpired || Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidPlayer)
            {
                HandleUnavailableStream(Self, InObservations);
                return;
            }
            if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::Gap)
            {
                // Gap pages still carry records after the consumed interval; terminal acknowledgement must survive.
                FailStream(Self, InObservations, n"ReceiptGap");
            }
            const auto Records = Page.Get_Records();
            const auto LatestAccepted = utils_crawler::Get_LatestAcceptedIndex(Page);
            for (int32 Index = 0; Index < Records.Num(); ++Index)
            {
                const auto Record = Records[Index];
                if (Record.Get_Identity().Get_Value() != Attack.ActionIdentity.Get_Value())
                { FailStream(Self, InObservations, n"ReceiptIdentity"); continue; }
                if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose && InObservations.ActionStreamFailed == false)
                { ResolveAccepted(Self, FMars_Crawler_AcceptedReceipt(Record.Get_Receipt(), Index == LatestAccepted), InObservations); }
                else if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
                {
                    Attack.TerminalSeen = true;
                    InObservations.Terminal = TOptional<FCk_ProceduralAction_Result>(Record.Get_Result());
                    InObservations.TerminalSource = n"Receipt";
                    if (Record.Get_Result().Get_Recovery() == ECk_ProceduralAction_Recovery::Failed)
                    { InObservations.ActionStreamFailed = true; }
                }
            }
            if (Page.Get_LastStreamSequence() > Attack.ReceiptCursor)
            { Attack.ReceiptCursor = Page.Get_LastStreamSequence(); }
            if (Records.Num() > 0)
            {
                utils_procedural_action_player::Request_ConsumeReceipts(Self.Get_ActionPlayer(),
                    FCk_Request_ProceduralActionPlayer_ConsumeReceipts(Attack.ActionIdentity, Attack.ReceiptCursor));
            }
            if (Page.Get_HasMore() == false || Attack.TerminalSeen)
            { break; }
        }
    }

    private void FailStream(FCk_Handle_Crawler& InSelf, FMars_Fragment_Crawler_AttackObservations& InObservations, FName InReason)
    {
        InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed = true;
        InObservations.ActionStreamFailed = true;
        InObservations.StreamFailure = InReason;
        InObservations.Candidate.Reset();
    }

    private void HandleUnavailableStream(FCk_Handle_Crawler& InSelf, FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        FailStream(InSelf, InObservations, n"StreamUnavailable");
        InObservations.StreamUnavailable = true;
        auto Action = InSelf.Get_AttackAction();
        FCk_Handle Entity = Action;
        // No receipt remains to acknowledge. The native player has already finished this owned action; release requests
        // cannot succeed through an invalid player, so dispose of only the finished entity and wait for actual removal.
        if (ck::IsValid(Action) && utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false &&
            Action.Get_State() == ECk_ProceduralAction_State::Finished)
        {
            InObservations.Terminal = TOptional<FCk_ProceduralAction_Result>(Action.Get_Result());
            InObservations.TerminalSource = n"FinishedActionSnapshot";
            utils_entity_lifetime::Request_DestroyEntity(Entity);
        }
    }

    private void ResolveAccepted(FCk_Handle_Crawler& Self, const FMars_Crawler_AcceptedReceipt& InAccepted,
        FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        const auto& Receipt = InAccepted.Receipt;
        const auto Stamp = Receipt.Get_Stamp();
        auto Evidence = FMars_Crawler_ReceiptEvidenceQuery();
        Evidence.ExpectedActionIdentity = Self.Get_Fragment(FMars_Fragment_Crawler_Attack).ActionIdentity;
        Evidence.AckSampleId = InObservations.AckSampleId;
        Evidence.AckRevision = InObservations.AckRevision;
        Evidence.ContentRevision = InObservations.ContentRevision;
        Evidence.TopologyRevision = InObservations.TopologyRevision;
        Evidence.Receipt = Receipt;
        const auto EvidenceResult = utils_crawler::Evaluate_AttackReceiptEvidence(Evidence);
        if (EvidenceResult.Skip)
        { return; }
        if (EvidenceResult.Failure.IsNone() == false)
        { FailStream(Self, InObservations, EvidenceResult.Failure); return; }
        auto CueObservation = FMars_Attack_CueObservation();
        CueObservation.Stamp = Stamp;
        CueObservation.Interval = Receipt.Get_Interval();
        CueObservation.ObservationFrame = utils_time::Get_FrameCounter();
        InObservations.PendingCueObservations.Add(CueObservation);
        InObservations.ContentRevision = Stamp.Get_ContentRevision();
        InObservations.TopologyRevision = Stamp.Get_TopologyRevision();
        if (Self.Get_AttackAdmission().Accepted == false && InObservations.FirstAccepted.IsSet() == false)
        { InObservations.FirstAccepted = TOptional<FCk_ProceduralAction_Stamp>(Stamp); }
        const auto Failures = utils_crawler::Evaluate_AttackContinuation(Self);
        if (Failures.Num() > 0)
        {
            Self.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed = true;
            InObservations.RequiredPartFailures = Failures;
            InObservations.Candidate.Reset();
            return;
        }
        const auto Plan = Self.Get_AttackPlan();
        auto Query = FMars_Crawler_EmitterQuery();
        Query.Plan = Plan;
        Query.Previous = Receipt.Get_PreviousPose();
        Query.Current = Receipt.Get_CurrentPose();
        Query.Interval = Receipt.Get_Interval();
        Query.Sample.Stamp = Stamp;
        Query.Sample.Generation = Self.Get_AttackGeneration();
        Query.Sample.ObservationFrame = utils_time::Get_FrameCounter();
        Query.GameWindowOpen = Self.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed == false;
        Query.Root.Current = utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
        Query.Root.AtStart = Self.Get_Fragment(FMars_Fragment_Crawler_Attack).RootAtStart;
        Query.Root.Direction = Self.Get_Fragment(FMars_Fragment_Crawler_Attack).CommittedDirection;
        Query.Root.SupportNormal = utils_surface_motion::Get_SupportNormal(Self.Get_Motion());
        const auto Extracted = utils_crawler::Extract_AttackEmitters(Query);
        if (Extracted.Failures.Num() > 0)
        {
            InObservations.EmitterFailures = Extracted.Failures;
            InObservations.Candidate.Reset();
            if (Extracted.Displaced)
            {
                Self.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed = true;
                InObservations.Displaced = TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Displaced);
            }
            else
            { FailStream(Self, InObservations, n"AcceptedSourceMissing"); }
            return;
        }
        if (InAccepted.Latest)
        {
            const auto PresentedFailures = Self.Evaluate_AttackEmitterPresentation(Extracted.Segments);
            if (PresentedFailures.Num() > 0)
            {
                InObservations.EmitterFailures = PresentedFailures;
                FailStream(Self, InObservations, n"AcceptedPresentationMismatch");
                return;
            }
        }
        InObservations.AcceptedEmitters = Extracted.Segments;
        InObservations.AckSampleId = Stamp.Get_SampleSequence();
        InObservations.AckRevision = Stamp.Get_SubjectPoseRevision();
        InObservations.AcceptedInterval = Query.Interval;
        ObservePhase(Query.Interval, Plan.Entry.Definition.Motion, InObservations);
        // Preserve the old first-authored-centre getters even though runtime query order is stable ID order.
        for (const auto& Segment : Extracted.Segments)
        {
            if (Segment.Emitter.Id == Plan.Entry.Definition.Hit.Emitters[0].Id)
            {
                InObservations.PreviousHitCenter = Segment.Geometry.To;
                InObservations.AcceptedHitCenter = Segment.Geometry.To;
                InObservations.AcceptedWorld = Segment.Geometry.CurrentFrame;
            }
        }
        if (Self.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed)
        { return; }
        auto Best = TOptional<FMars_Crawler_HitCandidate>();
        for (const auto& Segment : Extracted.Segments)
        {
            if (Segment.Activity.Obstruction == false)
            { continue; }
            InObservations.LongestSweep = Math::Max(InObservations.LongestSweep, Segment.Geometry.Travel);
            auto Settings = utils_crawler::Make_AttackQuery(Segment.Geometry.From, Segment.Geometry.To, Segment.Emitter.Radius);
            Settings.Set_IgnoredEntities(Self.Get_AttackIgnoredEntities());
            FCk_Handle Tracer = Self;
            const auto Hit = utils_probe_trace::Request_SingleShapeTrace(Tracer, Settings);
            if (Hit.Get_HitKind() == ECk_ProbeTrace_HitKind::World)
            {
                Self.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed = true;
                InObservations.Obstructed = true;
                InObservations.Candidate.Reset();
                return;
            }
            if (ck::Is_NOT_Valid(Hit.Get_HitEntity()))
            { continue; }
            // Body keeps its migrated Strike/damage-window bystander behavior. Endpoint offense is stricter: any other
            // entity blocks throughout its active sweep window, even before or after its damage window.
            if (Segment.Emitter.Source == EMars_Attack_EmitterSource::Body && Segment.Activity.Damage == false)
            { continue; }
            const auto Zone = utils_hit_zone::TryGet_Zone(Hit.Get_HitEntity());
            auto Target = Self.Get_AttackTarget();
            const auto TargetZone = Target.As_HitZone(ECk_SanityCheck::UnChecked);
            FCk_Handle ZoneEntity = Zone;
            FCk_Handle TargetZoneEntity = TargetZone;
            if (ck::Is_NOT_Valid(Zone) || ck::Is_NOT_Valid(TargetZone) || ZoneEntity != TargetZoneEntity)
            {
                Self.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed = true;
                InObservations.Obstructed = true;
                InObservations.Candidate.Reset();
                return;
            }
            if (Segment.Activity.Damage == false || Self.Get_AttackDamageCommitted() || InObservations.Candidate.IsSet())
            { continue; }
            const auto Fraction = Hit.Get_Fraction();
            if (Math::IsFinite(Fraction) == false || Fraction < 0.0f || Fraction > 1.0f ||
                utils_crawler::Get_IsFinite(Hit.Get_HitLocation()) == false || utils_crawler::Get_IsFinite(Hit.Get_SurfaceNormal()) == false)
            {
                InObservations.EmitterFailures.Add(utils_attack::Make_Blocker(n"HitContactInvalid", f"Hit.Emitters[{Segment.Emitter.Id.ToString()}]",
                    FMars_Attack_Comparison("finite contact and fraction 0..1", f"{Fraction}")));
                FailStream(Self, InObservations, n"HitContactInvalid");
                return;
            }
            auto Candidate = FMars_Crawler_HitCandidate();
            Candidate.HitEntity = Hit.Get_HitEntity();
            Candidate.Zone = Zone;
            Candidate.Target = Target;
            Candidate.Location = Hit.Get_HitLocation();
            Candidate.Normal = Hit.Get_SurfaceNormal();
            Candidate.Generation = Self.Get_AttackGeneration();
            Candidate.SampleId = Stamp.Get_SampleSequence();
            Candidate.HurtCount = Self.Get_HurtCount();
            Candidate.EmitterContact.EmitterId = Segment.Emitter.Id;
            Candidate.EmitterContact.Fraction = Fraction;
            if (Best.IsSet() == false || utils_crawler::Get_IsEarlierEmitterContact(Candidate.EmitterContact, Best.GetValue().EmitterContact))
            { Best = TOptional<FMars_Crawler_HitCandidate>(Candidate); }
        }
        if (Best.IsSet() && InObservations.Candidate.IsSet() == false)
        { InObservations.Candidate = Best; }
    }

    private EMars_Crawler_AttackPhase FindPhase(FName InPhase, const FMars_Attack_MotionContract& InMotion) const
    {
        if (InPhase == InMotion.WindupPhase) { return EMars_Crawler_AttackPhase::Windup; }
        if (InPhase == InMotion.StrikePhase) { return EMars_Crawler_AttackPhase::Strike; }
        if (InPhase == InMotion.RecoverPhase) { return EMars_Crawler_AttackPhase::Recover; }
        return EMars_Crawler_AttackPhase::Idle;
    }

    // The posed phase only advances within an action (records arrive in order); the Offense exit is an event at the end
    // of the interval that reaches Recover's end.
    private void ObservePhase(const FCk_ProceduralAction_Interval& InInterval, const FMars_Attack_MotionContract& InMotion, FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        const auto Phase = FindPhase(InInterval.Get_PhaseId(), InMotion);
        if (utils_crawler::Get_IsOffensivePhase(Phase) && int32(Phase) > int32(InObservations.AcceptedPhase))
        { InObservations.AcceptedPhase = Phase; }

        for (const auto& Event : InInterval.Get_Events())
        {
            if (Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowExit && Event.Get_Id() == InMotion.ObstructionWindow)
            { InObservations.OffenseEnded = true; }
        }
    }

}
