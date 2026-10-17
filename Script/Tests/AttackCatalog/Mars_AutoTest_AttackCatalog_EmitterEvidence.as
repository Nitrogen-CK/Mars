// Proposal only. The first gate must compile these native constructors before any runtime evidence claim.
class UMars_AutoTest_AttackCatalog_EmitterEvidence : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("E05 native observation constructors and receipt evidence policy", n"Step_Receipts");
        Add_Step("E05/E06 copied accepted source and travel/root/window guards", n"Step_Extraction");
        Add_Step("historical page and deterministic contact policy", n"Step_PagesAndOrder");
        Run_Steps(InHandle);
    }

    private FCk_ProceduralArticulation_Pose Pose_At(float64 InAcceptedX, bool InIncludeLimb)
    {
        auto Limbs = TArray<FCk_ProceduralArticulation_LimbPose>();
        if (InIncludeLimb)
        {
            auto Segments = TArray<FTransform>();
            Segments.Add(FTransform::Identity);
            // Requested/evaluated geometry is deliberately far from the accepted endpoint.
            Limbs.Add(FCk_ProceduralArticulation_LimbPose(n"Leg0", FTransform(FRotator::ZeroRotator, FVector(500.0, 0.0, 0.0)),
                FTransform(FRotator::ZeroRotator, FVector(InAcceptedX, 0.0, 0.0)), Segments, 0.0f,
                ECk_ProceduralRig_ChainState::Clear, ECk_ProceduralArticulation_ContactEvidence::Trusted));
        }
        return FCk_ProceduralArticulation_Pose(FTransform::Identity, FTransform::Identity, true, Limbs);
    }

    private FCk_ProceduralAction_Receipt Receipt_Of(int64 InSample, ECk_ProceduralAction_Continuity InContinuity, bool InAccepted)
    {
        auto Windows = TArray<FName>();
        Windows.Add(n"ClawSweep");
        Windows.Add(n"Damage");
        auto Events = TArray<FCk_ProceduralAction_Event>();
        const auto Interval = FCk_ProceduralAction_Interval(FCk_Time(0.5), FCk_Time(0.51), n"Strike", InContinuity, Windows, Events);
        const auto Stamp = FCk_ProceduralAction_Stamp(FCk_ProceduralAction_Identity(1), 1, InSample, InSample, 1, 1);
        const auto Sampling = FCk_ProceduralAction_SamplingReport(8, InAccepted ? 1 : 0, 8.0f, 1.0f, FCk_Time(0.0));
        return FCk_ProceduralAction_Receipt(InAccepted, Stamp, Interval, Pose_At(0.0, true), Pose_At(8.0, true), Sampling);
    }

    private FMars_Crawler_ReceiptEvidenceQuery Evidence_Of(const FCk_ProceduralAction_Receipt& InReceipt)
    {
        auto Query = FMars_Crawler_ReceiptEvidenceQuery();
        Query.ExpectedActionIdentity = FCk_ProceduralAction_Identity(1);
        Query.Receipt = InReceipt;
        Query.ContentRevision = 1;
        Query.TopologyRevision = 1;
        return Query;
    }

    UFUNCTION()
    private void Step_Receipts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = Evidence_Of(Receipt_Of(1, ECk_ProceduralAction_Continuity::FirstSample, true));
        auto Result = utils_crawler::Evaluate_AttackReceiptEvidence(Query);
        Assert_True(Result.Skip == false && Result.Failure.IsNone(), "fresh first accepted observation passes the production receipt seam");
        Query = Evidence_Of(Receipt_Of(2, ECk_ProceduralAction_Continuity::Continuous, false));
        Assert_True(utils_crawler::Evaluate_AttackReceiptEvidence(Query).Skip,
            "an evaluated-only report without accepted pose is skipped before extraction");
        Query = Evidence_Of(Receipt_Of(2, ECk_ProceduralAction_Continuity::Continuous, true));
        Query.AckSampleId = 2;
        Assert_True(utils_crawler::Evaluate_AttackReceiptEvidence(Query).Skip, "duplicate or older sample is skipped");
        Query.AckSampleId = 1;
        Query.AckRevision = 2;
        Assert_True(utils_crawler::Evaluate_AttackReceiptEvidence(Query).Skip, "stale subject revision is skipped");
        Query.AckRevision = 1;
        Query.ExpectedActionIdentity = FCk_ProceduralAction_Identity(2);
        Assert_True(utils_crawler::Evaluate_AttackReceiptEvidence(Query).Failure == n"ContentChanged", "fresh wrong identity is rejected");
        Query.ExpectedActionIdentity = FCk_ProceduralAction_Identity(1);
        Query.ContentRevision = 2;
        Assert_True(utils_crawler::Evaluate_AttackReceiptEvidence(Query).Failure == n"ContentChanged", "fresh wrong content revision is rejected");
        Query.ContentRevision = 1;
        Query.TopologyRevision = 2;
        Assert_True(utils_crawler::Evaluate_AttackReceiptEvidence(Query).Failure == n"ContentChanged", "fresh changed topology is rejected");
        Query = Evidence_Of(Receipt_Of(2, ECk_ProceduralAction_Continuity::Incomplete, true));
        Assert_True(utils_crawler::Evaluate_AttackReceiptEvidence(Query).Failure == n"ReceiptGap", "incomplete continuity closes receipt evidence");
        Query = Evidence_Of(Receipt_Of(2, ECk_ProceduralAction_Continuity::FirstSample, true));
        Query.AckSampleId = 1;
        Assert_True(utils_crawler::Evaluate_AttackReceiptEvidence(Query).Failure == n"ReceiptGap", "first-sample continuity cannot restart an acknowledged stream");
    }

    private FMars_Crawler_EmitterQuery Make_Query()
    {
        auto Query = FMars_Crawler_EmitterQuery();
        Query.Previous = Pose_At(0.0, true);
        Query.Current = Pose_At(8.0, true);
        Query.Interval = Receipt_Of(2, ECk_ProceduralAction_Continuity::Continuous, true).Get_Interval();
        Query.Sample.Stamp = Receipt_Of(2, ECk_ProceduralAction_Continuity::Continuous, true).Get_Stamp();
        Query.Sample.Generation = 1;
        auto Slot = FMars_Attack_ResolvedSlot();
        Slot.Slot = n"ClawRight";
        Slot.Binding.Role = GameplayTags::AttackRole_Mars_FrontRight;
        Slot.Binding.Source = EMars_Attack_AnatomySource::ProceduralLimb;
        Slot.Binding.LimbId = n"Leg0";
        Query.Plan.Entry.Slots.Add(Slot);
        auto Emitter = FMars_Attack_Emitter();
        Emitter.Id = GameplayTags::AttackEmitter_Mars_ClawRight;
        Emitter.Source = EMars_Attack_EmitterSource::LimbEndpoint;
        Emitter.Slot = Slot.Slot;
        Emitter.Radius = 12.0f;
        Emitter.MaxSampleTravel = 16.0f;
        Emitter.DamageWindow = n"Damage";
        Emitter.ObstructionWindow = n"ClawSweep";
        Query.Plan.Entry.Definition.Hit.Emitters.Add(Emitter);
        return Query;
    }

    private bool Has_Failure(const FMars_Crawler_EmitterExtraction& InExtraction, FName InCode) const
    {
        for (const auto& Failure : InExtraction.Failures)
        { if (Failure.Code == InCode) { return true; } }
        return false;
    }

    UFUNCTION()
    private void Step_Extraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = Make_Query();
        auto Extracted = utils_crawler::Extract_AttackEmitters(Query);
        Assert_True(Extracted.Failures.Num() == 0 && Extracted.Segments.Num() == 1, "unique accepted claimed source is extracted");
        if (Extracted.Segments.Num() == 1)
        {
            Assert_True(Extracted.Segments[0].Geometry.To.Equals(FVector(8.0, 0.0, 0.0), 1.0e-6),
                "accepted endpoint is used, never the requested/evaluated endpoint at 500 cm");
            Assert_True(Extracted.Segments[0].Activity.Damage && Extracted.Segments[0].Activity.Obstruction,
                "strike plus independently authored active windows permit this copied segment");
        }
        Query.Current = Pose_At(8.0, false);
        Assert_True(Has_Failure(utils_crawler::Extract_AttackEmitters(Query), n"AcceptedSourceMissing"),
            "missing accepted limb cannot substitute the body's presentation");
        Query = Make_Query();
        Query.Current = Pose_At(17.0, true);
        Assert_True(Has_Failure(utils_crawler::Extract_AttackEmitters(Query), n"SampleTravel"), "active centre travel beyond authored 16 cm is rejected before casts");
        Query = Make_Query();
        Query.Plan.Entry.Definition.Hit.Emitters[0].LocalCenter.X = Math::Sqrt(-1.0);
        Assert_True(Has_Failure(utils_crawler::Extract_AttackEmitters(Query), n"EmitterBounds"), "nonfinite centre is rejected before casts without constructing a diagnostic-sanitized NaN transform");
        Query = Make_Query();
        Query.Root.Direction.X = Math::Sqrt(-1.0);
        Assert_True(Has_Failure(utils_crawler::Extract_AttackEmitters(Query), n"RootInvalid"), "nonfinite copied facing input is rejected before casts");
        Query = Make_Query();
        Query.Root.Current = FTransform(FRotator::ZeroRotator, FVector(20.0, 0.0, 0.0));
        Assert_True(Has_Failure(utils_crawler::Extract_AttackEmitters(Query), n"RootDrift"), "root displacement exceeds the copied execution budget");
        Query = Make_Query();
        Query.Root.Current = FTransform(FRotator(0.0, 90.0, 0.0), FVector::ZeroVector);
        Assert_True(Has_Failure(utils_crawler::Extract_AttackEmitters(Query), n"FacingDrift"), "facing drift rejects before casts");
        Query = Make_Query();
        Query.GameWindowOpen = false;
        Extracted = utils_crawler::Extract_AttackEmitters(Query);
        Assert_True(Extracted.Segments.Num() == 1 && Extracted.Segments[0].Activity.Damage == false &&
            Extracted.Segments[0].Activity.Obstruction == false, "closed game window disables both activities");
        auto Windows = TArray<FName>();
        Windows.Add(n"ClawSweep");
        Query = Make_Query();
        Query.Interval = FCk_ProceduralAction_Interval(FCk_Time(0.46), FCk_Time(0.47), n"Strike",
            ECk_ProceduralAction_Continuity::Continuous, Windows, TArray<FCk_ProceduralAction_Event>());
        Extracted = utils_crawler::Extract_AttackEmitters(Query);
        Assert_True(Extracted.Segments.Num() == 1 && Extracted.Segments[0].Activity.Obstruction && Extracted.Segments[0].Activity.Damage == false,
            "not-yet-open Damage keeps obstruction active but cannot make a candidate");
        Windows.Add(n"Damage");
        auto Events = TArray<FCk_ProceduralAction_Event>();
        Events.Add(FCk_ProceduralAction_Event(FCk_Time(0.5), ECk_ProceduralAction_EventKind::WindowExit, n"Damage", 1));
        Query.Interval = FCk_ProceduralAction_Interval(FCk_Time(0.49), FCk_Time(0.5), n"Strike",
            ECk_ProceduralAction_Continuity::Continuous, Windows, Events);
        Assert_True(utils_crawler::Extract_AttackEmitters(Query).Segments[0].Activity.Damage,
            "a closure event at interval end does not erase the accepted preceding damage interval");
    }

    UFUNCTION()
    private void Step_PagesAndOrder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Records = TArray<FCk_ProceduralAction_Record>();
        Records.Add(FCk_ProceduralAction_Record(FCk_ProceduralAction_Identity(1), 1, ECk_ProceduralAction_RecordKind::AcceptedPose,
            Receipt_Of(1, ECk_ProceduralAction_Continuity::FirstSample, true), TArray<FName>(), FCk_ProceduralAction_Result()));
        const auto Historical = FCk_ProceduralAction_ReadPage(ECk_ProceduralAction_ReadResult::Succeeded, Records, 1, false, true);
        const auto Latest = FCk_ProceduralAction_ReadPage(ECk_ProceduralAction_ReadResult::Succeeded, Records, 1, false, false);
        Assert_Equals_Int(utils_crawler::Get_LatestAcceptedIndex(Historical), -1, "HasMore page is never compared to current presentation");
        Assert_Equals_Int(utils_crawler::Get_LatestAcceptedIndex(Latest), 0, "only a fully caught-up page exposes the latest accepted index");
        auto Left = FMars_Crawler_EmitterContact();
        Left.EmitterId = GameplayTags::AttackEmitter_Mars_Body;
        Left.Fraction = 0.25f;
        auto Right = Left;
        Right.EmitterId = GameplayTags::AttackEmitter_Mars_ClawRight;
        Assert_True(utils_crawler::Get_IsEarlierEmitterContact(Left, Right), "equal fractions use canonical emitter tag order");
        Right.Fraction = 0.1f;
        Assert_True(utils_crawler::Get_IsEarlierEmitterContact(Right, Left), "earliest contact fraction precedes canonical ID");
        Log("[EmitterEvidence] pure constructors/guard policy only; no physical hits or injected game backlog were asserted");
    }
}
