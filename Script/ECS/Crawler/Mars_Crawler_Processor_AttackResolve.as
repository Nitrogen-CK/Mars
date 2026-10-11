// The attack's observer (armed crawlers only), in FGroup_Overlap after the probe processors have pushed this frame's
// transforms into the probe bodies, so a target moved this frame is queried where it now is. It writes only the
// observations mailbox; the attack tick consumes it on the next frame.
//
// A sample is acknowledged only by this action's accepted, correlated receipt with a new subject-pose revision; the
// presentation must then sit exactly on the settled transform. In Windup, Strike and Recover the accepted hit centre
// is checked for displacement
// first (non-finite, a jump beyond MaxSampleTravel, the root beyond MaxRootDrift from its start or turned beyond the facing
// tolerance), and a displaced sample is never swept. Otherwise the sphere is swept from the previous accepted centre to
// this one, ignoring the crawler's own hurtboxes: a world body is an obstruction in any of the three phases; in Strike,
// before any damage was committed, the first hurtbox of the attack's target becomes the one candidate, and any other
// hurtbox (a bystander, a friend) is an obstruction. Validity of the target and the crawler is the attack tick's to judge
// at commit.
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
        if (Attack.ActionIdentity.Get_Value() == 0 || ck::Is_NOT_Valid(Self.Get_ActionPlayer()))
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

        for (const auto& Record : Page.Get_Records())
        {
            if (Record.Get_Identity().Get_Value() != Attack.ActionIdentity.Get_Value())
            { InObservations.ActionStreamFailed = true; continue; }

            if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose &&
                InObservations.ActionStreamFailed == false)
            { ResolveAccepted(Self, Record.Get_Receipt(), InObservations); }
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
            const auto Consume = FCk_Request_ProceduralActionPlayer_ConsumeReceipts(
                Attack.ActionIdentity, Attack.ReceiptCursor);
            if (Attack.TerminalSeen && Attack.TerminalConsumeIssued == false)
            {
                Attack.TerminalConsumeIssued = true;
                utils_procedural_action_player::Request_ConsumeReceipts(Self.Get_ActionPlayer(), Consume,
                    FCk_Delegate_Request_OnCompleted(this, n"OnTerminalConsumed"));
            }
            else
            { utils_procedural_action_player::Request_ConsumeReceipts(Self.Get_ActionPlayer(), Consume); }
        }
    }

    UFUNCTION()
    private void OnTerminalConsumed(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        if (ck::Is_NOT_Valid(InRequestOwner))
        { return; }

        const auto Crawler = InRequestOwner.As_Crawler();
        if (ck::Is_NOT_Valid(Crawler) || Crawler.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
        { return; }

        auto& Attack = Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.TerminalSeen == false || Attack.TerminalConsumeIssued == false || Attack.TerminalConsumeSucceeded)
        { return; }

        if (InResult == ECk_Request_OperationResult::Succeeded)
        { Attack.TerminalConsumeSucceeded = true; }
        else
        { Crawler.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).ActionStreamFailed = true; }
    }

    private void ResolveAccepted(FCk_Handle_Crawler& Self, const FCk_ProceduralAction_Receipt& InReceipt,
        FMars_Fragment_Crawler_AttackObservations& InObservations)
    {
        const auto PendingSampleId = Self.Get_AttackPendingSampleId();
        if (PendingSampleId == 0 || InReceipt.Get_HasAcceptedPose() == false ||
            InReceipt.Get_CorrelationToken() != PendingSampleId ||
            InReceipt.Get_Stamp().Get_SubjectPoseRevision() <= InObservations.AckRevision ||
            InReceipt.Get_CurrentPose().Get_HasBodyPresentation() == false)
        { return; }

        const auto Accepted = InReceipt.Get_CurrentPose().Get_BodyPresentation();
        const auto Presented = utils_transform::Get_EntityCurrentTransform(Self.Get_Presentation());
        const auto LocationError = (Presented.GetLocation() - Accepted.GetLocation()).Size();
        const auto AngleError = Math::RadiansToDegrees(Presented.GetRotation().AngularDistance(Accepted.GetRotation()));
        if (ck::EnsureIfNot(LocationError <= k_PresentationToleranceCm && AngleError <= k_PresentationToleranceDegrees,
            f"[Crawler] [{Self.ToString()}] the presentation [{Presented.GetLocation().ToString()}] is not the accepted action receipt [{Accepted.GetLocation().ToString()}] ({LocationError :.4} cm, {AngleError :.4} deg); sample [{PendingSampleId}] stays unacknowledged"))
        { return; }

        InObservations.AckSampleId = PendingSampleId;
        InObservations.AckRevision = InReceipt.Get_Stamp().Get_SubjectPoseRevision();
        InObservations.AcceptedWorld = Accepted;

        const auto Combat = Self.Get_Spec().Combat;
        const auto Previous = InObservations.PreviousHitCenter;
        const auto Center = utils_crawler::Get_HitCenter(Accepted, Combat.Hit.LocalCenter);
        InObservations.PreviousHitCenter = Center;
        InObservations.AcceptedHitCenter = Center;

        const auto Phase = Self.Get_AttackPhase();
        if (utils_crawler::Get_IsOffensivePhase(Phase) == false)
        { return; }

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
        Candidate.SampleId = PendingSampleId;
        Candidate.HurtCount = Self.Get_HurtCount();
        InObservations.Candidate = TOptional<FMars_Crawler_HitCandidate>(Candidate);
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
