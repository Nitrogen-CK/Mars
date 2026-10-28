// A deliberately isolated motion gym, not an autonomous enemy. Exactly one public procedural action player owns every
// body/limb pose. No transform teleports, disabled collisions, scaled bones, or independent leg animation clocks.
class UMars_CrawlerDoorway_EntityScript : UMars_Crawler_EntityScript
{
    UPROPERTY(ExposeOnSpawn)
    bool Loop = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Crawler_DoorwayPortal Portal;

    UPROPERTY(ExposeOnSpawn)
    bool BlockExit = false;

    default Color = FLinearColor(0.48, 0.42, 0.32);

    private FCk_Handle _Owner;
    private FCk_Handle_ProceduralArticulation _Subject;
    private FCk_Handle_ProceduralActionPlayer _Player;
    private FCk_Handle_ProceduralAction _Action;
    private FMars_Crawler_Rig _Rig;
    private TArray<FCk_Handle_SceneNode> _Coxae;
    private TArray<FCk_Handle_JoltBody> _Solids;
    private FVector _PortalOrigin;
    UPROPERTY()
    private UCk_ProceduralAction_Data _Clip;
    private FCk_ProceduralAction_Identity _Identity;
    private int64 _Cursor = 0;
    private int32 _Accepted = 0;
    private int32 _SweepChecks = 0;
    private int32 _RefinedSweeps = 0;
    private bool _Started = false;
    private bool _Stopped = false;
    private bool _SawFarSide = false;
    private bool _SawLowCrossing = false;
    private bool _SawBraceContacts = false;
    private bool _SawConcurrentStride = false;
    private float64 _MaxJointGap = 0.0;
    private float64 _MaxFootGap = 0.0;
    private float64 _MaxQuaternionError = 0.0;
    private float64 _LastMotionAngle = 0.0;
    private FVector _LastBody;
    private FVector _LastFoot;
    private FString _LastGeometryHit;
    private FString _Phase;
    private int32 _CompletedCycles = 0;
    private float64 _PlaybackSeconds = 0.0;
    private float64 _CrossingStartSeconds = -1.0;
    private float64 _LastBodyAdvanceSeconds = 0.0;
    private float64 _MeasuredCrossingSeconds = -1.0;
    private float64 _MaxCrossingPauseSeconds = 0.0;
    private bool _CrossingComplete = false;

    UFUNCTION(BlueprintPure)
    FString Get_TraversalStatus() const
    {
        return f"cycles={_CompletedCycles}; phase={_Phase}; accepted={_Accepted}; sweeps={_SweepChecks}; refined={_RefinedSweeps}; stopped={_Stopped}; brace={_SawBraceContacts}; concurrent={_SawConcurrentStride}; lowered={_SawLowCrossing}; farSide={_SawFarSide}; jointGapCm={_MaxJointGap}; footGapCm={_MaxFootGap}; crossingActive={_CrossingStartSeconds >= 0.0 && _CrossingComplete == false}; crossingSeconds={_MeasuredCrossingSeconds}; maxPauseSeconds={_MaxCrossingPauseSeconds}; bodyX={_LastBody.X}";
    }

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        _Owner = InHandle;
        _PortalOrigin = SpawnTransform.GetLocation() - FVector(utils_crawler::DoorwayStartX, 0.0, utils_crawler::DoorwayStandingHeight);
        if (SpawnTransform.GetRotation().Equals(FQuat::Identity, 0.001) == false ||
            SpawnTransform.GetScale3D().Equals(FVector::OneVector, 0.001) == false)
        {
            Fail("This first authored gym requires an unrotated, unscaled spawn");
            return ECk_EntityScript_ConstructionFlow::Finished;
        }
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        _Rig = BuildRig(InHandle, utils_crawler::Mars_CrawlerDoorwayRig8, utils_crawler::DoorwayBodyHalfExtents);
        for (int32 Index = 0; Index < 8; ++Index)
        {
            _Coxae.Add(AddRigAttachment(_Rig.Presentation,
                FMars_Crawler_PartVisual(utils_crawler::Get_DoorwayCoxaHalfExtents(Index), Color, nullptr),
                utils_crawler::Get_DoorwayCoxaOffset(Index)));
        }
        const auto Silhouette = utils_crawler::Make_DoorwaySilhouette();
        for (int32 Part = 0; Part < Silhouette.Num(); ++Part)
        {
            const auto Tint = Part == 1 ? FLinearColor(0.025, 0.02, 0.015) :
                (Part >= 3 ? FLinearColor(1.0, 0.65, 0.04) : Color);
            AddRigAttachment(_Rig.Presentation, FMars_Crawler_PartVisual(Silhouette[Part].Half, Tint, nullptr), Silhouette[Part].Frame);
        }
        AddSolid(FVector(0.0, 0.0, -10.0), FVector(1200.0, 650.0, 10.0), FLinearColor(0.12, 0.14, 0.18));
        const auto SideHalfWidth = 250.0;
        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            AddSolid(FVector(0.0, Side * (Portal.Width * 0.5 + SideHalfWidth), 220.0),
                FVector(Portal.Depth * 0.5, SideHalfWidth, 220.0), FLinearColor(0.14, 0.24, 0.32));
        }
        AddSolid(FVector(0.0, 0.0, (440.0 + Portal.Height) * 0.5),
            FVector(Portal.Depth * 0.5, Portal.Width * 0.5, (440.0 - Portal.Height) * 0.5), FLinearColor(0.14, 0.24, 0.32));
        if (BlockExit)
        { AddSolid(FVector(150.0, 0.0, 110.0), FVector(30.0, 95.0, 110.0), FLinearColor(0.8, 0.15, 0.05)); }

        auto Layouts = TArray<FCk_ProceduralLimb_Layout>();
        auto Bindings = TArray<FCk_ProceduralLimb_Binding>();
        for (int32 Index = 0; Index < 8; ++Index)
        {
            const auto Leg = utils_crawler::Mars_CrawlerDoorwayRig8.Get_Legs()[Index];
            const auto Hip = Leg.Get_Placement().Get_HipLocal();
            auto Layout = FCk_ProceduralLimb_Layout(Leg.Get_Id(), FTransform(Hip),
                Leg.Get_Chain().Get_SegmentLengths(), FTransform(Leg.Get_Placement().Get_RestFootLocal() - Hip),
                utils_crawler::Get_DoorwayBend(Index));
            // This authored clip holds a stable knee plane; full body/segment/foot boxes are independently audited below.
            Layout.Set_Clearance(ECk_ProceduralRig_Clearance::None);
            Layouts.Add(Layout);
            auto Binding = FCk_ProceduralLimb_Binding(Leg.Get_Id(), _Rig.Legs[Index].Segments);
            Binding.Set_Terminal(_Rig.Legs[Index].Foot);
            Bindings.Add(Binding);
        }
        auto Topology = FCk_ProceduralArticulation_Layout(Layouts);
        Topology.Set_BodyEnvelopeMin(-_Rig.BodyHalfExtents);
        Topology.Set_BodyEnvelopeMax(_Rig.BodyHalfExtents);
        auto SubjectSpec = FCk_ProceduralArticulation_Spec(Topology, Bindings);
        SubjectSpec.Set_Presentation(_Rig.Presentation);
        auto Clearance = FCk_ProceduralArticulation_ClearanceSettings();
        Clearance.Set_Query(ECk_ProceduralArticulation_ClearanceQuery::JoltFilter);
        SubjectSpec.Set_ClearanceSettings(Clearance);
        _Subject = utils_procedural_articulation::Add(Root, SubjectSpec);
        // Giant limbs need more small, qualified samples per service tick to keep up at 30 FPS.
        // Preserve the 2 cm / 5 degree / 1/120 second limits; increase work capacity, not contact tolerance.
        auto PlayerSpec = FCk_ProceduralActionPlayer_Spec();
        auto Tuning = PlayerSpec.Get_Tuning();
        auto Sampling = Tuning.Get_Sampling();
        Sampling.Set_MaxSamples(64);
        Tuning.Set_Sampling(Sampling);
        PlayerSpec.Set_Tuning(Tuning);
        _Player = utils_procedural_action_player::Add(_Subject, PlayerSpec);
        _Clip = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        const auto Report = utils_crawler::Build_DoorwayClip(_Clip);
        if (Report.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
        {
            auto Details = "";
            for (const auto& Diagnostic : Report.Get_Diagnostics())
            { Details = f"{Details} [{Diagnostic.Get_Code()} expected {Diagnostic.Get_Expected()} actual {Diagnostic.Get_Actual()}]"; }
            Fail(f"The doorway clip failed content validation:{Details}");
        }
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDoorwayTick"));
    }

    private void AddSolid(FVector InCenter, FVector InHalfExtents, FLinearColor InColor)
    {
        auto Node = AddVisual(_Owner, FMars_Crawler_PartVisual(InHalfExtents, InColor, nullptr));
        // One construction-time placement request; the creature itself is only ever posed by the action player.
        utils_transform::Request_SetTransform(Node, FTransform(_PortalOrigin + InCenter));
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Static);
        BodySpec.Set_CollisionProfileName(n"BlockAll");
        FCk_Handle Entity = Node;
        _Solids.Add(utils_jolt_body::Add(Entity, BodySpec));
    }

    private bool AreSolidsReady() const
    {
        for (const auto& Solid : _Solids)
        {
            if (ck::Is_NOT_Valid(Solid) || utils_jolt_body::Get_IsBodyAdded(Solid) == false)
            { return false; }
        }
        return _Solids.Num() >= 4;
    }

    private void Start()
    {
        const auto Validation = utils_crawler::Validate_DoorwayPortal(Portal);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(utils_crawler::DoorwayBodyHalfExtents);
        const auto ExitHit = utils_jolt_query::Get_ShapeCast(_PortalOrigin + FVector(-180.0, 0.0, 110.0),
            _PortalOrigin + FVector(420.0, 0.0, 110.0), FRotator::ZeroRotator, Shape, FCk_Jolt_QueryFilter());
        _Started = true;
        if (Validation.IsValid() == false || ExitHit.Get_HasHit())
        {
            utils_entity_tag::Add(_Owner, n"TAG_MarsDoorwayRejected");
            ck::Trace("[Doorway] Rejected before playback: unsupported frame or obstructed body route/exit");
            _Stopped = true;
            return;
        }
        auto Play = FCk_ProceduralAction_PlaySpec(TSoftObjectPtr<UCk_ProceduralAction_Data>(_Clip));
        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        for (int32 Index = 0; Index < 8; ++Index)
        { Bindings.Add(FCk_ProceduralAction_SlotBinding(FName(f"Leg{Index}"), FName(f"Leg{Index}"))); }
        Play.Set_SlotBindings(Bindings);
        Play.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);
        _Action = utils_procedural_action::Create_FromClip(_Owner, _Player, Play);
        if (ck::Is_NOT_Valid(_Action))
        { Fail("The action player did not create the doorway action"); return; }
        _Identity = _Action.Get_Identity();
        _Cursor = 0;
        _SawFarSide = false;
        _SawLowCrossing = false;
        _SawBraceContacts = false;
        _SawConcurrentStride = false;
        _PlaybackSeconds = 0.0;
        _CrossingStartSeconds = -1.0;
        _LastBodyAdvanceSeconds = 0.0;
        _MaxCrossingPauseSeconds = 0.0;
        _CrossingComplete = false;
    }

    UFUNCTION()
    private void OnDoorwayTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_Stopped || ck::Is_NOT_Valid(_Subject))
        { return; }
        if (_Started == false)
        {
            if (AreSolidsReady() && _Subject.Get_SettledRevision() > 0 && ck::Is_NOT_Valid(_Action))
            { Start(); }
            return;
        }
        _PlaybackSeconds += InDeltaT.Get_Seconds();
        const auto Page = _Player.Read_Receipts(_Identity, _Cursor, 64);
        if (Page.Get_Result() != ECk_ProceduralAction_ReadResult::Succeeded &&
            Page.Get_Result() != ECk_ProceduralAction_ReadResult::Pending)
        { Fail(f"Receipt stream lost: {Page.Get_Result() :n}"); return; }
        auto Completed = false;
        for (const auto& Record : Page.Get_Records())
        {
            if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose)
            {
                const auto Receipt = Record.Get_Receipt();
                _Phase = Receipt.Get_Interval().Get_PhaseId().ToString();
                _LastMotionAngle = Receipt.Get_Sampling().Get_MaxSegmentAngularStepDegrees();
                if (CheckPose(Receipt.Get_PreviousPose(), Receipt.Get_CurrentPose()) == false)
                { return; }
                ++_Accepted;
            }
            if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
            {
                if (Record.Get_Result().Get_Outcome() != ECk_ProceduralAction_Outcome::Completed)
                {
                    Fail(f"Playback failed after {_Accepted} accepted poses, last {_Phase}, subject {_Subject.Get_Fault() :n}, max quat norm error {_MaxQuaternionError}, max joint gap {_MaxJointGap}, last angular step {_LastMotionAngle}, body {_LastBody.ToString()}, foot {_LastFoot.ToString()}: {utils_procedural_action::Get_ResultText(Record.Get_Result(), Record.Get_Context()).ToString()}");
                    return;
                }
                Completed = true;
            }
        }
        if (_CrossingStartSeconds >= 0.0 && _CrossingComplete == false &&
            _PlaybackSeconds - _LastBodyAdvanceSeconds > 0.1)
        { Fail("The body paused for more than 0.1 seconds during the forward crossing"); return; }
        _Cursor = Page.Get_LastStreamSequence();
        if (Page.Get_Records().Num() > 0)
        { _Player.Request_ConsumeReceipts(FCk_Request_ProceduralActionPlayer_ConsumeReceipts(_Identity, _Cursor)); }
        if (Completed)
        {
            if (_SawFarSide == false || _SawLowCrossing == false || _SawBraceContacts == false || _SawConcurrentStride == false || _CrossingComplete == false || _Accepted < 100)
            { Fail("The clip ended without a complete lowered crossing and return"); return; }
            utils_entity_tag::Add(_Owner, n"TAG_MarsDoorwayCompleted");
            ++_CompletedCycles;
            ck::Trace(f"[Doorway] PASS: {_Accepted} accepted poses, {_SweepChecks} swept boxes, max joint gap {_MaxJointGap} cm, max foot gap {_MaxFootGap} cm, eight fixed-length legs, four masonry brace contacts, continuous crossing {_MeasuredCrossingSeconds} s, max body pause {_MaxCrossingPauseSeconds} s, lowered crossing and return");
            _Stopped = Loop == false;
            _Started = false;
            _Accepted = 0;
            _SweepChecks = 0;
        }
        if (WithVisuals)
        {
            utils_debug_draw::DrawDebugString(_PortalOrigin + FVector(-140.0, 0.0, 380.0),
                f"LONG WIDOW / 8 LEGS\n{_Phase}\n{_Accepted} accepted poses / {_SweepChecks} swept boxes", FLinearColor(0.5, 0.85, 1.0));
        }
    }

    private bool CheckPose(const FCk_ProceduralArticulation_Pose& InPrevious, const FCk_ProceduralArticulation_Pose& InCurrent)
    {
        if (InCurrent.Get_HasBodyPresentation() == false || InCurrent.Get_Limbs().Num() != 8 || InPrevious.Get_Limbs().Num() != 8)
        { Fail("An accepted pose is missing the body or one of its eight legs"); return false; }
        const auto Body = InCurrent.Get_BodyPresentation();
        const auto LocalBody = Body.GetLocation() - _PortalOrigin;
        _LastBody = LocalBody;
        _LastFoot = InCurrent.Get_Limbs()[0].Get_AcceptedEndpoint().GetLocation() - _PortalOrigin;
        if (LocalBody.X > 300.0 && LocalBody.Z > 260.0)
        { _SawFarSide = true; }
        if (Math::Abs(LocalBody.X - 35.0) < 20.0 && Math::Abs(LocalBody.Z - 110.0) < 0.5)
        { _SawLowCrossing = true; }
        if (CheckBox(InPrevious.Get_BodyPresentation(), Body, utils_crawler::DoorwayBodyHalfExtents) == false)
        { Fail(f"Body intersects a solid in {_Phase}"); return false; }
        auto Boxes = TArray<FMars_Crawler_DoorwayBox>();
        Boxes.Add(FMars_Crawler_DoorwayBox(Body, utils_crawler::DoorwayBodyHalfExtents, -1));
        if (Body.GetRotation().GetForwardVector().DotProduct(FVector::ForwardVector) < 0.999)
        { Fail(f"Body is not facing head-first along the doorway route in {_Phase}"); return false; }
        for (const auto& Part : utils_crawler::Make_DoorwaySilhouette())
        {
            const auto Current = Part.Frame * Body;
            if (CheckBox(Part.Frame * InPrevious.Get_BodyPresentation(), Current, Part.Half) == false)
            { Fail(f"Head/abdomen silhouette intersects a solid in {_Phase}: {_LastGeometryHit}"); return false; }
            Boxes.Add(FMars_Crawler_DoorwayBox(Current, Part.Half, -1));
        }
        for (int32 Index = 0; Index < 8; ++Index)
        {
            const auto Offset = utils_crawler::Get_DoorwayCoxaOffset(Index);
            const auto Current = Offset * Body;
            const auto Half = utils_crawler::Get_DoorwayCoxaHalfExtents(Index);
            if (CheckBox(Offset * InPrevious.Get_BodyPresentation(), Current, Half) == false)
            { Fail(f"Hip attachment {Index} intersects a solid in {_Phase}: {_LastGeometryHit}"); return false; }
            Boxes.Add(FMars_Crawler_DoorwayBox(Current, Half, Index));
        }
        const auto Legs = InCurrent.Get_Limbs();
        const auto PreviousLegs = InPrevious.Get_Limbs();
        auto SupportContacts = 0;
        auto BraceContacts = 0;
        for (int32 Index = 0; Index < Legs.Num(); ++Index)
        {
            const auto Segments = Legs[Index].Get_Segments();
            const auto PreviousSegments = PreviousLegs[Index].Get_Segments();
            if (Segments.Num() != 2 || PreviousSegments.Num() != 2 || Legs[Index].Get_EndpointErrorCm() > 0.1f)
            { Fail(f"Leg {Index} has incomplete geometry or an unreachable endpoint in {_Phase}"); return false; }
            auto Joint = Body.TransformPosition(utils_crawler::Get_DoorwayHip(Index));
            for (int32 Segment = 0; Segment < 2; ++Segment)
            {
                const auto Transform = Segments[Segment];
                Boxes.Add(FMars_Crawler_DoorwayBox(Transform, FVector(90.0, 6.0, 6.0), Index));
                const auto Rotation = Transform.GetRotation();
                _MaxQuaternionError = Math::Max(_MaxQuaternionError,
                    Math::Abs(Rotation.X * Rotation.X + Rotation.Y * Rotation.Y + Rotation.Z * Rotation.Z + Rotation.W * Rotation.W - 1.0));
                const auto Axis = Transform.GetRotation().GetForwardVector() * (utils_crawler::DoorwayBoneLength * 0.5);
                const auto JointGap = (Transform.GetLocation() - Axis - Joint).Size();
                _MaxJointGap = Math::Max(_MaxJointGap, JointGap);
                // Match the existing procedural-rig geometry test's 0.5 cm endpoint/connection budget. This does not
                // expand the separate solid-penetration tolerance (0.02 cm); the actual rendered boxes are tested below.
                if (JointGap > 0.5 ||
                    Transform.GetScale3D().Equals(FVector::OneVector, 0.001) == false)
                { Fail(f"Leg {Index} segment {Segment} disconnected in {_Phase}: gap {JointGap} cm, scale {Transform.GetScale3D().ToString()}, body {(Body.GetLocation() - _PortalOrigin).ToString()}, foot {(Legs[Index].Get_AcceptedEndpoint().GetLocation() - _PortalOrigin).ToString()}"); return false; }
                Joint = Transform.GetLocation() + Axis;
                if (CheckBox(PreviousSegments[Segment], Transform, FVector(90.0, 6.0, 6.0)) == false)
                { Fail(f"Leg {Index} segment {Segment} intersects a solid in {_Phase}: {_LastGeometryHit}"); return false; }
            }
            const auto FootGap = (Joint - Legs[Index].Get_AcceptedEndpoint().GetLocation()).Size();
            _MaxFootGap = Math::Max(_MaxFootGap, FootGap);
            if (FootGap > 0.5)
            { Fail(f"Leg {Index} does not end at its foot in {_Phase}"); return false; }
            if (CheckBox(PreviousLegs[Index].Get_AcceptedEndpoint(), Legs[Index].Get_AcceptedEndpoint(), FVector(8.0, 8.0, 8.0)) == false)
            { Fail(f"Foot {Index} intersects a solid in {_Phase}"); return false; }
            const auto Foot = Legs[Index].Get_AcceptedEndpoint().GetLocation();
            if (Body.GetLocation().X - InPrevious.Get_BodyPresentation().GetLocation().X > 0.001 &&
                (Foot - PreviousLegs[Index].Get_AcceptedEndpoint().GetLocation()).Size() > 0.001)
            { _SawConcurrentStride = true; }
            Boxes.Add(FMars_Crawler_DoorwayBox(Legs[Index].Get_AcceptedEndpoint(), FVector(8.0), Index));
            if (Math::Abs(Foot.Z - _PortalOrigin.Z - utils_crawler::DoorwayFootHeight) < 0.02)
            {
                const auto Contact = utils_jolt_query::Get_RayCast(Foot, Foot - FVector(0.0, 0.0, 8.1), FCk_Jolt_QueryFilter());
                if (Contact.Get_HasHit() && Contact.Get_Normal().Z > 0.9)
                { ++SupportContacts; }
            }
            else if (Math::Abs(Foot.X - _PortalOrigin.X + 28.0) < 0.02)
            {
                const auto Contact = utils_jolt_query::Get_RayCast(Foot, Foot + FVector(8.1, 0.0, 0.0), FCk_Jolt_QueryFilter());
                if (Contact.Get_HasHit() && Contact.Get_Normal().X < -0.9)
                {
                    ++SupportContacts;
                    if (Index < 2 || Index > 5)
                    { ++BraceContacts; }
                }
            }
        }
        if (BraceContacts == 4)
        { _SawBraceContacts = true; }
        if (SupportContacts < 6)
        { Fail(f"Only {SupportContacts} real floor/masonry supports remain in {_Phase}"); return false; }
        for (int32 Left = 0; Left < Boxes.Num(); ++Left)
        {
            for (int32 Right = Left + 1; Right < Boxes.Num(); ++Right)
            {
                // Adjacent parts of one articulated leg intentionally meet at their joints.
                if (Boxes[Left].Leg == Boxes[Right].Leg)
                { continue; }
                if (utils_crawler::Get_DoorwayBoxesOverlap(Boxes[Left], Boxes[Right]))
                { Fail(f"Self overlap boxes {Left}/{Right}, legs {Boxes[Left].Leg}/{Boxes[Right].Leg} in {_Phase}"); return false; }
            }
        }
        if (_Phase.Contains("Return") == false && _CrossingComplete == false)
        {
            auto LeadingX = -1000000.0;
            auto TrailingX = 1000000.0;
            for (const auto& Box : Boxes)
            {
                LeadingX = Math::Max(LeadingX, Box.Max.X - _PortalOrigin.X);
                TrailingX = Math::Min(TrailingX, Box.Min.X - _PortalOrigin.X);
            }
            if (_CrossingStartSeconds < 0.0 && LeadingX >= -Portal.Depth * 0.5 - 0.02)
            {
                _CrossingStartSeconds = _PlaybackSeconds;
                _LastBodyAdvanceSeconds = _PlaybackSeconds;
            }
            if (_CrossingStartSeconds >= 0.0)
            {
                const auto DeltaX = Body.GetLocation().X - InPrevious.Get_BodyPresentation().GetLocation().X;
                if (DeltaX < -0.001)
                { Fail("The body reversed during the forward crossing"); return false; }
                if (DeltaX > 0.001)
                {
                    _MaxCrossingPauseSeconds = Math::Max(_MaxCrossingPauseSeconds, _PlaybackSeconds - _LastBodyAdvanceSeconds);
                    _LastBodyAdvanceSeconds = _PlaybackSeconds;
                }
                if (TrailingX > Portal.Depth * 0.5 + 0.02)
                {
                    _MeasuredCrossingSeconds = _PlaybackSeconds - _CrossingStartSeconds;
                    if (_MeasuredCrossingSeconds < 3.0 || _MeasuredCrossingSeconds > 5.0)
                    { Fail(f"Actual first-entry/last-clear crossing took {_MeasuredCrossingSeconds} s; required 3-5 s"); return false; }
                    _CrossingComplete = true;
                    utils_entity_tag::Add(_Owner, n"TAG_MarsDoorwayTimedCrossing");
                    ck::Trace(f"[Doorway] Crossing cleared in {_MeasuredCrossingSeconds} s; max body pause {_MaxCrossingPauseSeconds} s");
                }
            }
        }
        return true;
    }

    private bool CheckBox(FTransform InPrevious, FTransform InCurrent, FVector InHalfExtents)
    {
        // Subdivide the conservative OBB sweep. One frame-wide angular expansion can touch the floor even when the
        // complete moving box stays clear. Each small cast still encloses every point of its rotating box.
        const auto A = InPrevious.GetRotation();
        const auto B = InCurrent.GetRotation();
        const auto Dot = Math::Clamp(Math::Abs(A.X * B.X + A.Y * B.Y + A.Z * B.Z + A.W * B.W), 0.0, 1.0);
        const auto Angle = 2.0 * Math::Acos(Dot);
        const auto Travel = (InCurrent.GetLocation() - InPrevious.GetLocation()).Size();
        const auto Count = int32(Math::Max(Angle / Math::DegreesToRadians(0.25), Travel / 0.5)) + 1;
        if (Count > 512)
        { _LastGeometryHit = f"audit substep budget exceeded: {Count}"; return false; }
        auto Previous = InPrevious;
        for (int32 Index = 1; Index <= Count; ++Index)
        {
            auto Current = FTransform();
            const auto Alpha = float64(Index) / Count;
            Current.SetLocation(Math::Lerp(InPrevious.GetLocation(), InCurrent.GetLocation(), Alpha));
            Current.SetRotation(FQuat::Slerp(A, B, Alpha));
            if (CheckBoxInterval(Previous, Current, InHalfExtents, 0) == false)
            { return false; }
            Previous = Current;
        }
        return true;
    }

    // Every accepted interval still needs a clear conservative enclosure. Near a planted foot, its rotating lower
    // segment can make the coarse enclosure touch the jamb while the actual box stays clear. Split only those
    // inconclusive intervals; never accept a colliding enclosure or increase the 0.02 cm penetration tolerance.
    private bool CheckBoxInterval(FTransform InPrevious, FTransform InCurrent, FVector InHalfExtents, int32 InDepth)
    {
        const auto A = InPrevious.GetRotation();
        const auto B = InCurrent.GetRotation();
        const auto Dot = Math::Clamp(Math::Abs(A.X * B.X + A.Y * B.Y + A.Z * B.Z + A.W * B.W), 0.0, 1.0);
        const auto Angle = 2.0 * Math::Acos(Dot);
        const auto Expansion = 2.0 * InHalfExtents.Size() * Math::Sin(Angle * 0.5);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents + FVector(Expansion - 0.02));
        ++_SweepChecks;
        auto Hit = utils_jolt_query::Get_Overlap(InCurrent.GetLocation(), InCurrent.Rotator(), Shape, FCk_Jolt_QueryFilter()).Num() > 0;
        if (Hit == false && InPrevious.GetLocation().Equals(InCurrent.GetLocation(), 0.0001) == false)
        {
            Hit = utils_jolt_query::Get_ShapeCast(InPrevious.GetLocation(), InCurrent.GetLocation(),
                InPrevious.Rotator(), Shape, FCk_Jolt_QueryFilter()).Get_HasHit();
        }
        if (Hit == false)
        { return true; }
        Shape.Set_HalfExtents(InHalfExtents - FVector(0.02));
        if (utils_jolt_query::Get_Overlap(InCurrent.GetLocation(), InCurrent.Rotator(), Shape, FCk_Jolt_QueryFilter()).Num() > 0)
        {
            _LastGeometryHit = f"actual box overlap at {(InCurrent.GetLocation() - _PortalOrigin).ToString()}";
            return false;
        }
        if (InDepth >= 8)
        {
            _LastGeometryHit = f"could not prove clearance after eight enclosure subdivisions; expansion {Expansion}";
            return false;
        }
        ++_RefinedSweeps;
        auto Mid = FTransform();
        Mid.SetLocation((InPrevious.GetLocation() + InCurrent.GetLocation()) * 0.5);
        Mid.SetRotation(FQuat::Slerp(A, B, 0.5));
        return CheckBoxInterval(InPrevious, Mid, InHalfExtents, InDepth + 1) &&
            CheckBoxInterval(Mid, InCurrent, InHalfExtents, InDepth + 1);
    }

    private void Fail(const FString& InReason)
    {
        _Stopped = true;
        utils_entity_tag::Add(_Owner, n"TAG_MarsDoorwayFailed");
        ck::Ensure(false, f"[Doorway] {InReason}");
        if (ck::IsValid(_Action))
        { _Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel()); }
    }
}
