// The real feed stations' net tests' shared steps, on the dock net rig (its platter, its report, its docks). The server
// spawns the real cutting station (or the real searing station) under the replicated spawn owner beside the platter, with
// the station's own feed timing or a slow one (0.6 s for each timed phase). Each machine finds its own copy as the dock
// rig does, then its feed, its board and its cleaver, and records in order the feed's OnPhaseChanged, OnStockChanged,
// OnTransferRefused and OnPieceLetGo and the board's OnHeldCountChanged; the server also its settles. Every frame it
// samples the label, the add-food row (the subject's visible hint under owner key StationFeed on the add-food action),
// whether the hand node is at rest and which piece rides it. Both machines make the subject an operator (the Operator
// feature, an InputIntents and a hint display); the server seats it, seeds its remote state with the add-food and the
// secondary rows and applies each remote press as one remote sample. What the client compares against goes out in one
// test-only replicated report on the subject (and, at the same step, the platter rig's). One [FeedStationNetTest] line per
// test per machine; ensures are 0 on both. The server destroys its station when it ends, and the client waits until its
// copy is gone.

namespace constants_feed_station_net_autotest
{
    const float32 k_SlowPhaseSeconds = 0.6f;
    // The remote state the server seeds: every row released at this serial, applied before the first press.
    const int32 k_SeedSerial = 7;
    // Frames the seed has to drain before the first press.
    const int32 k_SeedFrames = 10;
    // A board with no cut pending for this many frames in a row is quiet.
    const int32 k_QuietFrames = 5;
    const float64 k_PoseToleranceCm = 1.0;
    const float64 k_HandRestToleranceCm = 0.01;
}

enum EMars_TESTONLY_RealFeedStationKind
{
    Cutting,
    Searing
}

enum EMars_TESTONLY_NetFeedStationTiming
{
    Station,
    Slow
}

enum EMars_TESTONLY_NetFeedStationSignal
{
    PhaseChanged,
    StockChanged,
    TransferRefused,
    PieceLetGo,
    BoardHeldCountChanged
}

// Where the server found the reported piece.
enum EMars_TESTONLY_NetFeedStationWhere
{
    Unknown,
    OnPlatter,
    OnBoard,
    InStation
}

// One text this machine sampled, and the report's step it read on that frame.
struct FMars_TESTONLY_NetFeedStationSeen
{
    int32 Step = 0;
    FString Text;
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only: a feature's processors are
// the only writers in game code).
struct FMars_Fragment_TESTONLY_NetFeedStationReport
{
    UPROPERTY()
    int32 Serial = 0;

    UPROPERTY()
    int32 Step = 0;

    // The piece the test follows (the joint).
    UPROPERTY()
    FGuid PieceId;

    UPROPERTY()
    EMars_TESTONLY_NetFeedStationWhere Where = EMars_TESTONLY_NetFeedStationWhere::Unknown;

    UPROPERTY()
    int32 Available = 0;

    UPROPERTY()
    int32 Admitted = 0;

    // The frame counter of the server's last remote add-food press.
    UPROPERTY()
    int32 PressFrame = -1;

    // The board's held pieces and their root poses; empty without a board.
    UPROPERTY()
    TArray<FGuid> BoardIds;

    UPROPERTY()
    TArray<FTransform> BoardPoses;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetFeedStation : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    protected EMars_TESTONLY_RealFeedStationKind _FeedStationKind = EMars_TESTONLY_RealFeedStationKind::Cutting;
    protected EMars_TESTONLY_NetFeedStationTiming _FeedTiming = EMars_TESTONLY_NetFeedStationTiming::Station;

    // This machine's copy of the station's feed, board, cleaver and the feed's hand node, once found.
    protected FCk_Handle_CookingFeed _Feed;
    protected FCk_Handle_FoodBoard _Board;
    protected FCk_Handle_Cutting _Cutting;
    protected FCk_Handle_Transform _FeedHand;

    // Every signal this machine's copy raised since it was found (or since Clear_FeedRecord), in order.
    protected TArray<EMars_TESTONLY_NetFeedStationSignal> _Signals;
    protected TArray<EMars_CookingFeed_Phase> _Phases;
    // The frame counter of each phase change, in parallel.
    protected TArray<int64> _PhaseFrames;
    protected TArray<EMars_CookingFeed_Refusal> _Refusals;
    protected TArray<int32> _BoardCounts;
    protected int32 _LetGo = 0;
    // Server only.
    protected TArray<EMars_CookingFeed_Settle> _Settles;

    // The sampler's records: each label and row text when it changed, with the step read then; per piece id, the sampled
    // frames it was a child of this machine's hand node; whether the hand left its rest since the last clear.
    protected TArray<FMars_TESTONLY_NetFeedStationSeen> _LabelsSeen;
    protected TArray<FMars_TESTONLY_NetFeedStationSeen> _RowsSeen;
    protected TArray<FGuid> _UnderHandIds;
    protected TArray<int32> _UnderHandFrames;
    protected bool _HandLeftRest = false;

    // The operator.
    protected FCk_Handle_InputIntents _Intents;
    protected FCk_Handle_ActionHintDisplay _Display;
    // Server: the frame counter of its last remote add-food press.
    protected int64 _PressFrame = -1;

    // The server's spawn of the station.
    protected FCk_Handle _FeedStationEntity;
    // Seconds since the test began on this machine, by name, for the report.
    protected FString _Times;

    private bool _WasFeedStationFound = false;
    private int32 _AddFoodSerial = constants_feed_station_net_autotest::k_SeedSerial;
    private int32 _SweepSerial = constants_feed_station_net_autotest::k_SeedSerial;
    private FName _SeatedContinuation;
    private FName _SourcedContinuation;
    private FName _IdleContinuation;
    private int32 _AwaitedAvailable = 0;
    private float64 _BeginSeconds = 0.0;
    private FString _LastLabel = "<unset>";
    private FString _LastRow = "<unset>";
    private int32 _LastSampledStep = -1;
    private FString _FeedStationEndText;

    // Call first, on both machines.
    protected void Begin_FeedStationRig(FCk_Handle InTestEntity, float64 InX)
    {
        _StationKind = EMars_TESTONLY_NetDockStationKind::CuttingStation;
        _BeginSeconds = System::GetGameTimeInSeconds();
        Begin_PlatterRig(InTestEntity, InX);
        Add_FeedStationReport();
        Begin_Operator();
        Begin_Sampling(InTestEntity);
    }

    protected void Log_FeedStation(FString InText)
    {
        const auto Machine = Get_MachineName();
        const auto TestName = GetClass().GetName();
        const auto Ensures = Get_EnsureDelta();
        Log(f"[FeedStationNetTest] {TestName} {Machine}: {InText} times=[{_Times}] ensures={Ensures}");
    }

    // Seconds since the test began on this machine, under InName.
    protected void Mark_Time(FString InName)
    {
        const auto Seconds = System::GetGameTimeInSeconds() - _BeginSeconds;
        _Times += f"{InName}={Seconds} ";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Report
    //----------------------------------------------------------------------------------------------------------------------

    protected void Add_FeedStationReport()
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetFeedStationReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetFeedStationReport(), ECk_Replication::Replicates); }
    }

    protected FMars_Fragment_TESTONLY_NetFeedStationReport Get_FeedStationReport()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetFeedStationReport);
    }

    // Server: step InStep with InPiece as the followed piece, where it is, the feed's stock, the last press and the board's
    // pieces; the platter rig's report carries the same step with no rides.
    protected void Report_Step(int32 InStep, FCk_Handle_FoodPiece InPiece)
    {
        Publish_Location(InStep, FVector::ZeroVector);
        Write_FeedStationReport(InStep, InPiece);
    }

    // Server: as Report_Step, with the platter's frozen pieces as the platter rig's rides.
    protected void Report_StepWithRides(int32 InStep, FCk_Handle_FoodPiece InPiece)
    {
        Publish_Rides(InStep);
        Write_FeedStationReport(InStep, InPiece);
    }

    // Server: as Report_Step, with InPlatter's frozen pieces (at most k_SlotCount) as the platter rig's rides.
    protected void Report_StepWithRidesOf(int32 InStep, FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        auto Report = Get_PlatterReport();
        Report.Step = InStep;
        const auto Held = InPlatter.Get_Held();
        Report.Count = Math::Min(Held.Num(), k_SlotCount);
        for (int32 Index = 0; Index < Report.Count; ++Index)
        { Set_Slot(Report, Index, Make_Slot(Held[Index], Get_Offset(Held[Index]))); }

        Write_PlatterReport(Report);
        Write_FeedStationReport(InStep, InPiece);
    }

    private void Write_FeedStationReport(int32 InStep, FCk_Handle_FoodPiece InPiece)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetFeedStationReport);
        Report.Serial += 1;
        Report.Step = InStep;
        Report.PieceId = ck::IsValid(InPiece) ? InPiece.Get_Id() : FGuid();
        Report.Where = Get_Where(InPiece);
        Report.Available = _Feed.Get_Available();
        Report.Admitted = _Feed.Get_Admitted();
        Report.PressFrame = int32(_PressFrame);
        Report.BoardIds.Empty();
        Report.BoardPoses.Empty();
        if (ck::IsValid(_Board))
        {
            for (const auto& Piece : _Board.Get_Held())
            {
                Report.BoardIds.Add(Piece.Get_Id());
                Report.BoardPoses.Add(Get_RootWorld(Piece));
            }
        }

        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetFeedStationReport);
    }

    // Where the server finds InPiece: frozen on its platter, on its board, or held anywhere else (the station's kernel).
    protected EMars_TESTONLY_NetFeedStationWhere Get_Where(FCk_Handle_FoodPiece InPiece)
    {
        if (Get_IsLive(InPiece) == false)
        { return EMars_TESTONLY_NetFeedStationWhere::Unknown; }

        if (Try_FindPlatter() && _Platter.Get_Held().Contains(InPiece))
        { return EMars_TESTONLY_NetFeedStationWhere::OnPlatter; }

        if (ck::IsValid(_Board) && _Board.Get_Held().Contains(InPiece))
        { return EMars_TESTONLY_NetFeedStationWhere::OnBoard; }

        return EMars_TESTONLY_NetFeedStationWhere::InStation;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Either machine
    //----------------------------------------------------------------------------------------------------------------------

    // Finds this machine's station once its docks and its feed have composed (and, at the cutting station, its board and
    // cleaver), and records their signals from then on.
    protected bool Try_FindFeedStation()
    {
        if (_WasFeedStationFound)
        { return ck::IsValid(_Feed); }

        if (Try_FindDocks() == false || _Station.Is_CookingFeed() == false)
        { return false; }

        const auto IsCutting = _FeedStationKind == EMars_TESTONLY_RealFeedStationKind::Cutting;
        if (IsCutting && (_Station.Is_FoodBoard() == false || _Station.Is_Cutting() == false))
        { return false; }

        _WasFeedStationFound = true;
        _Feed = _Station.As_CookingFeed();
        _FeedHand = _Feed.Get_HandNode();
        _Feed.BindTo_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnRigPhaseChanged"));
        _Feed.BindTo_OnStockChanged(FMars_Delegate_CookingFeed_OnStockChanged(this, n"OnRigStockChanged"));
        _Feed.BindTo_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnRigTransferRefused"));
        _Feed.BindTo_OnPieceLetGo(FMars_Delegate_CookingFeed_OnPieceLetGo(this, n"OnRigPieceLetGo"));
        if (Get_IsServer())
        { _Feed.BindTo_OnTransferSettled(FMars_Delegate_CookingFeed_OnTransferSettled(this, n"OnRigTransferSettled")); }

        if (IsCutting)
        {
            _Board = _Station.As_FoodBoard();
            _Cutting = _Station.As_Cutting();
            _Board.BindTo_OnHeldCountChanged(FMars_Delegate_FoodBoard_OnHeldCountChanged(this, n"OnRigBoardHeldCountChanged"));
        }

        return true;
    }

    // The client steps only once it has its feed station and both reports reached InStep.
    protected bool Get_IsStepArrived(int32 InStep) override
    {
        return Try_FindFeedStation() && Get_FeedStationReport().Step >= InStep && Super::Get_IsStepArrived(InStep);
    }

    // What this copy raised before is not counted from here on.
    protected void Clear_FeedRecord()
    {
        _Signals.Empty();
        _Phases.Empty();
        _PhaseFrames.Empty();
        _Refusals.Empty();
        _BoardCounts.Empty();
        _LetGo = 0;
        _Settles.Empty();
        _HandLeftRest = false;
    }

    protected int32 Get_FeedSignalCount(EMars_TESTONLY_NetFeedStationSignal InSignal)
    {
        auto Count = 0;
        for (const auto Signal : _Signals)
        {
            if (Signal == InSignal)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_PhaseCount(EMars_CookingFeed_Phase InPhase)
    {
        auto Count = 0;
        for (const auto Phase : _Phases)
        {
            if (Phase == InPhase)
            { ++Count; }
        }

        return Count;
    }

    // At least one phase raised, Reach first and Idle last.
    protected bool Get_IsReachFirstAndIdleLast()
    {
        return _Phases.Num() >= 2 && _Phases[0] == EMars_CookingFeed_Phase::Reach && _Phases.Last() == EMars_CookingFeed_Phase::Idle;
    }

    protected int32 Get_RefusalCount(EMars_CookingFeed_Refusal InRefusal)
    {
        auto Count = 0;
        for (const auto Refusal : _Refusals)
        {
            if (Refusal == InRefusal)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_SettleCount(EMars_CookingFeed_Settle InSettle)
    {
        auto Count = 0;
        for (const auto Settle : _Settles)
        {
            if (Settle == InSettle)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_Record()
    {
        FString Phases = "";
        for (int32 Index = 0; Index < _Phases.Num(); ++Index)
        { Phases += f"{_Phases[Index] :n}@{_PhaseFrames[Index]} "; }

        FString Refusals = "";
        for (const auto Refusal : _Refusals)
        { Refusals += f"{Refusal :n} "; }

        FString Settles = "";
        for (const auto Settle : _Settles)
        { Settles += f"{Settle :n} "; }

        FString Counts = "";
        for (const auto Count : _BoardCounts)
        { Counts += f"{Count} "; }

        return f"phases=[{Phases}] refusals=[{Refusals}] settles=[{Settles}] letGo={_LetGo} boardCounts=[{Counts}]";
    }

    protected FString Describe_Feed()
    {
        if (ck::Is_NOT_Valid(_Feed))
        { return "feed=[none]"; }

        const auto Board = ck::IsValid(_Board) ? _Board.Get_HeldCount() : -1;
        return f"feed=[{_Feed.Get_Phase() :n} available={_Feed.Get_Available()} admitted={_Feed.Get_Admitted()}] board={Board}";
    }

    // The feed's ledger as this machine reads it.
    protected FString Describe_FeedLedger()
    {
        const auto Ledger = _Feed.Get_Ledger();
        return f"serial={Ledger.PhaseSerial} phase={Ledger.Phase :n} hold={Ledger.Hold :n} aim={Ledger.Aim :n} sourcing={Ledger.Sourcing :n} available={Ledger.Available} admitted={Ledger.Admitted} pile={Ledger.Pile :n} refusals={Ledger.RefusalSerial} last={Ledger.LastRefusal :n} letGo={Ledger.LetGoSerial}";
    }

    // The slow timing: 0.6 s for each timed phase, the admission budget as the spec's default.
    protected FMars_CookingFeed_TimingSpec Make_SlowTiming()
    {
        const auto Seconds = constants_feed_station_net_autotest::k_SlowPhaseSeconds;
        return FMars_CookingFeed_TimingSpec(Seconds, Seconds, Seconds, Seconds);
    }

    protected bool Get_IsSlowTiming(FMars_CookingFeed_TimingSpec InTiming)
    {
        const auto Slow = Make_SlowTiming();
        return InTiming.ReachSeconds == Slow.ReachSeconds && InTiming.GraspSeconds == Slow.GraspSeconds
            && InTiming.CarrySeconds == Slow.CarrySeconds && InTiming.ReturnSeconds == Slow.ReturnSeconds;
    }

    protected FString Describe_Timing(FMars_CookingFeed_TimingSpec InTiming)
    {
        return f"timing=[{InTiming.ReachSeconds} {InTiming.GraspSeconds} {InTiming.CarrySeconds} {InTiming.ReturnSeconds}]";
    }

    // The hand node's offset in the station's frame on this machine.
    protected FTransform Get_HandOffset()
    {
        FCk_Handle Entity = _FeedHand;
        return utils_scene_node::Get_Offset(Entity.As_SceneNode());
    }

    protected FTransform Get_HandRest()
    {
        return _Feed.Get_Spec().Hand.GetValue().RestLocal;
    }

    // The hand node is at rest as the feed compares a pose before it writes one: every component within
    // k_HandRestToleranceCm.
    protected bool Get_IsHandAtRest()
    {
        return Get_HandOffset().Equals(Get_HandRest(), constants_feed_station_net_autotest::k_HandRestToleranceCm);
    }

    protected FString Describe_HandRest()
    {
        const auto Cm = Get_HandOffset().GetLocation().Distance(Get_HandRest().GetLocation());
        return f"handOffRestCm={Cm} handLeftRest={_HandLeftRest}";
    }

    protected bool Get_IsUnderFeedHand(FCk_Handle_FoodPiece InPiece)
    {
        const auto Parent = Get_Parent(InPiece);
        return ck::IsValid(Parent) && ck::IsValid(_FeedHand) && Parent == _FeedHand;
    }

    // Sampled frames on which the piece with InId was a child of this machine's hand node.
    protected int32 Get_UnderHandFrames(FGuid InId)
    {
        for (int32 Index = 0; Index < _UnderHandIds.Num(); ++Index)
        {
            if (_UnderHandIds[Index] == InId)
            { return _UnderHandFrames[Index]; }
        }

        return 0;
    }

    protected FTransform Get_RootWorld(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    // The standing piece with InId whose replicated holder is this machine's board; invalid when there is none. The
    // board's held list is the authority's alone, so a client finds the piece by its id and its holder.
    protected FCk_Handle_FoodPiece Find_BoardPieceById(FGuid InId)
    {
        FCk_Handle BoardEntity = _Board;
        for (const auto& Piece : Get_StandingNear(_FloorTop))
        {
            if (Piece.Get_Id() == InId && Piece.TryGet_ReplicatedHolder() == BoardEntity)
            { return Piece; }
        }

        return FCk_Handle_FoodPiece();
    }

    // Empty when every piece of the report stands on this machine's board within k_PoseToleranceCm of its reported root;
    // otherwise the first fault.
    protected FString Get_BoardFault()
    {
        const auto Report = Get_FeedStationReport();
        if (_Board.Get_HeldCount() != Report.BoardIds.Num())
        { return f"board holds {_Board.Get_HeldCount()}, reported {Report.BoardIds.Num()}"; }

        for (int32 Index = 0; Index < Report.BoardIds.Num(); ++Index)
        {
            const auto Piece = Find_BoardPieceById(Report.BoardIds[Index]);
            if (Get_IsLive(Piece) == false)
            { return f"board piece {Index} is not on this board"; }

            const auto Cm = Get_RootWorld(Piece).GetLocation().Distance(Report.BoardPoses[Index].GetLocation());
            if (Cm > constants_feed_station_net_autotest::k_PoseToleranceCm)
            { return f"board piece {Index} off its reported root by {Cm} cm"; }
        }

        return "";
    }

    // Empty when every piece of the platter report's last step rides this machine's platter at its slot; otherwise the
    // first fault.
    protected FString Get_PileFault()
    {
        const auto Report = Get_PlatterReport();
        if (Try_FindPlatter() == false)
        { return "no platter"; }

        for (int32 Index = 0; Index < Report.Count; ++Index)
        {
            const auto Slot = Get_Slot(Report, Index);
            const auto Fault = Get_RideFault(Find_PieceById(Slot.Id), Slot);
            if (Fault.IsEmpty() == false)
            { return f"slot {Index}: {Fault}"; }
        }

        return "";
    }

    // Empty when InPiece rides InPlatter on this machine at InSlot: a Ready FoodPiece whose replicated holder is the
    // platter, whose scene-node parent is the platter's root, whose ride parent is the platter and whose offset under that
    // root is the slot's within k_RideToleranceCm and k_RideToleranceDegrees. Otherwise the first fault.
    protected FString Get_RideFaultOn(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, FMars_TESTONLY_NetPlatterSlot InSlot)
    {
        if (Get_IsLive(InPiece) == false)
        { return "no live piece"; }

        if (InPiece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { return f"status {InPiece.Get_Status() :n}"; }

        if (InPiece.TryGet_ReplicatedHolder() != InPlatter)
        { return f"replicated holder [{InPiece.TryGet_ReplicatedHolder().ToString()}] is not the platter"; }

        FCk_Handle PlatterEntity = InPlatter;
        const auto Parent = Get_Parent(InPiece);
        if (ck::Is_NOT_Valid(Parent) || Parent != PlatterEntity.As_Transform())
        { return f"scene-node parent [{Parent.ToString()}] is not the platter's root"; }

        if (InPiece.Get_RideParent() != InPlatter)
        { return f"ride parent [{InPiece.Get_RideParent().ToString()}] is not the platter"; }

        const auto Offset = Get_Offset(InPiece);
        const auto Expected = Get_SlotTransform(InSlot);
        const auto Cm = Offset.GetLocation().Distance(Expected.GetLocation());
        const auto Degrees = Get_AngleDegrees(Offset.GetRotation(), Expected.GetRotation());
        if (Cm > k_RideToleranceCm || Degrees > k_RideToleranceDegrees)
        { return f"offset off by {Cm} cm and {Degrees} deg"; }

        return "";
    }

    // Empty when InPlatter is Held by the subject on this machine's hand node at its held offset.
    protected FString Get_HeldOnHandFault(FCk_Handle_Platter InPlatter)
    {
        FCk_Handle Entity = InPlatter;
        auto WorldItem = Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(WorldItem))
        { return "no platter world item"; }

        if (WorldItem.Get_Mount() != EMars_WorldItem_Mount::Held || WorldItem.Get_Carrier() != Get_SubjectEntity())
        { return f"mount {WorldItem.Get_Mount() :n} by [{WorldItem.Get_Carrier().ToString()}]"; }

        const UMars_ItemTrait_Presentation Presentation = WorldItem.Get_Item().Get_Presentation();
        const auto Error = Get_PoseError(Entity, _Carrier.Hand, Presentation.Mounting.HeldOffset);
        if (Error > k_HandPoseToleranceCm)
        { return f"off its hand node by {Error} cm"; }

        return "";
    }

    // This machine's add-food row text; unset while the subject shows none.
    protected TOptional<FString> TryGet_AddFoodRow()
    {
        if (ck::Is_NOT_Valid(_Display))
        { return TOptional<FString>(); }

        for (auto Row : _Display.Get_VisibleHints())
        {
            const auto Spec = Row.Get_Spec();
            if (Spec.OwnerKey == n"StationFeed" && Spec.InputAction.Get() == mars::Mars_IA_StationAddFood)
            { return TOptional<FString>(Spec.Text.ToString()); }
        }

        return TOptional<FString>();
    }

    protected FString Get_AddFoodRowText()
    {
        const auto Row = TryGet_AddFoodRow();
        return Row.IsSet() ? Row.GetValue() : "<no row>";
    }

    // Some sampled frame while the report read InStep showed InText (exactly, for a row; contained, for a label).
    protected bool Get_SawRow(FString InText, int32 InStep)
    {
        for (const auto& Seen : _RowsSeen)
        {
            if (Seen.Step == InStep && Seen.Text == InText)
            { return true; }
        }

        return false;
    }

    protected bool Get_SawLabel(FString InText, int32 InStep)
    {
        for (const auto& Seen : _LabelsSeen)
        {
            if (Seen.Step == InStep && Seen.Text.Contains(InText))
            { return true; }
        }

        return false;
    }

    protected FString Describe_Seen(TArray<FMars_TESTONLY_NetFeedStationSeen> InSeen)
    {
        FString Text = "";
        for (const auto& Seen : InSeen)
        {
            const auto Shown = Seen.Text.Replace("\n", " / ");
            Text += f"{Seen.Step}:'{Shown}' ";
        }

        return Text;
    }

    protected bool Get_IsSubjectOperating()
    {
        return ck::IsValid(_Station) && _Station.As_Station().Get_IsOperatedBy(Get_SubjectEntity());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The sampler
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_FeedStationSample() {}

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        Try_FindPlatter();
        if (Try_FindFeedStation() == false)
        { return; }

        const auto Step = Get_FeedStationReport().Step;
        const auto Label = Get_ShownLabel();
        if (Label != _LastLabel || Step != _LastSampledStep)
        { _LabelsSeen.Add(Make_Seen(Step, Label)); }

        const auto Row = Get_AddFoodRowText();
        if (Row != _LastRow || Step != _LastSampledStep)
        { _RowsSeen.Add(Make_Seen(Step, Row)); }

        _LastLabel = Label;
        _LastRow = Row;
        _LastSampledStep = Step;

        if (Get_IsHandAtRest() == false)
        { _HandLeftRest = true; }

        for (const auto& Food : Get_FoodPiecesNear(_FloorTop))
        {
            if (Get_IsUnderFeedHand(Food))
            { Count_UnderHand(Food.Get_Id()); }
        }

        On_FeedStationSample();
    }

    private FMars_TESTONLY_NetFeedStationSeen Make_Seen(int32 InStep, FString InText)
    {
        auto Seen = FMars_TESTONLY_NetFeedStationSeen();
        Seen.Step = InStep;
        Seen.Text = InText;
        return Seen;
    }

    private void Count_UnderHand(FGuid InId)
    {
        for (int32 Index = 0; Index < _UnderHandIds.Num(); ++Index)
        {
            if (_UnderHandIds[Index] == InId)
            {
                _UnderHandFrames[Index] += 1;
                return;
            }
        }

        _UnderHandIds.Add(InId);
        _UnderHandFrames.Add(1);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The operator (either machine)
    //----------------------------------------------------------------------------------------------------------------------

    // The subject's Operator feature, its InputIntents and its hint display (reused when an earlier test of this session
    // composed them); any remote state an earlier test left behind is cleared.
    private void Begin_Operator()
    {
        auto Subject = Get_SubjectEntity();
        utils_operator::Add(Subject);
        _Intents = Subject.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { _Intents = utils_input_intents::Add(Subject); }

        _Display = Subject.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { _Display = utils_action_hint_display::Add(Subject); }

        _Intents.Request_ClearRemote(FMars_Request_InputIntents_ClearRemote());
    }

    // The seed: one remote sample carrying the add-food and the secondary rows at k_SeedSerial, released; then
    // InContinuation k_SeedFrames frames later. On the server it is the operator's stream; on a client, its own copy.
    protected void Seed_RemoteThen(FName InContinuation)
    {
        _AddFoodSerial = constants_feed_station_net_autotest::k_SeedSerial;
        _SweepSerial = constants_feed_station_net_autotest::k_SeedSerial;
        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.Intents.Add(FMars_InputIntents_RemoteIntent(GameplayTags::Mars_Intent_StationAddFood, _AddFoodSerial, EMars_InputIntents_Hold::Released));
        Sample.Intents.Add(FMars_InputIntents_RemoteIntent(GameplayTags::Mars_Intent_Interact_Secondary, _SweepSerial, EMars_InputIntents_Hold::Released));
        _Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
        WaitFrames(constants_feed_station_net_autotest::k_SeedFrames, InContinuation);
    }

    // InPresses remote add-food presses in one sample: the row's serial InPresses more, released.
    protected void Press_RemoteAddFood(int32 InPresses)
    {
        _AddFoodSerial += InPresses;
        _PressFrame = utils_time::Get_FrameCounter();
        Apply_RemotePress(GameplayTags::Mars_Intent_StationAddFood, _AddFoodSerial);
    }

    // A remote sweep press, the Interact_Secondary row at its next serial, released.
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
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerFeedStationReady() {}

    // Server: the station beside the platter under the spawn owner, as the map's spawner makes it (its own context), with
    // the test's feed timing, tracked; On_ServerFeedStationReady once this machine finds its docks and its feed composed.
    protected void Spawn_FeedStation()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Transform = FTransform(FRotator::ZeroRotator, Get_StationLocation());
        auto Pending = FCk_Handle_PendingEntityScript();
        if (_FeedStationKind == EMars_TESTONLY_RealFeedStationKind::Cutting)
        {
            auto Params = UMars_CuttingStation_EntityScript::Params();
            Params.SpawnTransform = Transform;
            if (_FeedTiming == EMars_TESTONLY_NetFeedStationTiming::Slow)
            { Params.Feed.Timing = Make_SlowTiming(); }

            Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_CuttingStation_EntityScript, Params);
        }
        else
        {
            auto Params = UMars_SearingStation_EntityScript::Params();
            Params.SpawnTransform = Transform;
            if (_FeedTiming == EMars_TESTONLY_NetFeedStationTiming::Slow)
            { Params.Feed.Timing = Make_SlowTiming(); }

            Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_SearingStation_EntityScript, Params);
        }

        _FeedStationEntity = Pending.Get_EntityUnderConstruction();
        _FeedStationEntity.Request_OverrideToSelf();
        Track_ForCleanup(_FeedStationEntity);
        WaitUntil(n"Is_RigFeedStationReady", n"OnRigFeedStationReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigFeedStationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_FeedStationEntity) && _FeedStationEntity.Is_CookingFeed() && Try_FindFeedStation());
    }

    UFUNCTION()
    private void OnRigFeedStationReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Station == _FeedStationEntity, "the server finds the station it spawned");
        On_ServerFeedStationReady();
    }

    // Server: seats the subject, seeds its remote state, then InContinuation.
    protected void Seat_SubjectThen(FName InContinuation)
    {
        auto Station = _Station.As_Station();
        Station.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        _SeatedContinuation = InContinuation;
        WaitUntil(n"Is_RigSubjectOperating", n"OnRigSubjectOperating", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigSubjectOperating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSubjectOperating());
    }

    UFUNCTION()
    private void OnRigSubjectOperating(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_RemoteThen(_SeatedContinuation);
    }

    // Server: the subject leaves the station (the station's own release, as the operator asks it).
    protected void Release_Subject()
    {
        auto Station = _Station.As_Station();
        Station.Request_Release(FMars_Request_Station_Release(Get_SubjectEntity(), EMars_Station_ReleaseReason::OperatorRequested));
    }

    // Server: InContinuation once the feed draws from a platter whose pile has frozen with InAvailable on it.
    protected void Await_SourcedThen(int32 InAvailable, FName InContinuation)
    {
        _AwaitedAvailable = InAvailable;
        _SourcedContinuation = InContinuation;
        WaitUntil(n"Is_RigSourced", n"OnRigSourced", k_SlowPolls);
    }

    protected bool Get_IsSourcedWith(int32 InAvailable)
    {
        return _Feed.Get_IsSourced() && _Feed.Get_IsSettling() == false && _Feed.Get_Available() == InAvailable;
    }

    UFUNCTION()
    private void Is_RigSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourcedWith(_AwaitedAvailable));
    }

    UFUNCTION()
    private void OnRigSourced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _SourcedContinuation);
    }

    // Server: InContinuation once the board holds one and the feed is Idle.
    protected void Await_BoardOneAndIdleThen(FName InContinuation)
    {
        _IdleContinuation = InContinuation;
        WaitUntil(n"Is_RigBoardOneAndIdle", n"OnRigBoardOneAndIdle", k_SlowPolls);
    }

    protected bool Get_IsBoardOneAndIdle()
    {
        return _Board.Get_HeldCount() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle;
    }

    UFUNCTION()
    private void Is_RigBoardOneAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBoardOneAndIdle());
    }

    UFUNCTION()
    private void OnRigBoardOneAndIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _IdleContinuation);
    }

    // The server's last step: it holds k_ServerOutliveSeconds while the client asserts, asserts no ensure, logs InText,
    // destroys its station and ends clean.
    protected void End_FeedStationServer(FString InText)
    {
        _FeedStationEndText = InText;
        WaitSeconds(k_ServerOutliveSeconds, n"OnRigFeedStationServerOutlived");
    }

    UFUNCTION()
    private void OnRigFeedStationServerOutlived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the server");
        Log_FeedStation(_FeedStationEndText);
        End_Sampling();
        if (Get_IsLive(_FeedStationEntity))
        { utils_entity_lifetime::Request_DestroyEntity(_FeedStationEntity); }

        End_Server();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // The client's last step: asserts no ensure, logs InText and waits until its station is gone and its X is clean.
    protected void End_FeedStationClient(FString InText)
    {
        End_Sampling();
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the client");
        Log_FeedStation(InText);
        WaitUntil(n"Is_RigClientFeedStationGone", n"OnRigClientFeedStationGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigClientFeedStationGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_Station) == false);
    }

    UFUNCTION()
    private void OnRigClientFeedStationGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Client();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRigPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase)
    {
        _Signals.Add(EMars_TESTONLY_NetFeedStationSignal::PhaseChanged);
        _Phases.Add(InPhase);
        _PhaseFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnRigStockChanged(FCk_Handle_CookingFeed InFeed, int32 InAvailable, int32 InAdmitted)
    {
        _Signals.Add(EMars_TESTONLY_NetFeedStationSignal::StockChanged);
    }

    UFUNCTION()
    private void OnRigTransferRefused(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal)
    {
        _Signals.Add(EMars_TESTONLY_NetFeedStationSignal::TransferRefused);
        _Refusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigPieceLetGo(FCk_Handle_CookingFeed InFeed, FCk_Handle_FoodPiece InPiece)
    {
        _Signals.Add(EMars_TESTONLY_NetFeedStationSignal::PieceLetGo);
        ++_LetGo;
    }

    UFUNCTION()
    private void OnRigTransferSettled(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle)
    {
        _Settles.Add(InSettle);
    }

    UFUNCTION()
    private void OnRigBoardHeldCountChanged(FCk_Handle_FoodBoard InBoard, int32 InHeldCount)
    {
        _Signals.Add(EMars_TESTONLY_NetFeedStationSignal::BoardHeldCountChanged);
        _BoardCounts.Add(InHeldCount);
    }
}
