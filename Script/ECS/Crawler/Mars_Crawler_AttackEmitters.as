// Copied accepted geometry only. Extraction has no live reads, casts, requests or fragment writes.
struct FMars_Crawler_EmitterSample
{
    UPROPERTY() FCk_ProceduralAction_Stamp Stamp;
    UPROPERTY() int32 Generation = 0;
    // Game overlap observation/query frame; independent of the native sample and the later damage commit frame.
    UPROPERTY() int64 ObservationFrame = 0;
}

struct FMars_Crawler_EmitterGeometry
{
    UPROPERTY() FTransform PreviousFrame = FTransform::Identity;
    UPROPERTY() FTransform CurrentFrame = FTransform::Identity;
    UPROPERTY() FVector From = FVector::ZeroVector;
    UPROPERTY() FVector To = FVector::ZeroVector;
    UPROPERTY() float32 Travel = 0.0f;
}

struct FMars_Crawler_EmitterActivity
{
    UPROPERTY() bool Obstruction = false;
    UPROPERTY() bool Damage = false;
}

struct FMars_Crawler_EmitterSegment
{
    UPROPERTY() FMars_Attack_Emitter Emitter;
    UPROPERTY() FName LimbId;
    UPROPERTY() FMars_Crawler_EmitterGeometry Geometry;
    UPROPERTY() FMars_Crawler_EmitterActivity Activity;
    UPROPERTY() FMars_Crawler_EmitterSample Sample;
}

struct FMars_Crawler_EmitterContact
{
    UPROPERTY() FGameplayTag EmitterId;
    UPROPERTY() float32 Fraction = 0.0f;
}

struct FMars_Crawler_EmitterRoot
{
    FTransform Current = FTransform::Identity;
    FVector AtStart = FVector::ZeroVector;
    FVector Direction = FVector::ForwardVector;
    FVector SupportNormal = FVector::UpVector;
}

struct FMars_Crawler_EmitterQuery
{
    FMars_Attack_ResolvedPlan Plan;
    FCk_ProceduralArticulation_Pose Previous;
    FCk_ProceduralArticulation_Pose Current;
    FCk_ProceduralAction_Interval Interval;
    FMars_Crawler_EmitterSample Sample;
    FMars_Crawler_EmitterRoot Root;
    bool GameWindowOpen = true;
}

struct FMars_Crawler_EmitterExtraction
{
    TArray<FMars_Crawler_EmitterSegment> Segments;
    TArray<FMars_Attack_Blocker> Failures;
    bool Displaced = false;
}

struct FMars_Crawler_EmitterSourceQuery
{
    FMars_Attack_Emitter Emitter;
    TArray<FMars_Attack_ResolvedSlot> Slots;
    FCk_ProceduralArticulation_Pose Pose;
}

struct FMars_Crawler_EmitterSourceFrame
{
    bool Found = false;
    FTransform Frame = FTransform::Identity;
    FName LimbId;
}

struct FMars_Crawler_ReceiptEvidenceQuery
{
    FCk_ProceduralAction_Identity ExpectedActionIdentity;
    int64 AckSampleId = 0;
    int64 AckRevision = 0;
    int64 ContentRevision = 0;
    int64 TopologyRevision = 0;
    FCk_ProceduralAction_Receipt Receipt;
}

struct FMars_Crawler_ReceiptEvidenceResult
{
    bool Skip = false;
    FName Failure;
}

namespace utils_crawler
{
    // Preserve the resolver's duplicate/nonaccepted skip precedence. Fresh evidence must match the current stream;
    // the native publisher seals FirstSample to the first publication, so it cannot resume an acknowledged stream.
    FMars_Crawler_ReceiptEvidenceResult Evaluate_AttackReceiptEvidence(const FMars_Crawler_ReceiptEvidenceQuery& InQuery)
    {
        auto Result = FMars_Crawler_ReceiptEvidenceResult();
        const auto Stamp = InQuery.Receipt.Get_Stamp();
        if (InQuery.Receipt.Get_HasAcceptedPose() == false || Stamp.Get_SubjectPoseRevision() <= InQuery.AckRevision ||
            Stamp.Get_SampleSequence() <= InQuery.AckSampleId)
        {
            Result.Skip = true;
            return Result;
        }

        if (Stamp.Get_Identity().Get_Value() != InQuery.ExpectedActionIdentity.Get_Value() ||
            (InQuery.ContentRevision != 0 && InQuery.ContentRevision != Stamp.Get_ContentRevision()) ||
            (InQuery.TopologyRevision != 0 && InQuery.TopologyRevision != Stamp.Get_TopologyRevision()))
        {
            Result.Failure = n"ContentChanged";
            return Result;
        }

        const auto Continuity = InQuery.Receipt.Get_Interval().Get_Continuity();
        if ((Continuity != ECk_ProceduralAction_Continuity::Continuous && Continuity != ECk_ProceduralAction_Continuity::FirstSample) ||
            (Continuity == ECk_ProceduralAction_Continuity::FirstSample && (InQuery.AckSampleId > 0 || InQuery.AckRevision > 0)))
        { Result.Failure = n"ReceiptGap"; }

        return Result;
    }

    // A page with more records is historical, even when its last record is an accepted pose.
    int32 Get_LatestAcceptedIndex(const FCk_ProceduralAction_ReadPage& InPage)
    {
        if (InPage.Get_HasMore())
        { return -1; }

        auto Latest = -1;
        const auto Records = InPage.Get_Records();
        for (int32 Index = 0; Index < Records.Num(); ++Index)
        {
            if (Records[Index].Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose)
            { Latest = Index; }
        }

        return Latest;
    }

    bool Get_IsEmitterFrameFinite(const FTransform& InFrame)
    {
        const auto Rotation = InFrame.GetRotation();
        const auto Norm = Rotation.X * Rotation.X + Rotation.Y * Rotation.Y + Rotation.Z * Rotation.Z + Rotation.W * Rotation.W;
        return InFrame.ContainsNaN() == false && Get_IsFinite(InFrame.GetLocation()) && Get_IsFinite(InFrame.GetScale3D()) &&
            Math::IsFinite(Rotation.X) && Math::IsFinite(Rotation.Y) && Math::IsFinite(Rotation.Z) && Math::IsFinite(Rotation.W) &&
            Math::IsFinite(Norm) && Math::Abs(Norm - 1.0) <= KINDA_SMALL_NUMBER;
    }

    bool Get_IsEmitterFrameRigid(const FTransform& InFrame)
    {
        return Get_IsEmitterFrameFinite(InFrame) && (InFrame.GetScale3D() - FVector::OneVector).IsNearlyZero(KINDA_SMALL_NUMBER);
    }

    FMars_Crawler_EmitterSourceFrame Find_AttackEmitterSource(const FMars_Crawler_EmitterSourceQuery& InQuery)
    {
        auto Result = FMars_Crawler_EmitterSourceFrame();
        if (InQuery.Emitter.Source == EMars_Attack_EmitterSource::Body)
        {
            Result.Found = InQuery.Pose.Get_HasBodyPresentation();
            if (Result.Found)
            { Result.Frame = InQuery.Pose.Get_BodyPresentation(); }

            return Result;
        }

        if (InQuery.Emitter.Source != EMars_Attack_EmitterSource::LimbEndpoint || InQuery.Emitter.LocalCenter.IsNearlyZero(0.0) == false)
        { return Result; }

        auto SlotMatches = 0;
        for (const auto& Slot : InQuery.Slots)
        {
            if (Slot.Slot == InQuery.Emitter.Slot && Slot.Binding.Source == EMars_Attack_AnatomySource::ProceduralLimb && Slot.Binding.LimbId.IsNone() == false)
            {
                Result.LimbId = Slot.Binding.LimbId;
                ++SlotMatches;
            }
        }

        if (SlotMatches != 1)
        { return Result; }

        auto LimbMatches = 0;
        for (const auto& Limb : InQuery.Pose.Get_Limbs())
        {
            if (Limb.Get_Id() == Result.LimbId)
            {
                Result.Frame = Limb.Get_AcceptedEndpoint();
                ++LimbMatches;
            }
        }

        Result.Found = LimbMatches == 1;
        return Result;
    }

    void Add_AttackEmitterFailure(FMars_Crawler_EmitterExtraction& InResult, const FMars_Attack_Emitter& InEmitter, EMars_Attack_BlockerCode InCode)
    {
        auto Failure = utils_attack::Make_Blocker(InCode, f"Hit.Emitters[{InEmitter.Id.ToString()}]",
            FMars_Attack_Comparison("unique accepted rigid source within authored bounds", f"{InCode :n}"));
        Failure.Slot = InEmitter.Slot;
        InResult.Failures.Add(Failure);
    }

    // The root guards of an active sample: the accepted root frames are rigid, and while any emitter sweeps, the live root
    // stays finite, within MaxRootDrift of where the attack started and within the facing tolerance of its direction.
    void Check_AttackEmitterRoot(const FMars_Crawler_EmitterQuery& InQuery, bool InAnyActive, FMars_Crawler_EmitterExtraction& InOutResult)
    {
        if (Get_IsEmitterFrameRigid(InQuery.Previous.Get_RootFrame()) == false || Get_IsEmitterFrameRigid(InQuery.Current.Get_RootFrame()) == false)
        {
            InOutResult.Displaced = true;
            InOutResult.Failures.Add(utils_attack::Make_Blocker(EMars_Attack_BlockerCode::AcceptedRootInvalid, "Accepted.RootFrame", FMars_Attack_Comparison("finite rigid frames", "invalid")));
        }

        if (InAnyActive == false)
        { return; }

        const auto ValidRoot = Get_IsEmitterFrameRigid(InQuery.Root.Current) && Get_IsFinite(InQuery.Root.AtStart) &&
            Get_IsFinite(InQuery.Root.Direction) && InQuery.Root.Direction.IsNearlyZero() == false &&
            Get_IsFinite(InQuery.Root.SupportNormal) && InQuery.Root.SupportNormal.IsNearlyZero() == false;
        if (ValidRoot == false)
        {
            InOutResult.Displaced = true;
            InOutResult.Failures.Add(utils_attack::Make_Blocker(EMars_Attack_BlockerCode::RootInvalid, "Root", FMars_Attack_Comparison("finite root and nonzero facing/support vectors", "invalid")));
            return;
        }

        const auto Drift = (InQuery.Root.Current.GetLocation() - InQuery.Root.AtStart).Size();
        const auto Facing = Get_PlanarAngleDegrees(InQuery.Root.Current.GetRotation().GetForwardVector(),
            InQuery.Root.Direction, InQuery.Root.SupportNormal.GetSafeNormal());
        const auto MaxDrift = InQuery.Plan.Execution.MaxRootDrift;
        if (Math::IsFinite(Drift) == false || Math::IsFinite(MaxDrift) == false || Drift > MaxDrift || MaxDrift < 0.0f)
        {
            InOutResult.Displaced = true;
            InOutResult.Failures.Add(utils_attack::Make_Blocker(EMars_Attack_BlockerCode::RootDrift, "Root.Distance", FMars_Attack_Comparison(f"<= {MaxDrift}", f"{Drift}")));
        }

        const auto Limit = InQuery.Plan.Entry.Definition.Prepare.FacingToleranceDegrees;
        if (Math::IsFinite(Facing) == false || Math::IsFinite(Limit) == false || Facing > Limit || Limit < 0.0f)
        {
            InOutResult.Displaced = true;
            InOutResult.Failures.Add(utils_attack::Make_Blocker(EMars_Attack_BlockerCode::FacingDrift, "Root.FacingDegrees", FMars_Attack_Comparison(f"<= {Limit}", f"{Facing}")));
        }
    }

    // One emitter's accepted segment from the previous to the current pose, added to InOutResult; a failure instead when its
    // source is missing, ambiguous or not rigid, or when an active sample travels further than the emitter allows.
    void Add_AttackEmitterSegment(const FMars_Crawler_EmitterQuery& InQuery, const FMars_Attack_Emitter& InEmitter, FMars_Crawler_EmitterExtraction& InOutResult)
    {
        const auto Motion = InQuery.Plan.Entry.Definition.Motion;
        auto SourceQuery = FMars_Crawler_EmitterSourceQuery();
        SourceQuery.Emitter = InEmitter;
        SourceQuery.Slots = InQuery.Plan.Entry.Slots;
        SourceQuery.Pose = InQuery.Previous;
        const auto Before = Find_AttackEmitterSource(SourceQuery);
        SourceQuery.Pose = InQuery.Current;
        const auto After = Find_AttackEmitterSource(SourceQuery);
        if (Before.Found == false || After.Found == false || Before.LimbId != After.LimbId)
        {
            auto Failure = utils_attack::Make_Blocker(EMars_Attack_BlockerCode::AcceptedSourceMissing, f"Hit.Emitters[{InEmitter.Id.ToString()}].Source",
                FMars_Attack_Comparison("unique previous/current accepted source for claimed slot", f"previous={Before.Found}, current={After.Found}, limb={After.LimbId.ToString()}"));
            Failure.Slot = InEmitter.Slot;
            InOutResult.Failures.Add(Failure);
            return;
        }

        if (Get_IsEmitterFrameRigid(Before.Frame) == false || Get_IsEmitterFrameRigid(After.Frame) == false)
        {
            InOutResult.Displaced = true;
            Add_AttackEmitterFailure(InOutResult, InEmitter, EMars_Attack_BlockerCode::AcceptedSourceInvalid);
            return;
        }

        auto Segment = FMars_Crawler_EmitterSegment();
        Segment.Emitter = InEmitter;
        Segment.LimbId = After.LimbId;
        Segment.Geometry.PreviousFrame = Before.Frame;
        Segment.Geometry.CurrentFrame = After.Frame;
        Segment.Geometry.From = Get_HitCenter(Before.Frame, InEmitter.LocalCenter);
        Segment.Geometry.To = Get_HitCenter(After.Frame, InEmitter.LocalCenter);
        const auto Travel = (Segment.Geometry.To - Segment.Geometry.From).Size();
        const auto Active = InQuery.GameWindowOpen && InQuery.Interval.Get_Windows().Contains(utils_attack::Get_EmitterObstructionWindow(InEmitter, Motion));
        if (Get_IsFinite(Segment.Geometry.From) == false || Get_IsFinite(Segment.Geometry.To) == false || Math::IsFinite(Travel) == false ||
            Math::IsFinite(float32(Travel)) == false || (Active && Travel > InEmitter.MaxSampleTravel))
        {
            InOutResult.Displaced = true;
            auto Failure = utils_attack::Make_Blocker(EMars_Attack_BlockerCode::SampleTravel, f"Hit.Emitters[{InEmitter.Id.ToString()}].Travel",
                FMars_Attack_Comparison(f"finite; active <= {InEmitter.MaxSampleTravel} cm", f"{Travel} cm; active={Active}"));
            Failure.Slot = InEmitter.Slot;
            InOutResult.Failures.Add(Failure);
        }

        Segment.Geometry.Travel = float32(Travel);
        Segment.Activity.Obstruction = Active;
        Segment.Activity.Damage = Active && InQuery.Interval.Get_PhaseId() == Motion.StrikePhase &&
            InQuery.Interval.Get_Windows().Contains(InEmitter.DamageWindow);
        Segment.Sample = InQuery.Sample;
        InOutResult.Segments.Add(Segment);
    }

    // At most eight copied segments, ordered by emitter id (ignoring case) so the authored array order is never gameplay.
    void Sort_AttackEmitterSegments(TArray<FMars_Crawler_EmitterSegment>& InOutSegments)
    {
        for (int32 Index = 1; Index < InOutSegments.Num(); ++Index)
        {
            auto Position = Index;
            while (Position > 0 && InOutSegments[Position].Emitter.Id.ToString().ToLower() < InOutSegments[Position - 1].Emitter.Id.ToString().ToLower())
            {
                const auto Swap = InOutSegments[Position - 1];
                InOutSegments[Position - 1] = InOutSegments[Position];
                InOutSegments[Position] = Swap;
                --Position;
            }
        }
    }

    // Validates the complete source set and every active guard before the caller may issue its first cast.
    FMars_Crawler_EmitterExtraction Extract_AttackEmitters(const FMars_Crawler_EmitterQuery& InQuery)
    {
        auto Result = FMars_Crawler_EmitterExtraction();
        const auto Motion = InQuery.Plan.Entry.Definition.Motion;
        const auto Emitters = InQuery.Plan.Entry.Definition.Hit.Emitters;
        if (Emitters.Num() == 0 || Emitters.Num() > 8)
        {
            Result.Failures.Add(utils_attack::Make_Blocker(EMars_Attack_BlockerCode::EmitterCount, "Hit.Emitters", FMars_Attack_Comparison("1..8", f"{Emitters.Num()}")));
            return Result;
        }

        auto AnyActive = false;
        for (const auto& Emitter : Emitters)
        {
            AnyActive = AnyActive || (InQuery.GameWindowOpen &&
                InQuery.Interval.Get_Windows().Contains(utils_attack::Get_EmitterObstructionWindow(Emitter, Motion)));
        }

        Check_AttackEmitterRoot(InQuery, AnyActive, Result);

        auto Seen = TArray<FGameplayTag>();
        for (const auto& Emitter : Emitters)
        {
            if (Emitter.Id.IsValid() == false || Seen.Contains(Emitter.Id))
            { Add_AttackEmitterFailure(Result, Emitter, EMars_Attack_BlockerCode::EmitterIdentity); }

            Seen.Add(Emitter.Id);
            if (Get_IsPositiveFinite(Emitter.Radius) == false || Get_IsPositiveFinite(Emitter.MaxSampleTravel) == false || Get_IsFinite(Emitter.LocalCenter) == false)
            { Add_AttackEmitterFailure(Result, Emitter, EMars_Attack_BlockerCode::EmitterBounds); }

            Add_AttackEmitterSegment(InQuery, Emitter, Result);
        }

        Sort_AttackEmitterSegments(Result.Segments);
        return Result;
    }

    bool Get_IsEarlierEmitterContact(const FMars_Crawler_EmitterContact& InLeft, const FMars_Crawler_EmitterContact& InRight)
    {
        if (InLeft.Fraction != InRight.Fraction)
        { return InLeft.Fraction < InRight.Fraction; }

        return InLeft.EmitterId.ToString().ToLower() < InRight.EmitterId.ToString().ToLower();
    }
}

// Only the actual latest settled record is compared with live visual transforms. Foot visual scale is independent of
// the rigid accepted endpoint frame; position and rotation carry the endpoint sphere's provenance.
mixin TArray<FMars_Attack_Blocker> Evaluate_AttackEmitterPresentation(const FCk_Handle_Crawler& Self,
    const TArray<FMars_Crawler_EmitterSegment>& InSegments)
{
    auto Failures = TArray<FMars_Attack_Blocker>();
    for (const auto& Segment : InSegments)
    {
        auto Presented = FCk_Handle_Transform();
        auto Matches = 0;
        if (Segment.Emitter.Source == EMars_Attack_EmitterSource::Body)
        {
            Presented = Self.Get_Presentation();
            Matches = 1;
        }
        else
        {
            for (const auto& Leg : Self.Get_Spec().Rig.Legs)
            {
                if (Leg.LegId == Segment.LimbId)
                {
                    Presented = Leg.Foot;
                    ++Matches;
                }
            }
        }

        FCk_Handle PresentedEntity = Presented;
        auto Failure = utils_attack::Make_Blocker(EMars_Attack_BlockerCode::AcceptedPresentationMismatch, f"Hit.Emitters[{Segment.Emitter.Id.ToString()}].Presentation",
            FMars_Attack_Comparison("live matching accepted source within 0.05 cm/deg", "missing or displaced"));
        Failure.Slot = Segment.Emitter.Slot;
        if (Matches != 1 || ck::Is_NOT_Valid(Presented) ||
            utils_entity_lifetime::Get_IsPendingDestroy(PresentedEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            Failures.Add(Failure);
            continue;
        }

        const auto Frame = utils_transform::Get_EntityCurrentTransform(Presented);
        const auto Accepted = Segment.Geometry.CurrentFrame;
        if (utils_crawler::Get_IsEmitterFrameFinite(Frame) == false)
        {
            Failures.Add(Failure);
            continue;
        }

        const auto Distance = (Frame.GetLocation() - Accepted.GetLocation()).Size();
        const auto Angle = Math::RadiansToDegrees(Frame.GetRotation().AngularDistance(Accepted.GetRotation()));
        if (Math::IsFinite(Distance) == false || Math::IsFinite(Angle) == false || Distance > 0.05 || Angle > 0.05)
        {
            Failure.Actual = f"{Distance :.4} cm, {Angle :.4} deg";
            Failures.Add(Failure);
        }
    }

    return Failures;
}

mixin TArray<FMars_Crawler_EmitterSegment> Get_AttackAcceptedEmitters(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) == false)
    { return TArray<FMars_Crawler_EmitterSegment>(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Hit.Emitters;
}

mixin TArray<FMars_Attack_Blocker> Get_AttackEmitterFailures(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) == false)
    { return TArray<FMars_Attack_Blocker>(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Hit.EmitterFailures;
}

// The emitter and contact fraction of the committed hit; unset fields when none.
mixin FMars_Crawler_EmitterContact Get_AttackCommittedEmitter(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return FMars_Crawler_EmitterContact(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Ledger.Emitter;
}

mixin FGameplayTag Get_AttackCommittedEmitterId(const FCk_Handle_Crawler& Self)
{
    return Self.Get_AttackCommittedEmitter().EmitterId;
}

mixin float32 Get_AttackCommittedEmitterFraction(const FCk_Handle_Crawler& Self)
{
    return Self.Get_AttackCommittedEmitter().Fraction;
}
