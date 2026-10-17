class UMars_AutoTest_CrawlerMelee_EndpointPhysics : UMars_AutoTestRig_CrawlerEndpointCatalog
{
    default _TimeoutSeconds = 120.0f;
    default _Origin = FVector(-600000.0, -180000.0, 600.0);
    protected bool _Miss = false;
    protected bool _Dual = false;
    protected bool _ReverseEmitters = false;
    protected bool _WorldBlocker = false;
    protected bool _BystanderBlocker = false;
    protected bool _RequireDamageExitContact = false;
    protected bool _CancelFinalCandidate = false;
    protected bool _Hitch = false;
    private bool _HitchActive = false;
    private float32 _OriginalDilation = 0.0f;
    private float64 _HitchStartSeconds = 0.0;
    private FMars_AutoTest_CrawlerMelee_Target _Bystander;
    private FCk_Handle _Wall;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_EndpointSpec();
        if (_ReverseEmitters)
        {
            auto Emitters = _CatalogPincer.Def.Hit.Emitters;
            const auto First = Emitters[0]; Emitters[0] = Emitters[1]; Emitters[1] = First;
            _CatalogPincer.Def.Hit.Emitters = Emitters;
        }
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        if (_Dual == false)
        {
            Add_Step("disable only the unused prerequisite to select the four-entry graph's right swipe", n"Step_DisableLeft");
            Add_Step_WaitUntil("left disable processed", n"Check_LeftDisabled", k_SlowPolls, 0);
        }
        Add_Step("calibrate the same clip against real native accepted geometry", n"Step_StartCalibration");
        Add_Step_WaitUntil("native calibration reaches a saved terminal", n"Check_CalibrationTerminal", k_SlowPolls, 0);
        Add_Step_WaitUntil("calibration acknowledgement releases controls", n"Check_CalibrationReleased", k_SlowPolls, 0);
        Add_Step("choose a measured accepted Damage-window anchor", n"Step_SelectMeasuredAnchor");
        Add_Step("place the physical target and optional other-emitter blocker", n"Step_PlaceMeasuredTarget");
        Add_Step_WaitFrames("let only the fixture's new physics bodies register", 3);
        Add_Step("select the measured target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("the intended anatomy choice is fully ready", n"Check_ExpectedEndpointReady", k_SlowPolls, 0);
        if (_Hitch)
        {
            Add_Step("save and dilate only the test-owned PIE world", n"Step_StartHitch");
            Add_Step_WaitFrames("let the actual dilated native frame delta arrive", 3);
        }
        Add_Step("start accepted-evidence capture", n"Step_StartCapture");
        if (_CancelFinalCandidate) { Add_Step("arm public cancellation of a real final-window candidate", n"Step_ArmFinalCancel"); }
        Add_Step("request one game attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the game attack really accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step_WaitUntil("native action and game cleanup finish", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("surviving limbs return Default/Planted", n"Check_CalibrationReleased", k_SlowPolls, 0);
        Add_Step("E01/E02/E03/E04/E06 actual accepted physics evidence", n"Step_AssertPhysics");
        Add_Step("restore the saved test-world dilation", n"Step_RestoreHitch");
        Run_Steps(InHandle);
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    { Restore_Hitch(); }

    // Restore before the base writes the result and permits the next shared-world test.
    void FinishFailure(const FString& InMessage) override
    { Restore_Hitch(); Super::FinishFailure(InMessage); }

    void FinishSuccess() override
    { Restore_Hitch(); Super::FinishSuccess(); }
    private void Restore_Hitch()
    {
        if (_HitchActive == false) { return; }
        Gameplay::SetGlobalTimeDilation(_OriginalDilation);
        _HitchActive = false;
    }

    UFUNCTION()
    private void Step_StartHitch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // The getter is BlueprintPure in GameplayStatics.h:387; its Gameplay AS alias is a compile probe in this unit.
        _OriginalDilation = Gameplay::GetGlobalTimeDilation();
        if (Math::IsFinite(_OriginalDilation) == false || _OriginalDilation <= 0.0f)
        { FinishFailure("the test-world dilation getter did not supply a valid value to restore"); return; }
        _HitchActive = true;
        _HitchStartSeconds = System::GetGameTimeInSeconds();
        Gameplay::SetGlobalTimeDilation(8.0f);
    }

    UFUNCTION()
    private void Step_RestoreHitch(FCk_Handle InHandle, FInstancedStruct InPayload)
    { Restore_Hitch(); }

    UFUNCTION()
    private void Step_DisableLeft(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Leg = _Crawler.Get_LegParts().Last().Get_Leg();
        Leg.Request_EnableDisable(FCk_Request_ProceduralLeg_EnableDisable(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Check_LeftDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_LegParts().Last().Get_Leg().Get_Status() == ECk_ProceduralLeg_Status::Disabled);
    }

    UFUNCTION()
    private void Step_PlaceMeasuredTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Centre = _ExpectedEndpointId == GameplayTags::Attack_Mars_SwipeLeft ? _CalibratedLeft : _CalibratedRight;
        if (_Dual && _WorldBlocker == false && _BystanderBlocker == false)
        {
            Centre = (_CalibratedRight + _CalibratedLeft) * 0.5;
            const auto LocalSpan = _CalibratedRoot.InverseTransformVectorNoScale(_CalibratedRight - _CalibratedLeft);
            _EndpointHalf = FVector(Math::Abs(LocalSpan.X) * 0.5 + 6.0, Math::Abs(LocalSpan.Y) * 0.5 + 6.0, Math::Abs(LocalSpan.Z) * 0.5 + 6.0);
        }
        if (_Miss) { Centre += _CalibratedRoot.GetRotation().GetRightVector() * 200.0; }
        if (_RequireDamageExitContact)
        {
            _EndpointHalf = FVector(0.05, 0.05, 0.05);
            Assert_True(_AnchorTravelDirection.IsNearlyZero() == false, "the final accepted interval has measurable endpoint travel");
            const auto LocalDirection = _CalibratedRoot.InverseTransformVectorNoScale(_AnchorTravelDirection);
            // Query transforms convert to Jolt float matrices. At this isolated 660k-cm origin the position ULP is
            // 0.0625 cm; 0.25 cm overlap exceeds that quantization while earlier sweeps must remain strictly clear.
            auto Low = 0.0;
            auto High = 12.0 + _EndpointHalf.Size();
            for (auto Iteration = 0; Iteration < 40; ++Iteration)
            {
                const auto Offset = (Low + High) * 0.5;
                if (Get_BoxDistance(LocalDirection * Offset, _EndpointHalf) < 11.75) { Low = Offset; }
                else { High = Offset; }
            }
            Centre += _AnchorTravelDirection * ((Low + High) * 0.5);
        }
        _Target = SpawnCombatTargetAt(InHandle, FTransform(_CalibratedRoot.GetRotation(), Centre), _EndpointHalf);
        auto MinimumBodyClearance = 1.0e20;
        const auto TargetFrame = utils_transform::Get_EntityCurrentTransform(_Target.Root);
        for (const auto& Receipt : _CalibrationReceipts)
        {
            const auto Body = utils_crawler::Get_HitCenter(Receipt.Get_CurrentPose().Get_BodyPresentation(), _CatalogSpec.Combat.Hit.LocalCenter);
            const auto Point = TargetFrame.InverseTransformPosition(Body);
            const auto Outside = FVector(Math::Max(Math::Abs(Point.X) - _EndpointHalf.X, 0.0),
                Math::Max(Math::Abs(Point.Y) - _EndpointHalf.Y, 0.0), Math::Max(Math::Abs(Point.Z) - _EndpointHalf.Z, 0.0));
            MinimumBodyClearance = Math::Min(MinimumBodyClearance, Outside.Size());
        }
        if (_Dual == false)
        {
            Assert_True(MinimumBodyClearance > _CatalogSpec.Combat.Hit.Radius,
                "the E01 measured target lies outside the original body's sphere for the complete accepted calibration path");
        }
        if (_RequireDamageExitContact)
        {
            auto LastDamageTime = -1.0;
            for (const auto& Receipt : _CalibrationReceipts)
            {
                if (Receipt.Get_Interval().Get_Windows().Contains(n"Damage"))
                { LastDamageTime = Math::Max(LastDamageTime, Receipt.Get_Interval().Get_ToTime().Get_Seconds()); }
            }
            const auto LimbId = _ExpectedEndpointId == GameplayTags::Attack_Mars_SwipeRight ? n"Leg0" : FName(f"Leg{_CatalogLegCount - 1}");
            for (const auto& Receipt : _CalibrationReceipts)
            {
                if (Receipt.Get_Interval().Get_Windows().Contains(n"Damage") == false ||
                    Receipt.Get_Interval().Get_ToTime().Get_Seconds() >= LastDamageTime) { continue; }
                auto From = FVector::ZeroVector;
                auto To = FVector::ZeroVector;
                auto FoundFrom = false;
                auto FoundTo = false;
                for (const auto& Limb : Receipt.Get_PreviousPose().Get_Limbs())
                { if (Limb.Get_Id() == LimbId) { From = Limb.Get_AcceptedEndpoint().GetLocation(); FoundFrom = true; } }
                for (const auto& Limb : Receipt.Get_CurrentPose().Get_Limbs())
                { if (Limb.Get_Id() == LimbId) { To = Limb.Get_AcceptedEndpoint().GetLocation(); FoundTo = true; } }
                Assert_True(FoundFrom && FoundTo, "earlier accepted Damage intervals retain both measured endpoint frames");
                Assert_True(Get_SegmentBoxDistanceLowerBound(TargetFrame.InverseTransformPosition(From),
                    TargetFrame.InverseTransformPosition(To), _EndpointHalf) > 12.0,
                    "every earlier accepted Damage sweep is strictly clear of the final-contact box");
            }
        }
        if (_WorldBlocker) { _Wall = SpawnWall(InHandle, _CalibratedLeft, FVector(6.0, 6.0, 6.0)); }
        if (_BystanderBlocker) { _Bystander = SpawnBystanderAt(InHandle, FTransform(_CalibratedRoot.GetRotation(), _CalibratedLeft), FVector(6.0, 6.0, 6.0)); }
        Log(f"[EndpointTarget] centre {Centre.ToString()}, half {_EndpointHalf.ToString()}, original-body minimum clearance {MinimumBodyClearance}");
    }

    private float64 Get_BoxDistance(FVector InPoint, FVector InHalf)
    {
        return FVector(Math::Max(Math::Abs(InPoint.X) - InHalf.X, 0.0),
            Math::Max(Math::Abs(InPoint.Y) - InHalf.Y, 0.0),
            Math::Max(Math::Abs(InPoint.Z) - InHalf.Z, 0.0)).Size();
    }

    private float64 Get_SegmentBoxDistanceLowerBound(FVector InFrom, FVector InTo, FVector InHalf)
    {
        // Distance to a convex box is convex along this segment. The residual interval's
        // half-length bounds any remaining overestimate, so passing cannot hide an earlier hit.
        auto Low = 0.0;
        auto High = 1.0;
        const auto Travel = InTo - InFrom;
        for (auto Iteration = 0; Iteration < 40; ++Iteration)
        {
            const auto First = Low + (High - Low) / 3.0;
            const auto Second = High - (High - Low) / 3.0;
            if (Get_BoxDistance(InFrom + Travel * First, InHalf) <= Get_BoxDistance(InFrom + Travel * Second, InHalf))
            { High = Second; }
            else { Low = First; }
        }
        return Get_BoxDistance(InFrom + Travel * ((Low + High) * 0.5), InHalf) - Travel.Size() * ((High - Low) * 0.5);
    }

    UFUNCTION()
    private void Step_ArmFinalCancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Command = FMars_TESTONLY_EndpointFinalCancel();
        Command.Crawler = _Crawler;
        _Capture.AddOrGet_Fragment(FMars_TESTONLY_EndpointFinalCancel) = Command;
    }

    UFUNCTION()
    private void Step_AssertPhysics(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_MeasuredTrace();
        const auto Capture = _Capture.Get_Fragment(FMars_TESTONLY_EndpointCapture);
        if (_Hitch)
        {
            auto MaxDelta = 0.0;
            for (const auto& Row : Capture.Trace) { MaxDelta = Math::Max(MaxDelta, Row.DeltaSeconds); }
            Assert_True(_HitchActive && MaxDelta > 1.0 / 60.0, "the native accepted endpoint traces really ran under a larger-than-authored-advance frame delta");
            Log(f"[EndpointHitchCompletion] actual max delta {MaxDelta}, game elapsed {System::GetGameTimeInSeconds() - _HitchStartSeconds}, saved dilation {_OriginalDilation}; limits were not expanded after failure");
        }
        Assert_True(_Crawler.Get_AttackId() == _ExpectedEndpointId, "actual selected graph entry matches the intended anatomy");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "one real game admission occurred");
        Assert_Equals_Int(_CatalogResults.Num(), 1, "one game terminal/cleanup result occurred");
        if (_CancelFinalCandidate)
        {
            const auto Command = _Capture.Get_Fragment(FMars_TESTONLY_EndpointFinalCancel);
            Assert_True(Command.Fired && Command.Frame > 0 && Command.Candidate.SampleId > 0,
                "public cancellation was queued against a real candidate on an accepted Damage-window exit interval");
            Assert_Equals_Int(Command.IssuedAtBoundary, 0, "the pending final candidate had not issued damage");
            Assert_Equals_Int(utils_mars_test_catalog::Get_IssuedDamageRequests(_Crawler), 0, "cancellation superseded the queued final-strike candidate");
            Assert_True(Capture.CommitSample == 0 && _CatalogResults.Num() == 1 &&
                _CatalogResults[0].Native.Get_Outcome() == ECk_ProceduralAction_Outcome::Cancelled,
                "the final accepted candidate is discarded and native cancellation remains explicit");
            return;
        }
        if (_WorldBlocker || _BystanderBlocker)
        {
            Assert_Equals_Int(utils_mars_test_catalog::Get_IssuedDamageRequests(_Crawler), 0, "other-emitter obstruction suppressed every damage request");
            Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "simultaneous target remained unharmed");
            if (_BystanderBlocker) { Assert_Equals_Float(_Bystander.Health.Get_Current(), 100.0f, 0.01f, "obstructing bystander also receives no damage"); }
            Assert_True(Capture.SimultaneousBlockedSamples > 0,
                "the same real accepted sample hit the selected target on one emitter and a blocker on the other");
            Assert_True(_Crawler.Get_AttackLastCancel().IsSet() && _Crawler.Get_AttackLastCancel().GetValue() == EMars_Crawler_AttackCancel::Obstructed,
                "world/bystander obstruction remains the real game cancellation reason");
            return;
        }
        Assert_Equals_Int(Get_DamageRequestCount(), _Miss ? 0 : 1, "all emitters share one per-attempt damage ledger");
        Assert_Equals_Float(_Target.Health.Get_Current(), _Miss ? 100.0f : 85.0f, 0.01f, "accepted endpoint physics alone decides the hit");
        if (_Miss) { Assert_True(Capture.CommitSample == 0, "a physical miss has no committed accepted sample"); return; }
        Assert_True(Capture.CommitSample > 0 && Capture.CommitContact.EmitterId.IsValid(),
            "commit retains actual accepted sample and emitter identity");
        if (_Dual) { Assert_True(Capture.DualContactSamples > 0, "both endpoint spheres actually contacted the target in a shared accepted sample"); }
        auto CandidateSeen = false;
        auto ExitContact = false;
        for (const auto& Candidate : Capture.Candidates)
        {
            if (Candidate.SampleId != Capture.CommitSample) { continue; }
            CandidateSeen = Candidate.EmitterContact.EmitterId == Capture.CommitContact.EmitterId;
            auto Best = FMars_Crawler_EmitterContact();
            auto HaveBest = false;
            for (const auto& Row : Capture.Trace)
            {
                if (Row.Segment.Sample.Stamp.Get_SampleSequence() != Candidate.SampleId || Row.Segment.Activity.Damage == false || Row.QueryZone != _Target.Zone) { continue; }
                auto Contact = FMars_Crawler_EmitterContact();
                Contact.EmitterId = Row.Segment.Emitter.Id;
                Contact.Fraction = Row.QueryFraction;
                if (HaveBest == false || utils_crawler::Get_IsEarlierEmitterContact(Contact, Best)) { Best = Contact; HaveBest = true; }
                for (const auto& Event : Row.Interval.Get_Events())
                { ExitContact = ExitContact || Event.Get_Id() == n"Damage" && Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowExit; }
            }
            Assert_True(HaveBest && Best.EmitterId == Capture.CommitContact.EmitterId && Math::Abs(Best.Fraction - Capture.CommitContact.Fraction) < 1.0e-5f,
                "actual earliest contact and canonical emitter tie-break match the committed contact regardless authored array order");
        }
        Assert_True(CandidateSeen, "stored candidate and commit name the same accepted sample/emitter");
        Assert_True(Capture.EarlyStrikeSamples > 0 && Capture.LateStrikeSamples > 0 && Capture.DamageExitSamples > 0,
            "real accepted early Strike and Damage exit intervals were observed without an extra hit");
        if (_RequireDamageExitContact)
        { Assert_True(ExitContact, "the physical hit belongs to an accepted interval ending at Damage closure; fail rather than claim an earlier hit proves this"); }
        if (_Dual) { return; } // E02 spans both claws; its box can overlap the reference body. E01 proves body noncontact.
        for (const auto& Row : Capture.Trace)
        {
            const auto Frame = utils_transform::Get_EntityCurrentTransform(_Target.Root);
            const auto Point = Frame.InverseTransformPosition(Row.BodyCenter);
            const auto Outside = FVector(Math::Max(Math::Abs(Point.X) - _EndpointHalf.X, 0.0),
                Math::Max(Math::Abs(Point.Y) - _EndpointHalf.Y, 0.0), Math::Max(Math::Abs(Point.Z) - _EndpointHalf.Z, 0.0));
            Assert_True(Outside.Size() > _CatalogSpec.Combat.Hit.Radius, "actual game body path also remained outside the target");
        }
    }
}
