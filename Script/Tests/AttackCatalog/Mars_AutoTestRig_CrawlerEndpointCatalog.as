struct FMars_TESTONLY_EndpointTrace
{
    FMars_Crawler_EmitterSegment Segment;
    FCk_ProceduralAction_Interval Interval;
    FCk_ProceduralAction_SamplingReport Sampling;
    FTransform Rendered = FTransform::Identity;
    bool RenderedFound = false;
    FVector BodyCenter;
    int64 Frame = 0;
    float64 DeltaSeconds = 0.0;
    FCk_Handle QueryZone;
    bool QueryWorld = false;
    float32 QueryFraction = 0.0f;
}

struct FMars_TESTONLY_EndpointCapture
{
    FCk_Handle_Crawler Crawler;
    TArray<FMars_TESTONLY_EndpointTrace> Trace;
    TArray<FMars_Crawler_HitCandidate> Candidates;
    int64 LastSample = 0;
    int64 CommitSample = 0;
    FMars_Crawler_EmitterContact CommitContact;
    int32 PresentationFailures = 0;
    int32 ClosedWindowCandidates = 0;
    FCk_Handle TargetZone;
    int32 DualContactSamples = 0;
    int32 SimultaneousBlockedSamples = 0;
    int32 EarlyStrikeSamples = 0;
    int32 LateStrikeSamples = 0;
    int32 DamageExitSamples = 0;
}

struct FMars_TESTONLY_EndpointFinalCancel
{
    FCk_Handle_Crawler Crawler;
    bool Fired = false;
    int64 Frame = 0;
    int32 IssuedAtBoundary = 0;
    FMars_Crawler_HitCandidate Candidate;
}

// Public cancel is transported before the owning tick; the fixture never fabricates or edits a game candidate.
class UMars_TESTONLY_Processor_EndpointFinalCancel : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Crawler_HandleRequests");
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Crawler_AttackTick");
    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query) {}
    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_EndpointFinalCancel& InCommand)
    {
        if (InCommand.Fired || ck::Is_NOT_Valid(InCommand.Crawler)) { return; }
        const auto& Observed = InCommand.Crawler.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        if (Observed.Candidate.IsSet() == false || Observed.Candidate.GetValue().SampleId != Observed.AckSampleId) { return; }
        auto Exit = false;
        for (const auto& Event : Observed.AcceptedInterval.Get_Events())
        { Exit = Exit || Event.Get_Id() == n"Damage" && Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowExit; }
        if (Exit == false) { return; }
        InCommand.Fired = true;
        InCommand.Frame = utils_time::Get_FrameCounter();
        InCommand.Candidate = Observed.Candidate.GetValue();
        InCommand.IssuedAtBoundary = utils_mars_test_catalog::Get_IssuedDamageRequests(InCommand.Crawler);
        InCommand.Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));
    }
}

// Test evidence only: production resolves first, then this records the same accepted sample and current foot.
class UMars_TESTONLY_Processor_CrawlerEndpointCapture : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Overlap";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Crawler_AttackResolve");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {}

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_EndpointCapture& InCapture)
    {
        if (ck::Is_NOT_Valid(InCapture.Crawler)) { return; }
        const auto Crawler = InCapture.Crawler;
        const auto& Observed = Crawler.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        const auto& Attack = Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Observed.Candidate.IsSet())
        {
            const auto Candidate = Observed.Candidate.GetValue();
            if (InCapture.Candidates.IsEmpty() || InCapture.Candidates.Last().SampleId != Candidate.SampleId)
            { InCapture.Candidates.Add(Candidate); }
            if (Observed.AcceptedInterval.Get_Windows().Contains(n"Damage") == false)
            { ++InCapture.ClosedWindowCandidates; }
        }
        if (Attack.CommittedSampleId > 0)
        { InCapture.CommitSample = Attack.CommittedSampleId; InCapture.CommitContact = Attack.CommittedEmitter; }
        if (Observed.AckSampleId == 0 || Observed.AckSampleId <= InCapture.LastSample || ck::Is_NOT_Valid(Attack.Action))
        { return; }
        InCapture.LastSample = Observed.AckSampleId;
        const auto Receipt = Attack.Action.Get_LastReceipt();
        auto TargetContacts = 0;
        auto Blockers = 0;
        for (const auto& Segment : Observed.AcceptedEmitters)
        {
            if (Segment.Sample.Stamp.Get_SampleSequence() != Receipt.Get_Stamp().Get_SampleSequence())
            { continue; }
            auto Row = FMars_TESTONLY_EndpointTrace();
            Row.Segment = Segment;
            Row.Interval = Observed.AcceptedInterval;
            Row.Sampling = Receipt.Get_Sampling();
            Row.Frame = utils_time::Get_FrameCounter();
            Row.DeltaSeconds = InDeltaT.Get_Seconds();
            Row.BodyCenter = utils_crawler::Get_HitCenter(Receipt.Get_CurrentPose().Get_BodyPresentation(), Crawler.Get_Spec().Combat.Hit.LocalCenter);
            if (Segment.Activity.Obstruction)
            {
                auto Settings = utils_crawler::Make_AttackQuery(Segment.Geometry.From, Segment.Geometry.To, Segment.Emitter.Radius);
                Settings.Set_IgnoredEntities(Crawler.Get_AttackIgnoredEntities());
                FCk_Handle Tracer = Crawler;
                const auto Hit = utils_probe_trace::Request_SingleShapeTrace(Tracer, Settings);
                Row.QueryWorld = Hit.Get_HitKind() == ECk_ProbeTrace_HitKind::World;
                Row.QueryZone = utils_hit_zone::TryGet_Zone(Hit.Get_HitEntity());
                Row.QueryFraction = Hit.Get_Fraction();
                if (Segment.Activity.Damage && Row.QueryZone == InCapture.TargetZone) { ++TargetContacts; }
                if (Row.QueryWorld || (ck::IsValid(Row.QueryZone) && Row.QueryZone != InCapture.TargetZone)) { ++Blockers; }
            }
            for (const auto& Leg : Crawler.Get_Spec().Rig.Legs)
            {
                if (Leg.LegId != Segment.LimbId || ck::Is_NOT_Valid(Leg.Foot)) { continue; }
                Row.Rendered = utils_transform::Get_EntityCurrentTransform(Leg.Foot);
                Row.RenderedFound = true;
            }
            const auto PositionError = (Row.Rendered.GetLocation() - Segment.Geometry.CurrentFrame.GetLocation()).Size();
            const auto AngularError = Math::RadiansToDegrees(Row.Rendered.GetRotation().AngularDistance(Segment.Geometry.CurrentFrame.GetRotation()));
            if (Row.RenderedFound == false || PositionError > 0.05 || AngularError > 0.05)
            { ++InCapture.PresentationFailures; }
            InCapture.Trace.Add(Row);
        }
        if (TargetContacts >= 2) { ++InCapture.DualContactSamples; }
        if (TargetContacts > 0 && Blockers > 0) { ++InCapture.SimultaneousBlockedSamples; }
        if (Observed.AcceptedInterval.Get_PhaseId() == n"Strike" && Observed.AcceptedInterval.Get_Windows().Contains(n"Damage") == false)
        {
            auto PhaseStart = 0.0;
            for (const auto& Phase : Attack.Plan.Entry.Definition.Clip.Get().Get_Phases())
            {
                if (Phase.Get_Id() == n"Strike")
                {
                    const auto Duration = Phase.Get_Duration().Get_Seconds();
                    if (Observed.AcceptedInterval.Get_ToTime().Get_Seconds() <= PhaseStart + Duration * 0.25 + 1.0e-6) { ++InCapture.EarlyStrikeSamples; }
                    if (Observed.AcceptedInterval.Get_FromTime().Get_Seconds() >= PhaseStart + Duration * 0.75 - 1.0e-6) { ++InCapture.LateStrikeSamples; }
                }
                PhaseStart += Phase.Get_Duration().Get_Seconds();
            }
        }
        for (const auto& Event : Observed.AcceptedInterval.Get_Events())
        { if (Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowExit && Event.Get_Id() == n"Damage") { ++InCapture.DamageExitSamples; } }
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_CrawlerEndpointCatalog : UMars_AutoTestRig_CrawlerAttackCatalog
{
    UPROPERTY() protected UCk_ProceduralAction_Data _EndpointPincer;
    UPROPERTY() protected UCk_ProceduralAction_Data _SwipeRight;
    UPROPERTY() protected UCk_ProceduralAction_Data _SwipeLeft;
    UPROPERTY() protected UMars_AttackDefinition_Data _RightDefinition;
    UPROPERTY() protected UMars_AttackDefinition_Data _LeftDefinition;
    protected FGameplayTag _ExpectedEndpointId = GameplayTags::Attack_Mars_SwipeRight;
    protected FCk_Handle _Capture;
    protected FMars_TESTONLY_AttackCatalog_Stream _Calibration;
    protected TArray<FCk_ProceduralAction_Receipt> _CalibrationReceipts;
    protected FVector _CalibratedRight;
    protected FVector _CalibratedLeft;
    protected FVector _EndpointHalf = FVector(6.0, 6.0, 6.0);
    protected FTransform _CalibratedRoot;
    protected bool _AnchorLastDamage = false;
    protected FVector _AnchorTravelDirection;
    private int32 _ReturnPolls = 0;

    protected FMars_Crawler_Spec Make_EndpointSpec()
    {
        auto Spec = Make_CatalogSpec(false);
        _EndpointPincer = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        _SwipeRight = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        _SwipeLeft = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
#if EDITOR
        Assert_True(utils_crawler::Build_ReferenceEndpointPincerClip(_CatalogLayout, _CatalogLegCount, _CatalogPincerSource, _EndpointPincer).Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            "opt-in endpoint pincer builder compiles without modifying its legacy source");
        Assert_True(utils_crawler::Build_ReferenceSwipeClip(_CatalogLayout, _CatalogLegCount, true, _SwipeRight).Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            "independent right swipe public builder compiles");
        Assert_True(utils_crawler::Build_ReferenceSwipeClip(_CatalogLayout, _CatalogLegCount, false, _SwipeLeft).Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            "independent left swipe public builder compiles");
#endif
        _CatalogPincer.Def.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(_EndpointPincer);
        _CatalogPincer.Def.Hit.Emitters.Empty();
        _CatalogPincer.Def.Hit.Emitters.Add(Make_EndpointEmitter(GameplayTags::AttackEmitter_Mars_ClawRight, n"ClawRight"));
        _CatalogPincer.Def.Hit.Emitters.Add(Make_EndpointEmitter(GameplayTags::AttackEmitter_Mars_ClawLeft, n"ClawLeft"));
        _CatalogPincer.Def.Prepare.MaxDistance = 400.0f;
        _CatalogPincer.Def.Prepare.FacingToleranceDegrees = 90.0f;
        _CatalogPincer.Def.Prepare.MaxHeightDifference = 300.0f;
        _RightDefinition = Make_EndpointDefinition(Spec, _SwipeRight, true);
        _LeftDefinition = Make_EndpointDefinition(Spec, _SwipeLeft, false);
        _Catalog.Spec.Entries.Add(Make_CatalogEntry(GameplayTags::Attack_Mars_SwipeRight, _RightDefinition, 50));
        _Catalog.Spec.Entries.Add(Make_CatalogEntry(GameplayTags::Attack_Mars_SwipeLeft, _LeftDefinition, 50));
        _Catalog.Spec.Selection.TemporaryReadiness = EMars_Attack_TemporaryReadinessPolicy::UseReadyAlternative;
        _Catalog.Spec.Selection.ReadyAlternativeDelaySeconds = 0.25f;
        auto Tuning = _Catalog.Spec.Execution.Tuning;
        auto Sampling = Tuning.Get_Sampling();
        Sampling.Set_MaxAdvance(FCk_Time(1.0 / 60.0));
        Sampling.Set_MaxEndpointTravelCm(16.0f);
        // Native joint swivels retain legacy allowance; sphere collision uses the stricter physical travel budget.
        Sampling.Set_MaxSegmentAngularStepDegrees(180.0f);
        Sampling.Set_MaxSamples(1);
        Tuning.Set_Sampling(Sampling);
        _Catalog.Spec.Execution.Tuning = Tuning;
        auto Longest = Math::Max(utils_crawler::Get_ClipSeconds(_EndpointPincer),
            Math::Max(utils_crawler::Get_ClipSeconds(_SwipeRight), utils_crawler::Get_ClipSeconds(_SwipeLeft)));
        auto Locomotion = _Catalog.Spec.Execution.Locomotion;
        auto Support = Locomotion.Get_Support();
        Assert_True(Longest + Tuning.Get_Transition().Get_DedicatedReturn().Get_Seconds() <= 6.0,
            "the bounded demo support hold covers every enabled clip and its dedicated return before runtime");
        Support.Set_SupportHoldTimeout(FCk_Time(6.0));
        Locomotion.Set_Support(Support);
        _Catalog.Spec.Execution.Locomotion = Locomotion;
        _CatalogSpec = Spec;
        return Spec;
    }

    protected FMars_Attack_Emitter Make_EndpointEmitter(FGameplayTag InId, FName InSlot)
    {
        auto Emitter = FMars_Attack_Emitter();
        Emitter.Id = InId;
        Emitter.Source = EMars_Attack_EmitterSource::LimbEndpoint;
        Emitter.Slot = InSlot;
        Emitter.Radius = 12.0f;
        Emitter.MaxSampleTravel = 16.0f;
        Emitter.DamageWindow = n"Damage";
        Emitter.ObstructionWindow = n"ClawSweep";
        return Emitter;
    }

    private UMars_AttackDefinition_Data Make_EndpointDefinition(const FMars_Crawler_Spec& InSpec, UCk_ProceduralAction_Data InClip, bool InRight)
    {
        auto Definition = Make_CatalogDefinition(InSpec, InClip);
        Definition.Def.Hit.Emitters.Empty();
        Definition.Def.Hit.Emitters.Add(Make_EndpointEmitter(InRight ? GameplayTags::AttackEmitter_Mars_ClawRight : GameplayTags::AttackEmitter_Mars_ClawLeft, InRight ? n"ClawRight" : n"ClawLeft"));
        auto Slot = FMars_Attack_SlotRole();
        Slot.Role = InRight ? GameplayTags::AttackRole_Mars_FrontRight : GameplayTags::AttackRole_Mars_FrontLeft;
        Slot.Slot = InRight ? n"ClawRight" : n"ClawLeft";
        Definition.Def.Requirements.Slots.Add(Slot);
        Definition.Def.Prepare = _CatalogPincer.Def.Prepare;
        return Definition;
    }

    protected UCk_ProceduralAction_Data Get_EndpointSource(FGameplayTag InId) const
    { return InId == GameplayTags::Attack_Mars_Pincer ? _EndpointPincer : InId == GameplayTags::Attack_Mars_SwipeRight ? _SwipeRight : _SwipeLeft; }

    UFUNCTION()
    protected void Step_StartCalibration(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CalibratedRoot = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        if (_ExpectedEndpointId == GameplayTags::Attack_Mars_Pincer || _ExpectedEndpointId == GameplayTags::Attack_Mars_SwipeRight)
        { Bindings.Add(FCk_ProceduralAction_SlotBinding(n"ClawRight", n"Leg0")); }
        if (_ExpectedEndpointId == GameplayTags::Attack_Mars_Pincer || _ExpectedEndpointId == GameplayTags::Attack_Mars_SwipeLeft)
        { Bindings.Add(FCk_ProceduralAction_SlotBinding(n"ClawLeft", FName(f"Leg{_CatalogLegCount - 1}"))); }
        auto Play = FCk_ProceduralAction_PlaySpec(TSoftObjectPtr<UCk_ProceduralAction_Data>(Get_EndpointSource(_ExpectedEndpointId)));
        Play.Set_SlotBindings(Bindings);
        Play.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);
        auto Owner = InHandle;
        _Calibration.Action = utils_procedural_action::Create_FromClip(Owner, _Crawler.Get_ActionPlayer(), Play);
        Assert_True(ck::IsValid(_Calibration.Action), "calibration creates a real native action using the actual common demo policy");
        _Calibration.Identity = _Calibration.Action.Get_Identity();
    }

    UFUNCTION()
    protected void Check_CalibrationTerminal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Player = _Crawler.Get_ActionPlayer();
        for (int32 PageIndex = 0; PageIndex < 4 && _Calibration.TerminalSeen == false; ++PageIndex)
        {
            const auto Page = Player.Read_Receipts(_Calibration.Identity, _Calibration.Cursor, 16);
            if (Page.Get_Result() != ECk_ProceduralAction_ReadResult::Succeeded && Page.Get_Result() != ECk_ProceduralAction_ReadResult::Pending)
            { FinishFailure(f"calibration receipt stream failed {Page.Get_Result() :n}"); return; }
            for (const auto& Record : Page.Get_Records())
            {
                if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose)
                { _CalibrationReceipts.Add(Record.Get_Receipt()); }
                if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
                { _Calibration.Result = Record.Get_Result(); _Calibration.TerminalSeen = true; }
            }
            _Calibration.Cursor = Page.Get_LastStreamSequence();
            if (Page.Get_Records().Num() > 0)
            { Player.Request_ConsumeReceipts(FCk_Request_ProceduralActionPlayer_ConsumeReceipts(_Calibration.Identity, _Calibration.Cursor)); }
            if (Page.Get_HasMore() == false) { break; }
        }
        auto Res = OutResult;
        Res.Set(_Calibration.TerminalSeen);
    }

    UFUNCTION()
    protected void Check_CalibrationReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_ReturnPolls;
        if (_ReturnPolls == 1 || _ReturnPolls == 300)
        {
            const auto Result = _Crawler.Get_AttackResult();
            const auto Cancel = _Crawler.Get_AttackLastCancel();
            const FString CancelText = Cancel.IsSet() ? f"{Cancel.GetValue() :n}" : "-";
            Log(f"[EndpointReturn] {_CatalogLayout :n}/{_CatalogLegCount} {_ExpectedEndpointId}: accepted {Result.Accepted}, completed {Result.Completed}, native {Result.Native.Get_Outcome() :n}/{Result.Native.Get_Recovery() :n}/{Result.Native.Get_Reason()}, evidence {Result.Evidence.Failure}, cleanup {Result.CleanupOutcome}, cancel {CancelText}, articulation {_Crawler.Get_Articulation().Get_Health() :n}");
            for (const auto& Failure : _Crawler.Get_AttackEmitterFailures())
            { Log(f"[EndpointReturnFailure] {Failure.Code} {Failure.Field} expected {Failure.Expected} actual {Failure.Actual}"); }
            for (const auto& Part : _Crawler.Get_LegParts())
            {
                const auto Control = _Crawler.Get_Articulation().Get_LimbControl(Part.Get_Leg().Get_Id());
                Log(f"[EndpointReturnLimb] {Part.Get_Leg().Get_Id()}: {Control.Get_State() :n} participating {Control.Get_Participating()}, planted {Part.Get_Leg().Get_Foot().Get_Phase() :n}");
            }
        }
        auto Ready = ck::Is_NOT_Valid(_Calibration.Action) && _Crawler.Get_Articulation().Get_Health() == ECk_ProceduralArticulation_Health::Operational;
        for (const auto& Part : _Crawler.Get_LegParts())
        {
            if (Part.Get_State() != EMars_BodyPart_State::Attached || Part.Get_Leg().Get_IsAttached() == false ||
                Part.Get_Leg().Get_Status() == ECk_ProceduralLeg_Status::Disabled) { continue; }
            const auto Control = _Crawler.Get_Articulation().Get_LimbControl(Part.Get_Leg().Get_Id());
            Ready = Ready && Control.Get_State() == ECk_ProceduralLimbControl_State::Default && Control.Get_Participating() &&
                Part.Get_Leg().Get_Foot().Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted;
        }
        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    protected void Step_SelectMeasuredAnchor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Calibration.Result.Get_Outcome() == ECk_ProceduralAction_Outcome::Completed &&
            _Calibration.Result.Get_Recovery() == ECk_ProceduralAction_Recovery::Succeeded, "calibration completed with exact successful native return");
        auto Best = 1.0e20;
        auto Found = false;
        auto Start = 0.0;
        auto Middle = 0.0;
        for (const auto& Phase : Get_EndpointSource(_ExpectedEndpointId).Get_Phases())
        {
            if (Phase.Get_Id() == n"Strike") { Middle = Start + Phase.Get_Duration().Get_Seconds() * 0.5; }
            Start += Phase.Get_Duration().Get_Seconds();
        }
        for (const auto& Receipt : _CalibrationReceipts)
        {
            if (Receipt.Get_Interval().Get_PhaseId() != n"Strike" || Receipt.Get_Interval().Get_Windows().Contains(n"Damage") == false) { continue; }
            const auto Error = _AnchorLastDamage ? -Receipt.Get_Interval().Get_ToTime().Get_Seconds() :
                Math::Abs(Receipt.Get_Interval().Get_ToTime().Get_Seconds() - Middle);
            if (Error >= Best) { continue; }
            auto Right = false;
            auto Left = false;
            for (const auto& Limb : Receipt.Get_CurrentPose().Get_Limbs())
            {
                if (Limb.Get_Id() == n"Leg0") { _CalibratedRight = Limb.Get_AcceptedEndpoint().GetLocation(); Right = true; }
                if (Limb.Get_Id() == FName(f"Leg{_CatalogLegCount - 1}")) { _CalibratedLeft = Limb.Get_AcceptedEndpoint().GetLocation(); Left = true; }
            }
            Found = _ExpectedEndpointId == GameplayTags::Attack_Mars_Pincer ? Right && Left : _ExpectedEndpointId == GameplayTags::Attack_Mars_SwipeRight ? Right : Left;
            if (_AnchorLastDamage)
            {
                const auto Id = _ExpectedEndpointId == GameplayTags::Attack_Mars_SwipeRight ? n"Leg0" : FName(f"Leg{_CatalogLegCount - 1}");
                for (const auto& Before : Receipt.Get_PreviousPose().Get_Limbs())
                {
                    if (Before.Get_Id() != Id) { continue; }
                    const auto End = _ExpectedEndpointId == GameplayTags::Attack_Mars_SwipeRight ? _CalibratedRight : _CalibratedLeft;
                    _AnchorTravelDirection = (End - Before.Get_AcceptedEndpoint().GetLocation()).GetSafeNormal();
                }
            }
            if (Found) { Best = Error; }
        }
        Assert_True(Found, "target anchor comes from a real accepted Damage-window endpoint, not an evaluated key");
    }

    UFUNCTION()
    protected void Step_StartCapture(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::IsValid(_Capture)) { utils_entity_lifetime::Request_DestroyEntity(_Capture); }
        _Capture = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Data = FMars_TESTONLY_EndpointCapture();
        Data.Crawler = _Crawler;
        Data.TargetZone = _Target.Zone;
        _Capture.AddOrGet_Fragment(FMars_TESTONLY_EndpointCapture) = Data;
    }

    UFUNCTION()
    protected void Check_ExpectedEndpointReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
        auto Res = OutResult;
        Res.Set(Advice.Selection.Selected.IsSet() && Advice.Selection.Selected.GetValue() == _ExpectedEndpointId);
    }

    protected void Assert_MeasuredTrace()
    {
        const auto Capture = _Capture.Get_Fragment(FMars_TESTONLY_EndpointCapture);
        Assert_True(Capture.Trace.Num() > 0, "game resolver exposed real accepted endpoint segments");
        Assert_Equals_Int(Capture.PresentationFailures, 0, "captured sample IDs match current rendered foot position and rotation");
        Assert_Equals_Int(Capture.ClosedWindowCandidates, 0, "no candidate was observed outside Damage");
        auto MaxTravel = 0.0f;
        auto MaxReported = 0.0f;
        auto MaxAngle = 0.0f;
        auto MaxAcceptedAngle = 0.0;
        auto MaxAdvance = 0.0;
        auto MaxDelta = 0.0;
        auto MinDelta = 1.0e20;
        auto LastTime = 0.0;
        for (const auto& Row : Capture.Trace)
        {
            MaxTravel = Math::Max(MaxTravel, Row.Segment.Geometry.Travel);
            MaxReported = Math::Max(MaxReported, Row.Sampling.Get_MaxEndpointTravelCm());
            MaxAngle = Math::Max(MaxAngle, Row.Sampling.Get_MaxSegmentAngularStepDegrees());
            MaxAcceptedAngle = Math::Max(MaxAcceptedAngle, Math::RadiansToDegrees(Row.Segment.Geometry.PreviousFrame.GetRotation().AngularDistance(Row.Segment.Geometry.CurrentFrame.GetRotation())));
            MaxAdvance = Math::Max(MaxAdvance, Row.Interval.Get_ToTime().Get_Seconds() - Row.Interval.Get_FromTime().Get_Seconds());
            MaxDelta = Math::Max(MaxDelta, Row.DeltaSeconds);
            MinDelta = Math::Min(MinDelta, Row.DeltaSeconds);
            LastTime = Math::Max(LastTime, Row.Interval.Get_ToTime().Get_Seconds());
            if (Row.Segment.Activity.Obstruction)
            { Assert_True(Row.Segment.Geometry.Travel <= 16.0f, "every active actual accepted centre sweep obeyed the authored 16 cm guard"); }
            Assert_True(Row.Segment.Sample.Stamp.Get_SampleSequence() > 0 && Row.Segment.Sample.Stamp.Get_SubjectPoseRevision() > 0,
                "captured geometry retains accepted sample/revision provenance");
            Assert_True(Row.Segment.Sample.ObservationFrame == Row.Frame, "accepted query observation and rendered-foot evidence came from the same actual world frame");
        }
        Log(f"[EndpointMeasuredEnvelope] {_CatalogLayout :n}/{_CatalogLegCount}, attack {_ExpectedEndpointId}, rows {Capture.Trace.Num()}, actual accepted max {MaxTravel} cm/{MaxAcceptedAngle} deg, accepted interval max {MaxAdvance}, evaluated-report max {MaxReported} cm/{MaxAngle} deg, actual delta [{MinDelta},{MaxDelta}], clip time {LastTime}; no integrated game backlog injection");
    }
}
