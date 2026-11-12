// The food board net tests' shared steps, on the food net rig. The server spawns a test station under the replicated spawn
// owner at the floor's top: the base station (Authority input stance, the cutting net rig's control state machine, which
// nobody operates) with a Cutting and a FoodBoard whose pile node is the root's origin, tagged so each machine finds its
// copy. The slab is the food rig's meat slab, Ready and at rest on the floor at the station's origin, then made Kinematic.
// Each machine records, in order, the board signals its own copy raises. What the client compares against goes out in one
// test-only replicated report on the subject: the server's held pieces' ids and root poses at a numbered step.

namespace constants_foodboard_net_autotest
{
    const int32 k_MaxHeldPieces = 4;
    const int32 k_MaxCutsPerChop = 2;
    const float32 k_SeparationCm = 10.0f;
    // The board is quiet once this many frames in a row read no held piece with a board cut pending.
    const int32 k_QuietFrames = 5;
    // A beat for the client's copy to compose and bind before the server's first request.
    const float32 k_ClientBindSeconds = 1.0f;
    // The client asserts this long after a report step arrives.
    const float32 k_ClientSettleSeconds = 1.0f;
    // The server holds this long after its last report before it ends.
    const float32 k_ReportHoldSeconds = 2.5f;
    const float32 k_StepSeconds = 1.5f;
    // The client's tolerance against the report.
    const float64 k_ReportToleranceCm = 1.0;
    const float64 k_ReportToleranceDegrees = 1.0;
    // The server's tolerance against its own geometry.
    const float64 k_ServerToleranceCm = 0.01;
    const float64 k_ServerToleranceDegrees = 0.01;
    // The remote seed's press serial on every row it carries: presses from before it never count.
    const int32 k_SeedSerial = 7;
    // Frames the server waits after the seed before a press, so the reader has polled it.
    const int32 k_SeedFrames = 10;
}

// How either machine reads a world item's pickup and its ledger's claim.
namespace mars_test_ledger_claim
{
    // InWorldItem's pickup holds the Ledger reason on this machine.
    bool Get_IsHeldByLedger(FCk_Handle_WorldItem InWorldItem)
    {
        const auto Pickup = InWorldItem.Get_Pickup();
        return ck::IsValid(Pickup) && Pickup.Get_IsDisabledFor(EMars_Interactable_DisableReason::Ledger);
    }

    // InWorldItem's pickup can take focus on this machine; false without a pickup.
    bool Get_IsFocusable(FCk_Handle_WorldItem InWorldItem)
    {
        const auto Pickup = InWorldItem.Get_Pickup();
        return ck::IsValid(Pickup) && Pickup.Get_IsFocusable();
    }

    FString Describe(FCk_Handle_WorldItem InWorldItem)
    {
        if (ck::Is_NOT_Valid(InWorldItem))
        { return "no world item"; }

        return f"ledger-held={Get_IsHeldByLedger(InWorldItem)} focusable={Get_IsFocusable(InWorldItem)} claim={InWorldItem.Get_LedgerClaim() :n}";
    }
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only: a feature's processors are
// the only writers in game code). In parallel: the held pieces' ids and root poses, board order.
struct FMars_Fragment_TESTONLY_NetFoodBoardReport
{
    UPROPERTY()
    int32 Serial = 0;

    UPROPERTY()
    int32 Step = 0;

    UPROPERTY()
    TArray<FGuid> Ids;

    UPROPERTY()
    TArray<FVector> Locations;

    UPROPERTY()
    TArray<float64> Yaws;
}

// One board signal a machine's copy raised.
enum EMars_TESTONLY_NetBoardEvent
{
    CutIssued,
    Turned,
    ReleaseRefused,
    HeldCountChanged,
    Placed,
    PieceCut,
    Released,
    // The cleaver's, recorded once Begin_OperatorRig ran.
    ChopStarted,
    ChopLanded
}

// How the standing pieces on a client compare with the report: the reported ids found standing, and the worst errors.
struct FMars_TESTONLY_NetBoardPoseCheck
{
    int32 Reported = 0;
    int32 Found = 0;
    float64 WorstCm = 0.0;
    float64 WorstDegrees = 0.0;
}

// The test board station: the base station with a Cutting (its lateral node on the root) and a FoodBoard (its pile node at
// the root's origin), tagged on its root.
class UMars_TESTONLY_NetBoardStation_EntityScript : UMars_TESTONLY_Station_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        auto Handle = InRoot.H();
        utils_entity_tag::Add(Handle, n"TAG_MarsTestNetBoardStation");

        auto Spec = FMars_Cutting_Spec(constants_cutting_net_autotest::k_BoardHalfWidth, constants_cutting_net_autotest::k_ChopSeconds);
        Spec.Nodes = FMars_Cutting_Nodes(utils_scene_node::Create(InRoot, FTransform::Identity));
        utils_cutting::Add(Handle, Spec);

        auto Tuners = FMars_FoodBoard_Tuners();
        Tuners.MaxHeldPieces = constants_foodboard_net_autotest::k_MaxHeldPieces;
        Tuners.MaxCutsPerChop = constants_foodboard_net_autotest::k_MaxCutsPerChop;
        Tuners.SeparationCm = constants_foodboard_net_autotest::k_SeparationCm;
        auto PileNode = utils_scene_node::Create(InRoot, FTransform::Identity).As_Transform();
        utils_foodboard::Add(Handle, FMars_FoodBoard_Spec(Tuners, PileNode));
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetFoodBoard : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    protected FCk_Handle_FoodBoard _Board;
    private bool _WasFound = false;

    // In order: every board signal this machine's copy raised, and the values of each kind in their own order.
    protected TArray<EMars_TESTONLY_NetBoardEvent> _Events;
    protected TArray<FMars_FoodBoard_CutIssue> _CutIssues;
    protected TArray<float32> _Turns;
    protected TArray<EMars_FoodBoard_ReleaseRefusal> _ReleaseRefusals;
    protected TArray<int32> _HeldCounts;
    // In parallel with _Events: the frame of this machine's test in which each was raised.
    protected TArray<int32> _EventFrames;
    // Frames this machine's test has run, counted from Begin_BoardRig.
    protected int32 _Frame = 0;
    // The frame this machine first found its copy, and the ledger it read then.
    protected int32 _FoundFrame = -1;
    protected FMars_Fragment_FoodBoard_Net _FoundLedger;

    private int32 _AwaitedAnswers = 0;
    private int32 _AwaitedTurns = 0;
    private int32 _QuietFrameCount = 0;
    private FName _QuietContinuation;
    private FName _HeldContinuation;
    private int32 _AwaitedStep = 0;
    private FName _StepContinuation;

    // The subject as the station's operator (Begin_OperatorRig).
    protected FCk_Handle_InputIntents _Intents;
    private bool _IsRecordingChops = false;
    private FName _SeatedContinuation;
    private int32 _DropSerial = constants_foodboard_net_autotest::k_SeedSerial;
    private int32 _SweepSerial = constants_foodboard_net_autotest::k_SeedSerial;

    // Call first, on both machines.
    protected void Begin_BoardRig(FCk_Handle InTestEntity, float64 InX)
    {
        Begin_Rig(InX);
        Add_BoardReport();
        utils_timer::Create_Tick(InTestEntity, FCk_Delegate_Timer(this, n"OnBoardRigFrame"));
    }

    UFUNCTION()
    private void OnBoardRigFrame(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        ++_Frame;
    }

    private void Record(EMars_TESTONLY_NetBoardEvent InEvent)
    {
        _Events.Add(InEvent);
        _EventFrames.Add(_Frame);
    }

    // Forgets everything this machine's copy raised so far: a test that starts listening late counts from here.
    protected void Clear_BoardRecord()
    {
        _Events.Empty();
        _EventFrames.Empty();
        _CutIssues.Empty();
        _Turns.Empty();
        _ReleaseRefusals.Empty();
        _HeldCounts.Empty();
    }

    protected void Log_BoardResult(FString InText)
    {
        const auto Machine = Get_MachineName();
        const auto Ensures = Get_EnsureDelta();
        const auto TestName = GetClass().GetName();
        Log(f"[FoodBoardNetTest] {TestName} {Machine}: {InText} events=[{Describe_Events()}] found@{_FoundFrame} ({Describe_Ledger(_FoundLedger)}) ensures={Ensures}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The station (either machine)
    //----------------------------------------------------------------------------------------------------------------------

    // Server: the test board station at the floor's top, under the spawn owner.
    protected void Spawn_ServerBoardStation()
    {
        auto Spec = FMars_Station_Spec();
        Spec.MinigameStateClass = UMars_TESTONLY_SmState_NetCutting_Idle;
        Spec.InputStance = EMars_Station_InputStance::Authority;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Params = FMars_TESTONLY_StationSpawnParams(FTransform(FRotator::ZeroRotator, _FloorTop), Spec);
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetBoardStation_EntityScript, Params);
    }

    // This machine's board station has composed; the first time, its signals are recorded from here (and the server tracks
    // it).
    protected bool Get_IsBoardStationFound()
    {
        // Once found, a station the server's cleanup destroyed is never found again.
        if (_WasFound)
        { return ck::IsValid(_Board); }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetBoardStation"))
        {
            auto Board = Candidate.As_FoodBoard(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Board))
            { continue; }

            _WasFound = true;
            _Board = Board;
            _FoundFrame = _Frame;
            _FoundLedger = Board.Get_Ledger();
            _Board.BindTo_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnRigCutIssued"));
            _Board.BindTo_OnTurned(FMars_Delegate_FoodBoard_OnTurned(this, n"OnRigTurned"));
            _Board.BindTo_OnReleaseRefused(FMars_Delegate_FoodBoard_OnReleaseRefused(this, n"OnRigReleaseRefused"));
            _Board.BindTo_OnHeldCountChanged(FMars_Delegate_FoodBoard_OnHeldCountChanged(this, n"OnRigHeldCountChanged"));
            if (_IsRecordingChops)
            {
                auto Cutting = Get_Cutting();
                Cutting.BindTo_OnChopStarted(FMars_Delegate_Cutting_OnChopStarted(this, n"OnRigChopStarted"));
                Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnRigChopLanded"));
            }

            if (Get_IsServer())
            {
                _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnRigPlaced"));
                _Board.BindTo_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnRigPieceCut"));
                _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnRigReleased"));
                Track_ForCleanup(Candidate);
            }

            return true;
        }

        return false;
    }

    protected FVector Get_StationRootLocation()
    {
        return Get_RootLocation(_Board);
    }

    // A vertical world plane through InPoint with the horizontal InNormal; the tangent is the world up crossed with it.
    protected FMars_FoodPiece_WorldPlane Make_VerticalPlane(FVector InPoint, FVector InNormal)
    {
        const auto Normal = InNormal.GetSafeNormal();
        return FMars_FoodPiece_WorldPlane(InPoint, Normal, FVector::UpVector.CrossProduct(Normal).GetSafeNormal());
    }

    // A vertical plane through the station root's location.
    protected FMars_FoodPiece_WorldPlane Make_PlaneThroughRoot(FVector InNormal)
    {
        return Make_VerticalPlane(Get_StationRootLocation(), InNormal);
    }

    // The world centre of InPiece's bounds at its pose.
    protected FVector Get_WorldBoundsCenter(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        const auto Metrics = utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
        const auto World = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        return World.TransformPosition((Metrics.Get_BoundsMinCm() + Metrics.Get_BoundsMaxCm()) * 0.5);
    }

    protected float64 Get_RootYaw(FCk_Handle InEntity)
    {
        return utils_transform::Get_EntityCurrentTransform(InEntity.As_Transform()).Rotator().Yaw;
    }

    // The board's events of InKinds, in order.
    protected TArray<EMars_TESTONLY_NetBoardEvent> Get_EventsOf(TArray<EMars_TESTONLY_NetBoardEvent> InKinds)
    {
        TArray<EMars_TESTONLY_NetBoardEvent> Events;
        for (const auto Event : _Events)
        {
            if (InKinds.Contains(Event))
            { Events.Add(Event); }
        }

        return Events;
    }

    protected FString Describe_Events() const
    {
        auto Text = "";
        for (int32 Index = 0; Index < _Events.Num(); ++Index)
        { Text += f"{_Events[Index] :n}@{_EventFrames[Index]} "; }

        return Text;
    }

    protected FString Describe_HeldCounts() const
    {
        auto Text = "";
        for (const auto Count : _HeldCounts)
        { Text += f"{Count} "; }

        return Text;
    }

    protected FString Describe_Ledger(FMars_Fragment_FoodBoard_Net InLedger) const
    {
        return f"held={InLedger.HeldCount} occupancy={InLedger.Occupancy} cuts={InLedger.CutSerial} turns={InLedger.TurnSerial} refusals={InLedger.ReleaseRefusalSerial}";
    }

    protected FString Describe_Issue(FMars_FoodBoard_CutIssue InIssue) const
    {
        return f"S{InIssue.Straddling}/B{InIssue.Budget}/I{InIssue.Issued}";
    }

    protected FString Describe_Issues() const
    {
        auto Text = "";
        for (const auto& Issue : _CutIssues)
        { Text += f"{Describe_Issue(Issue)} "; }

        return Text;
    }

    protected FString Describe_Refusals() const
    {
        auto Text = "";
        for (const auto Refusal : _ReleaseRefusals)
        { Text += f"{Refusal :n} "; }

        return Text;
    }

    protected bool Get_IsIssue(FMars_FoodBoard_CutIssue InIssue, int32 InStraddling, int32 InBudget, int32 InIssued)
    {
        return InIssue.Straddling == InStraddling && InIssue.Budget == InBudget && InIssue.Issued == InIssued;
    }

    protected bool Get_IsLedgerEqual(FMars_Fragment_FoodBoard_Net InA, FMars_Fragment_FoodBoard_Net InB)
    {
        return InA.HeldCount == InB.HeldCount && InA.Occupancy == InB.Occupancy && InA.CutSerial == InB.CutSerial
            && InA.TurnSerial == InB.TurnSerial && InA.ReleaseRefusalSerial == InB.ReleaseRefusalSerial;
    }

    // Exactly InCounts, in order.
    protected bool Get_AreHeldCounts(TArray<int32> InCounts)
    {
        if (_HeldCounts.Num() != InCounts.Num())
        { return false; }

        for (int32 Index = 0; Index < InCounts.Num(); ++Index)
        {
            if (_HeldCounts[Index] != InCounts[Index])
            { return false; }
        }

        return true;
    }

    protected int32 Get_EventCount(EMars_TESTONLY_NetBoardEvent InKind)
    {
        auto Count = 0;
        for (const auto Event : _Events)
        {
            if (Event == InKind)
            { ++Count; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    // Lays the floor, waits for the spawn owner, spawns the station and the slab, and calls On_ServerBoardReady once the
    // station is found and the slab is Ready, at rest and Kinematic, and the client had a beat to bind.
    protected void Begin_ServerBoardWithSlab(FCk_Handle InTestEntity)
    {
        Begin_ServerFloor(InTestEntity);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnBoardRigOwnerWithSlab", k_SlowPolls);
    }

    // Waits for the spawn owner, spawns the station, and calls On_ServerBoardReady once it is found and the client had a
    // beat to bind.
    protected void Begin_ServerBoardOnly(FCk_Handle InTestEntity)
    {
        Begin_ServerFloor(InTestEntity);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnBoardRigOwnerOnly", k_SlowPolls);
    }

    protected void On_ServerBoardReady() {}

    UFUNCTION()
    private void OnBoardRigOwnerWithSlab(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBoardStation();
        Spawn_ServerSlab();
        WaitUntil(n"Is_BoardRigSlabPlaceable", n"OnBoardRigFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnBoardRigOwnerOnly(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBoardStation();
        WaitUntil(n"Is_BoardRigStationFound", n"OnBoardRigFound", k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_BoardRigStationFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBoardStationFound());
    }

    // The still count advances once a frame whatever else reads false.
    UFUNCTION()
    private void Is_BoardRigSlabPlaceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsStill = Tick_SlabReadyAndStill();
        const auto IsFound = Get_IsBoardStationFound();
        auto Result = OutResult;
        Result.Set(IsStill && IsFound && Ask_SlabKinematic());
    }

    UFUNCTION()
    private void OnBoardRigFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(constants_foodboard_net_autotest::k_ClientBindSeconds, n"OnBoardRigReady");
    }

    UFUNCTION()
    private void OnBoardRigReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerBoardReady();
    }

    // The SetMotionType handler drops a request that reaches a body not added yet: ask until the mirror reads it.
    protected bool Ask_SlabKinematic()
    {
        auto Body = _Rock.As_JoltBody();
        if (utils_jolt_body::Get_IsBodyAdded(Body) == false)
        { return false; }

        if (utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Kinematic)
        { return true; }

        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        return false;
    }

    protected ECk_MotionType Get_SlabMotionType()
    {
        return utils_jolt_body::Get_MotionType(_Rock.As_JoltBody());
    }

    protected void Place_Slab()
    {
        _Board.Request_Place(FMars_Request_FoodBoard_Place(_Rock.As_FoodPiece()));
    }

    // Places the slab and calls InContinuation once the board holds it.
    protected void Place_SlabThen(FName InContinuation)
    {
        Place_Slab();
        _HeldContinuation = InContinuation;
        WaitUntil(n"Is_BoardRigHoldsOne", n"OnBoardRigHoldsOne", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_BoardRigHoldsOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Board.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void OnBoardRigHoldsOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _HeldContinuation);
    }

    // Calls InContinuation once the board answered InAnswers cuts and InTurns turns in all and has been quiet (no held
    // piece with a board cut pending) for k_QuietFrames frames in a row.
    protected void Await_ServerQuiet(int32 InAnswers, int32 InTurns, FName InContinuation)
    {
        _AwaitedAnswers = InAnswers;
        _AwaitedTurns = InTurns;
        _QuietFrameCount = 0;
        _QuietContinuation = InContinuation;
        WaitUntil(n"Is_BoardRigQuiet", n"OnBoardRigQuiet", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_BoardRigQuiet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto IsQuiet = _CutIssues.Num() >= _AwaitedAnswers && _Turns.Num() >= _AwaitedTurns;
        for (const auto& Piece : _Board.Get_Held())
        {
            if (Piece.Get_HasBoardCutPending())
            { IsQuiet = false; }
        }

        _QuietFrameCount = IsQuiet ? _QuietFrameCount + 1 : 0;
        auto Result = OutResult;
        Result.Set(_QuietFrameCount >= constants_foodboard_net_autotest::k_QuietFrames);
    }

    UFUNCTION()
    private void OnBoardRigQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _QuietContinuation);
    }

    // Publishes the held pieces' ids and root poses as step InStep.
    protected void Publish_BoardReport(int32 InStep)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetFoodBoardReport);
        Report.Serial += 1;
        Report.Step = InStep;
        Report.Ids.Empty();
        Report.Locations.Empty();
        Report.Yaws.Empty();
        for (const auto& Piece : _Board.Get_Held())
        {
            Report.Ids.Add(Piece.Get_Id());
            Report.Locations.Add(Get_RootLocation(Piece));
            Report.Yaws.Add(Get_RootYaw(Piece));
        }

        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetFoodBoardReport);
    }

    // The server's last step: it holds while the client asserts, then ends clean.
    protected void End_ServerAfterReport()
    {
        WaitSeconds(constants_foodboard_net_autotest::k_ReportHoldSeconds, n"OnBoardRigReportHeld");
    }

    UFUNCTION()
    private void OnBoardRigReportHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Report
    //----------------------------------------------------------------------------------------------------------------------

    protected void Add_BoardReport()
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetFoodBoardReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetFoodBoardReport(), ECk_Replication::Replicates); }
    }

    protected FMars_Fragment_TESTONLY_NetFoodBoardReport Get_BoardReport()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetFoodBoardReport);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // Finds and binds this machine's copy every frame until it composes, and calls InContinuation once report step InStep
    // has arrived and k_ClientSettleSeconds more have passed.
    protected void Await_ClientStep(int32 InStep, FName InContinuation)
    {
        _AwaitedStep = InStep;
        _StepContinuation = InContinuation;
        WaitUntil(n"Is_BoardRigStepArrived", n"OnBoardRigStepArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_BoardRigStepArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsFound = Get_IsBoardStationFound();
        auto Result = OutResult;
        Result.Set(IsFound && Get_BoardReport().Step >= _AwaitedStep);
    }

    UFUNCTION()
    private void OnBoardRigStepArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(constants_foodboard_net_autotest::k_ClientSettleSeconds, _StepContinuation);
    }

    // Every reported id against the standing piece with that id near the test's X.
    protected FMars_TESTONLY_NetBoardPoseCheck Check_AtReport()
    {
        const auto Report = Get_BoardReport();
        const auto Standing = Get_StandingNear(_FloorTop);
        auto Check = FMars_TESTONLY_NetBoardPoseCheck();
        Check.Reported = Report.Ids.Num();
        for (int32 Index = 0; Index < Report.Ids.Num(); ++Index)
        {
            const auto Piece = Find_ById(Standing, Report.Ids[Index]);
            if (ck::Is_NOT_Valid(Piece))
            { continue; }

            ++Check.Found;
            const auto ErrorCm = (Get_RootLocation(Piece) - Report.Locations[Index]).Size();
            const auto ErrorDegrees = Math::Abs(Math::FindDeltaAngleDegrees(Get_RootYaw(Piece), Report.Yaws[Index]));
            Check.WorstCm = Math::Max(Check.WorstCm, ErrorCm);
            Check.WorstDegrees = Math::Max(Check.WorstDegrees, ErrorDegrees);
        }

        return Check;
    }

    protected bool Get_IsAtReport(FMars_TESTONLY_NetBoardPoseCheck InCheck)
    {
        return InCheck.Reported > 0 && InCheck.Found == InCheck.Reported
            && InCheck.WorstCm <= constants_foodboard_net_autotest::k_ReportToleranceCm
            && InCheck.WorstDegrees <= constants_foodboard_net_autotest::k_ReportToleranceDegrees;
    }

    protected FString Describe_Check(FMars_TESTONLY_NetBoardPoseCheck InCheck) const
    {
        return f"found {InCheck.Found}/{InCheck.Reported} worst {InCheck.WorstCm} cm {InCheck.WorstDegrees} deg";
    }

    // Every standing piece's replicated holder is this machine's board.
    protected bool Get_AreStandingHeldByBoard()
    {
        FCk_Handle BoardEntity = _Board;
        const auto Standing = Get_StandingNear(_FloorTop);
        for (const auto& Piece : Standing)
        {
            if (Piece.TryGet_ReplicatedHolder() != BoardEntity)
            { return false; }
        }

        return Standing.Num() > 0;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The operator (either machine)
    //----------------------------------------------------------------------------------------------------------------------

    // Both machines, first thing (after Begin_BoardRig): the subject's Operator feature and its InputIntents (reused when an
    // earlier test of this session composed it), and the cleaver's starts and landings recorded beside the board's
    // signals. The server clears any remote state an earlier test left behind.
    protected void Begin_OperatorRig()
    {
        auto Subject = Get_SubjectEntity();
        utils_operator::Add(Subject);
        _Intents = Subject.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { _Intents = utils_input_intents::Add(Subject); }

        _IsRecordingChops = true;
        if (Get_IsServer())
        { _Intents.Request_ClearRemote(FMars_Request_InputIntents_ClearRemote()); }
    }

    protected FCk_Handle_Station Get_Station()
    {
        return _Board.H().As_Station();
    }

    protected FCk_Handle_Cutting Get_Cutting()
    {
        return _Board.H().As_Cutting();
    }

    protected bool Get_IsSubjectOperating()
    {
        return Get_IsBoardStationFound() && Get_Station().Get_IsOperatedBy(Get_SubjectEntity());
    }

    // This machine's whole food near the test's X as a world item; invalid while there is none.
    protected FCk_Handle_WorldItem Find_WholeFood()
    {
        return Find_WorldItemNear(_FloorTop);
    }

    // Exactly one cleaver start, then one landing.
    protected bool Get_IsOneChop()
    {
        TArray<EMars_TESTONLY_NetBoardEvent> Kinds;
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::ChopStarted);
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::ChopLanded);
        const auto Chops = Get_EventsOf(Kinds);
        return Chops.Num() == 2 && Chops[0] == EMars_TESTONLY_NetBoardEvent::ChopStarted && Chops[1] == EMars_TESTONLY_NetBoardEvent::ChopLanded;
    }

    // Exactly one answer, and it issued InIssued cuts.
    protected bool Get_IsOneAnswer(int32 InIssued)
    {
        return _CutIssues.Num() == 1 && _CutIssues[0].Issued == InIssued;
    }

    // Server: seats the subject and calls InContinuation once the station reads it operating.
    protected void Seat_SubjectThen(FName InContinuation)
    {
        auto Station = Get_Station();
        Station.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        _SeatedContinuation = InContinuation;
        WaitUntil(n"Is_BoardRigSubjectOperating", n"OnBoardRigSubjectOperating", k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_BoardRigSubjectOperating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSubjectOperating());
    }

    UFUNCTION()
    private void OnBoardRigSubjectOperating(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _SeatedContinuation);
    }

    // Server: the seed, a first remote sample carrying the turn and sweep rows at k_SeedSerial, released; then
    // InContinuation k_SeedFrames frames later.
    protected void Seed_RemoteThen(FName InContinuation)
    {
        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.Intents.Add(FMars_InputIntents_RemoteIntent(GameplayTags::Mars_Intent_Drop, _DropSerial, EMars_InputIntents_Hold::Released));
        Sample.Intents.Add(FMars_InputIntents_RemoteIntent(GameplayTags::Mars_Intent_Interact_Secondary, _SweepSerial, EMars_InputIntents_Hold::Released));
        _Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
        WaitFrames(constants_foodboard_net_autotest::k_SeedFrames, InContinuation);
    }

    // Server: a remote turn press, the Drop row at its next serial, released.
    protected void Press_RemoteTurn()
    {
        _DropSerial += 1;
        Apply_RemotePress(GameplayTags::Mars_Intent_Drop, _DropSerial);
    }

    // Server: a remote sweep press, the Interact_Secondary row at its next serial, released.
    protected void Press_RemoteSweep()
    {
        _SweepSerial += 1;
        Apply_RemotePress(GameplayTags::Mars_Intent_Interact_Secondary, _SweepSerial);
    }

    private void Apply_RemotePress(FGameplayTag InRow, int32 InSerial)
    {
        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.Intents.Add(FMars_InputIntents_RemoteIntent(InRow, InSerial, EMars_InputIntents_Hold::Released));
        _Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRigCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue)
    {
        Record(EMars_TESTONLY_NetBoardEvent::CutIssued);
        _CutIssues.Add(InIssue);
    }

    UFUNCTION()
    private void OnRigTurned(FCk_Handle_FoodBoard InBoard, float32 InYawDegrees)
    {
        Record(EMars_TESTONLY_NetBoardEvent::Turned);
        _Turns.Add(InYawDegrees);
    }

    UFUNCTION()
    private void OnRigReleaseRefused(FCk_Handle_FoodBoard InBoard, EMars_FoodBoard_ReleaseRefusal InRefusal)
    {
        Record(EMars_TESTONLY_NetBoardEvent::ReleaseRefused);
        _ReleaseRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigHeldCountChanged(FCk_Handle_FoodBoard InBoard, int32 InHeldCount)
    {
        Record(EMars_TESTONLY_NetBoardEvent::HeldCountChanged);
        _HeldCounts.Add(InHeldCount);
    }

    UFUNCTION()
    private void OnRigPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        Record(EMars_TESTONLY_NetBoardEvent::Placed);
    }

    // The halves are tracked: a cut half is a replicated piece script outside the test's lifetime subtree.
    UFUNCTION()
    private void OnRigPieceCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative)
    {
        Record(EMars_TESTONLY_NetBoardEvent::PieceCut);
        Track_ForCleanup(InPositive);
        Track_ForCleanup(InNegative);
    }

    UFUNCTION()
    private void OnRigReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        Record(EMars_TESTONLY_NetBoardEvent::Released);
    }

    UFUNCTION()
    private void OnRigChopStarted(FCk_Handle_Cutting InCutting)
    {
        Record(EMars_TESTONLY_NetBoardEvent::ChopStarted);
    }

    UFUNCTION()
    private void OnRigChopLanded(FCk_Handle_Cutting InCutting)
    {
        Record(EMars_TESTONLY_NetBoardEvent::ChopLanded);
    }
}
