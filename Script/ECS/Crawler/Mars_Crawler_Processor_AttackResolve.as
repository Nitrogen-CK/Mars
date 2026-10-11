// The attack's observer (armed crawlers only), in FGroup_Overlap after the probe processors have pushed this frame's
// transforms into the probe bodies, so a target moved this frame is queried where it now is. It writes only the
// observations mailbox; the attack tick consumes it on the next frame.
//
// A sample is acknowledged when the body pose has published the attack's pending sample id with a new revision; the
// presentation must then sit exactly on the published transform (anything else is an integration failure, never a reason
// to query the requested pose instead). In Windup, Strike and Recover the accepted hit centre is checked for displacement
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
        const auto PendingSampleId = Self.Get_AttackPendingSampleId();
        if (PendingSampleId == 0)
        { return; }

        const auto Sample = utils_procedural_body_pose::Get_ActionSample(Self.Get_BodyPose());
        if (Sample.Get_SampleId() != PendingSampleId || Sample.Get_PoseRevision() <= InObservations.AckRevision)
        { return; }

        const auto Accepted = Sample.Get_WorldTransform();
        const auto Presented = utils_transform::Get_EntityCurrentTransform(Self.Get_Presentation());
        const auto LocationError = (Presented.GetLocation() - Accepted.GetLocation()).Size();
        const auto AngleError = Math::RadiansToDegrees(Presented.GetRotation().AngularDistance(Accepted.GetRotation()));
        if (ck::EnsureIfNot(LocationError <= k_PresentationToleranceCm && AngleError <= k_PresentationToleranceDegrees,
            f"[Crawler] [{Self.ToString()}] the presentation [{Presented.GetLocation().ToString()}] is not the published body pose sample [{Accepted.GetLocation().ToString()}] ({LocationError :.4} cm, {AngleError :.4} deg); sample [{PendingSampleId}] stays unacknowledged"))
        { return; }

        InObservations.AckSampleId = Sample.Get_SampleId();
        InObservations.AckRevision = Sample.Get_PoseRevision();
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
        Candidate.SampleId = Sample.Get_SampleId();
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
