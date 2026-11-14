// The CookingFeed net tests' shared steps, on the platter net rig. The server lays the floor, spawns the large platter and
// loads it with meat slabs until they have frozen, then spawns a test feed station 250 cm from the platter along -Y under
// the replicated spawn owner: a bare feed on the station's root (no input dock, no receiving kernel beside it, so the test
// answers every release), its release node 100 cm up, its hand node, which the feed moves by the single-machine rig's hand
// geometry, and 0.6 s timed phases with no admission budget. Each machine finds its own copy of the station by tag once its
// feed has composed, records in order every feed signal that copy raises, and samples every frame its hand node (offset,
// largest move between two frames), its phase clock, and whether the ledger's piece rides its hand node and at which
// offset. What the client compares against goes out in one test-only replicated report on the subject (and, at the same
// step, the platter rig's rides). One [CookingFeedNetTest] line per test per machine; ensures are 0 on both.

namespace constants_cooking_feed_net_autotest
{
    const float32 k_PhaseSeconds = 0.6f;
    const FVector k_StationOffset = FVector(0.0, -250.0, 0.0);
    const FVector k_ReleaseLocal = FVector(0.0, 0.0, 100.0);
    const FVector k_HandLocal = FVector(0.0, 100.0, 60.0);
    const float32 k_LiftClearCm = 20.0f;
}

// The test feed station: a release node and a hand node under the root, and a bare feed on the root with the timing
// Get_FeedTiming returns.
class UMars_TESTONLY_NetFeedStation_EntityScript : UMars_TESTONLY_Station_EntityScript
{
    protected FCk_Handle_Transform _ReleaseNode;
    protected FCk_Handle_Transform _HandNode;

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        auto Handle = InRoot.H();
        utils_entity_tag::Add(Handle, n"TAG_MarsTestNetFeedStation");
        _ReleaseNode = utils_scene_node::Create(InRoot, FTransform(constants_cooking_feed_net_autotest::k_ReleaseLocal)).As_Transform();
        _HandNode = utils_scene_node::Create(InRoot, FTransform(constants_cooking_feed_net_autotest::k_HandLocal)).As_Transform();
        Compose_Feed(Handle);
    }

    // Four timed phases of k_PhaseSeconds, no admission budget: the test answers every release.
    protected FMars_CookingFeed_TimingSpec Get_FeedTiming() const
    {
        const auto Seconds = constants_cooking_feed_net_autotest::k_PhaseSeconds;
        auto Timing = FMars_CookingFeed_TimingSpec(Seconds, Seconds, Seconds, Seconds);
        Timing.AdmissionBudgetSeconds = 0.0f;
        return Timing;
    }

    protected void Compose_Feed(FCk_Handle& InHandle)
    {
        auto Spec = FMars_CookingFeed_Spec(Get_FeedTiming(), FMars_CookingFeed_MotionSpec());
        auto Hand = FMars_CookingFeed_HandGeometry();
        Hand.RestLocal = FTransform(constants_cooking_feed_net_autotest::k_HandLocal);
        Hand.ClearanceCm = constants_cooking_feed_net_autotest::k_LiftClearCm;
        Spec.Hand = TOptional<FMars_CookingFeed_HandGeometry>(Hand);
        Spec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode, _HandNode);
        utils_cooking_feed::Add(InHandle, Spec);
    }
}

// The test feed station with four zero-length phases: a whole transfer fits in the frame of its press and its answer.
class UMars_TESTONLY_NetInstantFeedStation_EntityScript : UMars_TESTONLY_NetFeedStation_EntityScript
{
    protected FMars_CookingFeed_TimingSpec Get_FeedTiming() const override
    {
        auto Timing = FMars_CookingFeed_TimingSpec(0.0f, 0.0f, 0.0f, 0.0f);
        Timing.AdmissionBudgetSeconds = 0.0f;
        return Timing;
    }
}

// The test feed station as a replicating real station composes its feed: the construction ends in the spawn frame and the
// authority composes the feed from a tick a frame later; a machine without authority composes it at once.
class UMars_TESTONLY_NetLateFeedStation_EntityScript : UMars_TESTONLY_NetFeedStation_EntityScript
{
    private FCk_Handle _Self;
    private FCk_Handle_Timer _LateTimer;

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        auto Handle = InRoot.H();
        utils_entity_tag::Add(Handle, n"TAG_MarsTestNetFeedStation");
        _ReleaseNode = utils_scene_node::Create(InRoot, FTransform(constants_cooking_feed_net_autotest::k_ReleaseLocal)).As_Transform();
        _HandNode = utils_scene_node::Create(InRoot, FTransform(constants_cooking_feed_net_autotest::k_HandLocal)).As_Transform();
        if (utils_net::Get_HasAuthority(Handle) == false)
        {
            Compose_Feed(Handle);
            return;
        }

        _Self = Handle;
        _LateTimer = utils_timer::Create_Tick(Handle, FCk_Delegate_Timer(this, n"OnLateCompose"));
    }

    UFUNCTION()
    private void OnLateCompose(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_timer::UnbindFrom_OnUpdate(_LateTimer, FCk_Delegate_Timer(this, n"OnLateCompose"));
        utils_entity_lifetime::Request_DestroyEntity(_LateTimer.H());
        _LateTimer = FCk_Handle_Timer();
        Log(f"[CookingFeedNetTest] the late station [{_Self.ToString()}] composes its feed at frame {utils_time::Get_FrameCounter()}");
        Compose_Feed(_Self);
    }
}

// A harness fixture: the timed test feed station whose authority, as it composes, sources its feed from the platter
// beside it and presses add food twice, so its drain sets the source, begins a reach and refuses the second press Busy
// in the spawn frame. A copy is born into a reach with one refusal.
class UMars_TESTONLY_NetBornFeedStation_EntityScript : UMars_TESTONLY_NetFeedStation_EntityScript
{
    private const float64 k_PlatterReachCm = 500.0;

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        Super::AddVisuals(InRoot);

        auto Handle = InRoot.H();
        if (utils_net::Get_HasAuthority(Handle) == false)
        { return; }

        const auto Platter = Find_PlatterBeside(Handle);
        if (ck::EnsureIfNot(ck::IsValid(Platter), f"[CookingFeedNetTest] [{Handle.ToString()}] found no platter beside it"))
        { return; }

        auto Feed = Handle.As_CookingFeed();
        Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(Platter));
        Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
        Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    // The live platter world item within k_PlatterReachCm of the spawn location; invalid when there is none.
    private FCk_Handle_Platter Find_PlatterBeside(FCk_Handle InContext)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InContext, n"TAG_MarsWorldItem"))
        {
            const auto IsLive = ck::IsValid(Candidate)
                && utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;
            if (IsLive == false || Candidate.Is_Transform() == false || Candidate.Is_Platter() == false)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentLocation(Candidate.As_Transform());
            if (Location.Distance(SpawnTransform.GetLocation()) <= k_PlatterReachCm)
            { return Candidate.As_Platter(); }
        }

        return FCk_Handle_Platter();
    }
}

enum EMars_TESTONLY_NetFeedStationKind
{
    Timed,
    Instant,
    Late,
    Born
}

// One feed signal a machine's copy raised.
enum EMars_TESTONLY_NetFeedEvent
{
    PhaseChanged,
    StockChanged,
    TransferRefused,
    PieceLetGo,
    TransferSettled,
    ReleaseRequested
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only: a feature's processors are
// the only writers in game code).
struct FMars_Fragment_TESTONLY_NetCookingFeedReport
{
    UPROPERTY()
    int32 Serial = 0;

    UPROPERTY()
    int32 Step = 0;

    UPROPERTY()
    FGuid PieceId;

    // The feed's hand node's offset.
    UPROPERTY()
    FTransform HandLocal = FTransform::Identity;

    // The reserved piece's offset under the hand node through the carry.
    UPROPERTY()
    FTransform HeldLocal = FTransform::Identity;

    UPROPERTY()
    FTransform PieceWorld = FTransform::Identity;

    UPROPERTY()
    int32 Available = 0;

    UPROPERTY()
    int32 Admitted = 0;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetCookingFeed : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    // A beat for the client's copy to compose and bind before the server's first request.
    protected const float32 k_ClientBindSeconds = 1.0f;
    protected const float64 k_HandRestToleranceCm = 0.01;
    protected const FVector k_SecondSlabOffset = FVector(60.0, 150.0, 5.0);

    protected EMars_TESTONLY_NetFeedStationKind _StationKind = EMars_TESTONLY_NetFeedStationKind::Timed;
    protected int32 _SlabCount = 2;

    // Server: the station it spawned and the slabs it loaded, in load order.
    protected FCk_Handle _StationEntity;
    protected TArray<FCk_Handle> _Slabs;

    // This machine's copy of the feed and its hand node, once found.
    protected FCk_Handle_CookingFeed _Feed;
    protected FCk_Handle_Transform _FeedHand;
    protected int64 _FeedFoundFrame = -1;
    private bool _WasFeedFound = false;
    // Off authority: each rep-notify of the copy's ledger, its frame counter and the ledger as it then read.
    protected TArray<int64> _NotifyFrames;
    // The copy's InitialState as this machine read it when it found the copy.
    protected EMars_Net_InitialState _InitialAtFind = EMars_Net_InitialState::Awaited;
    protected TArray<FMars_Fragment_CookingFeed_Net> _NotifyLedgers;
    // The lowest phase progress sampled once a first notify is recorded while the ledger still read its phase serial.
    protected float32 _LowestFirstPhaseProgress = 2.0f;

    // Every signal this machine's copy raised since it was found (or since Clear_FeedRecord), in order.
    protected TArray<EMars_TESTONLY_NetFeedEvent> _Events;
    protected TArray<EMars_CookingFeed_Phase> _Phases;
    // The frame counter of each phase change, in parallel.
    protected TArray<int64> _PhaseFrames;
    // In parallel: one entry per OnStockChanged.
    protected TArray<int32> _StockAvailable;
    protected TArray<int32> _StockAdmitted;
    protected TArray<EMars_CookingFeed_Refusal> _Refusals;
    protected int32 _LetGo = 0;
    // Server only.
    protected TArray<EMars_CookingFeed_Settle> _Settles;
    protected TArray<FMars_CookingFeed_Release> _Releases;

    // The sampler's records.
    protected float64 _HandMaxStepCm = 0.0;
    protected int32 _ProgressDrops = 0;
    // The ledger piece's offset under this machine's hand node on every sampled Carry frame it rode there.
    protected TArray<FTransform> _CarryHeld;
    protected FCk_Handle_FoodPiece _CarryPiece;
    // Sampled Carry frames on which the ledger's held piece was not under this hand node after it had been.
    protected TArray<FString> _CarryFaults;
    // The last frame counter on which any food near the test's X was under this machine's hand node.
    protected int64 _LastUnderHandFrame = -1;
    private TOptional<FVector> _LastHandWorld;
    private int32 _LastPhaseSerial = -1;
    private float32 _LastProgress = 0.0f;

    private EMars_CookingFeed_Phase _AwaitedPhase = EMars_CookingFeed_Phase::Idle;
    private int32 _AwaitedFeedStep = 0;
    private FName _StepContinuation;
    private FString _FeedEndText;

    // Call first, on both machines.
    protected void Begin_FeedRig(FCk_Handle InTestEntity, float64 InX)
    {
        Begin_PlatterRig(InTestEntity, InX);
        Add_FeedReport();
        Begin_Sampling(InTestEntity);
    }

    protected void Log_Feed(FString InText)
    {
        const auto Machine = Get_MachineName();
        const auto TestName = GetClass().GetName();
        const auto Ensures = Get_EnsureDelta();
        const auto Find = Describe_Find();
        const auto Line = f"[CookingFeedNetTest] {TestName} {Machine}: {InText} {Find} ensures={Ensures}";
        Log(Line);
    }

    // This machine's copy's level now; Awaited while there is none.
    protected EMars_Net_InitialState Get_FeedInitialState()
    {
        if (ck::Is_NOT_Valid(_Feed) || _Feed.Has_Fragment(FMars_Fragment_CookingFeed_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Feed.Get_Fragment(FMars_Fragment_CookingFeed_Local).InitialState;
    }

    protected bool Get_HasFirstNotify() const
    {
        return _NotifyFrames.Num() > 0;
    }

    // The ledger the first recorded rep-notify read; the composed default while none is recorded.
    protected FMars_Fragment_CookingFeed_Net Get_FirstNotifyLedger() const
    {
        if (_NotifyLedgers.Num() == 0)
        { return FMars_Fragment_CookingFeed_Net(); }

        return _NotifyLedgers[0];
    }

    protected int64 Get_FirstNotifyFrame() const
    {
        if (_NotifyFrames.Num() == 0)
        { return -1; }

        return _NotifyFrames[0];
    }

    protected FString Describe_Find()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _NotifyFrames.Num(); ++Index)
        {
            const auto& Ledger = _NotifyLedgers[Index];
            Notifies += f"{_NotifyFrames[Index]}:{Ledger.Phase :n}/{Ledger.PhaseSerial}/{Ledger.RefusalSerial}/{Ledger.LetGoSerial} ";
        }

        return f"found@{_FeedFoundFrame} initialAtFind={_InitialAtFind :n} initial={Get_FeedInitialState() :n} notifies=[{Notifies}] lowestFirstProgress={_LowestFirstPhaseProgress}";
    }

    // A notify can land on a feed already ending.
    UFUNCTION()
    private void OnRigLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Has_Fragment(FMars_Fragment_CookingFeed_Net) == false)
        { return; }

        _NotifyFrames.Add(utils_time::Get_FrameCounter());
        _NotifyLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_CookingFeed_Net));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Report
    //----------------------------------------------------------------------------------------------------------------------

    protected void Add_FeedReport()
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetCookingFeedReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetCookingFeedReport(), ECk_Replication::Replicates); }
    }

    protected FMars_Fragment_TESTONLY_NetCookingFeedReport Get_FeedReport()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetCookingFeedReport);
    }

    // Server: step InStep as the report stands, with the feed's stock and its hand's offset now.
    protected FMars_Fragment_TESTONLY_NetCookingFeedReport Make_FeedStep(int32 InStep)
    {
        auto Report = Get_FeedReport();
        Report.Step = InStep;
        Report.Available = _Feed.Get_Available();
        Report.Admitted = _Feed.Get_Admitted();
        Report.HandLocal = Get_HandOffset();
        return Report;
    }

    // Server: the platter's rides at InReport's step (a location-only step once the platter is gone), then InReport with
    // the next serial.
    protected void Publish_FeedStep(FMars_Fragment_TESTONLY_NetCookingFeedReport InReport)
    {
        if (Get_IsLive(_Platter))
        { Publish_Rides(InReport.Step); }
        else
        { Publish_Location(InReport.Step, FVector::ZeroVector); }

        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetCookingFeedReport);
        const auto Serial = Report.Serial;
        Report = InReport;
        Report.Serial = Serial + 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetCookingFeedReport);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Either machine
    //----------------------------------------------------------------------------------------------------------------------

    // Finds this machine's copy of the feed station near the test's X once its feed has composed, and records its signals
    // from then on (the server also its settles and releases, and tracks the station).
    protected bool Try_FindFeed()
    {
        // Once found, a station the server's cleanup destroyed is never found again.
        if (_WasFeedFound)
        { return ck::IsValid(_Feed); }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetFeedStation"))
        {
            if (Get_IsLive(Candidate) == false || Get_IsNear(Candidate, _FloorTop) == false)
            { continue; }

            auto Feed = Candidate.As_CookingFeed(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Feed))
            { continue; }

            _WasFeedFound = true;
            _Feed = Feed;
            _FeedHand = Feed.Get_HandNode();
            _FeedFoundFrame = utils_time::Get_FrameCounter();
            _InitialAtFind = Get_FeedInitialState();
            if (Get_IsServer() == false)
            {
                FCk_Handle Entity = Candidate;
                Entity.BindTo_OnRepNotify(FMars_Fragment_CookingFeed_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnRigLedgerNotify"));
            }

            _Feed.BindTo_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnRigPhaseChanged"));
            _Feed.BindTo_OnStockChanged(FMars_Delegate_CookingFeed_OnStockChanged(this, n"OnRigStockChanged"));
            _Feed.BindTo_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnRigTransferRefused"));
            _Feed.BindTo_OnPieceLetGo(FMars_Delegate_CookingFeed_OnPieceLetGo(this, n"OnRigPieceLetGo"));
            if (Get_IsServer())
            {
                _Feed.BindTo_OnTransferSettled(FMars_Delegate_CookingFeed_OnTransferSettled(this, n"OnRigTransferSettled"));
                _Feed.BindTo_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnRigReleaseRequested"));
            }

            return true;
        }

        return false;
    }

    UFUNCTION()
    private void OnRigPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase)
    {
        _Events.Add(EMars_TESTONLY_NetFeedEvent::PhaseChanged);
        _Phases.Add(InPhase);
        _PhaseFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnRigStockChanged(FCk_Handle_CookingFeed InFeed, int32 InAvailable, int32 InAdmitted)
    {
        _Events.Add(EMars_TESTONLY_NetFeedEvent::StockChanged);
        _StockAvailable.Add(InAvailable);
        _StockAdmitted.Add(InAdmitted);
    }

    UFUNCTION()
    private void OnRigTransferRefused(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal)
    {
        _Events.Add(EMars_TESTONLY_NetFeedEvent::TransferRefused);
        _Refusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigPieceLetGo(FCk_Handle_CookingFeed InFeed, FCk_Handle_FoodPiece InPiece)
    {
        _Events.Add(EMars_TESTONLY_NetFeedEvent::PieceLetGo);
        ++_LetGo;
    }

    UFUNCTION()
    private void OnRigTransferSettled(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle)
    {
        _Events.Add(EMars_TESTONLY_NetFeedEvent::TransferSettled);
        _Settles.Add(InSettle);
    }

    UFUNCTION()
    private void OnRigReleaseRequested(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease)
    {
        _Events.Add(EMars_TESTONLY_NetFeedEvent::ReleaseRequested);
        _Releases.Add(InRelease);
    }

    // What this copy raised before is not counted from here on.
    protected void Clear_FeedRecord()
    {
        _Events.Empty();
        _Phases.Empty();
        _PhaseFrames.Empty();
        _StockAvailable.Empty();
        _StockAdmitted.Empty();
        _Refusals.Empty();
        _LetGo = 0;
        _Settles.Empty();
        _Releases.Empty();
    }

    protected int32 Get_EventCount(EMars_TESTONLY_NetFeedEvent InEvent)
    {
        auto Count = 0;
        for (const auto Event : _Events)
        {
            if (Event == InEvent)
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

    // The phases raised are exactly InExpected, in order.
    protected bool Get_ArePhases(TArray<EMars_CookingFeed_Phase> InExpected)
    {
        if (_Phases.Num() != InExpected.Num())
        { return false; }

        for (int32 Index = 0; Index < _Phases.Num(); ++Index)
        {
            if (_Phases[Index] != InExpected[Index])
            { return false; }
        }

        return true;
    }

    // Reach, Grasp, Carry, AwaitAdmission, Return, Idle.
    protected TArray<EMars_CookingFeed_Phase> Get_TransferPhases()
    {
        TArray<EMars_CookingFeed_Phase> Phases;
        Phases.Add(EMars_CookingFeed_Phase::Reach);
        Phases.Add(EMars_CookingFeed_Phase::Grasp);
        Phases.Add(EMars_CookingFeed_Phase::Carry);
        Phases.Add(EMars_CookingFeed_Phase::AwaitAdmission);
        Phases.Add(EMars_CookingFeed_Phase::Return);
        Phases.Add(EMars_CookingFeed_Phase::Idle);
        return Phases;
    }

    protected FString Describe_Phases()
    {
        FString Text = "";
        for (int32 Index = 0; Index < _Phases.Num(); ++Index)
        { Text += f"{_Phases[Index] :n}@{_PhaseFrames[Index]} "; }

        return Text;
    }

    protected FString Describe_Stock()
    {
        FString Text = "";
        for (int32 Index = 0; Index < _StockAvailable.Num(); ++Index)
        { Text += f"({_StockAvailable[Index]},{_StockAdmitted[Index]}) "; }

        return Text;
    }

    protected FString Describe_Refusals()
    {
        FString Text = "";
        for (const auto Refusal : _Refusals)
        { Text += f"{Refusal :n} "; }

        return Text;
    }

    protected FString Describe_Settles()
    {
        FString Text = "";
        for (const auto Settle : _Settles)
        { Text += f"{Settle :n} "; }

        return Text;
    }

    protected FString Describe_Record()
    {
        return f"phases=[{Describe_Phases()}] stock=[{Describe_Stock()}] refusals=[{Describe_Refusals()}] letGo={_LetGo} settles=[{Describe_Settles()}] releases={_Releases.Num()}";
    }

    protected FString Describe_Ledger(FMars_Fragment_CookingFeed_Net InLedger)
    {
        return f"serial={InLedger.PhaseSerial} phase={InLedger.Phase :n} hold={InLedger.Hold :n} aim={InLedger.Aim :n} sourcing={InLedger.Sourcing :n} available={InLedger.Available} admitted={InLedger.Admitted} pile={InLedger.Pile :n} refusals={InLedger.RefusalSerial} last={InLedger.LastRefusal :n} letGo={InLedger.LetGoSerial}";
    }

    // The hand node's offset in the station's frame on this machine.
    protected FTransform Get_HandOffset()
    {
        FCk_Handle Entity = _FeedHand;
        return utils_scene_node::Get_Offset(Entity.As_SceneNode());
    }

    // How far this machine's hand node is from its rest pose, in cm.
    protected float64 Get_HandRestErrorCm()
    {
        return Get_HandOffset().GetLocation().Distance(constants_cooking_feed_net_autotest::k_HandLocal);
    }

    // The hand node is at rest as the feed itself compares a pose before it writes one: every component within
    // k_HandRestToleranceCm (the feed leaves a pose that close unwritten).
    protected bool Get_IsHandAtRest()
    {
        return Get_HandOffset().Equals(FTransform(constants_cooking_feed_net_autotest::k_HandLocal), k_HandRestToleranceCm);
    }

    protected FString Describe_HandRest()
    {
        const auto Delta = Get_HandOffset().GetLocation() - constants_cooking_feed_net_autotest::k_HandLocal;
        return f"off by {Get_HandRestErrorCm()} cm, per axis {Delta.ToString()}";
    }

    protected bool Get_IsUnderFeedHand(FCk_Handle_FoodPiece InPiece)
    {
        const auto Parent = Get_Parent(InPiece);
        return ck::IsValid(Parent) && ck::IsValid(_FeedHand) && Parent == _FeedHand;
    }

    // InPiece's world pose on this machine.
    protected FTransform Get_PieceWorld(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    // Empty when every piece of the platter report's last step rides this machine's platter at its slot and none is under
    // this machine's hand node; otherwise the first fault.
    protected FString Get_PileFault()
    {
        const auto Report = Get_PlatterReport();
        if (Try_FindPlatter() == false)
        { return "no platter"; }

        for (int32 Index = 0; Index < Report.Count; ++Index)
        {
            const auto Slot = Get_Slot(Report, Index);
            const auto Piece = Find_PieceById(Slot.Id);
            if (Get_IsUnderFeedHand(Piece))
            { return f"slot {Index} is under the feed's hand node"; }

            const auto Fault = Get_RideFault(Piece, Slot);
            if (Fault.IsEmpty() == false)
            { return f"slot {Index}: {Fault}"; }
        }

        return "";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The sampler
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_FeedSample() {}

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        Try_FindPlatter();
        if (Try_FindFeed() == false)
        { return; }

        Sample_Feed();
        On_FeedSample();
    }

    private void Sample_Feed()
    {
        const auto Frame = utils_time::Get_FrameCounter();
        const auto HandWorld = utils_transform::Get_EntityCurrentLocation(_FeedHand);
        if (_LastHandWorld.IsSet())
        { _HandMaxStepCm = Math::Max(_HandMaxStepCm, HandWorld.Distance(_LastHandWorld.GetValue())); }

        _LastHandWorld = TOptional<FVector>(HandWorld);

        const auto Ledger = _Feed.Get_Ledger();
        const auto Progress = _Feed.Get_PhaseProgress();
        if (Ledger.PhaseSerial == _LastPhaseSerial && Progress < _LastProgress - 0.0001f)
        { ++_ProgressDrops; }

        _LastPhaseSerial = Ledger.PhaseSerial;
        _LastProgress = Progress;

        if (Get_HasFirstNotify() && Ledger.PhaseSerial == Get_FirstNotifyLedger().PhaseSerial)
        { _LowestFirstPhaseProgress = Math::Min(_LowestFirstPhaseProgress, Progress); }

        for (const auto& Food : Get_FoodPiecesNear(_FloorTop))
        {
            if (Get_IsUnderFeedHand(Food))
            { _LastUnderHandFrame = Frame; }
        }

        if (_Feed.Get_Phase() != EMars_CookingFeed_Phase::Carry || Ledger.Hold != EMars_CookingFeed_PieceHold::InHand)
        { return; }

        const auto Piece = Ledger.Piece.As_FoodPiece(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Piece))
        { return; }

        if (Get_IsUnderFeedHand(Piece))
        {
            _CarryPiece = Piece;
            _CarryHeld.Add(Get_Offset(Piece));
            return;
        }

        if (_CarryHeld.Num() > 0)
        { _CarryFaults.Add(f"frame {Frame} parent=[{Get_Parent(Piece).ToString()}] world={Get_PieceWorld(Piece).GetLocation().ToString()}"); }
    }

    // Sampled Carry frames on which the ledger piece with InId rode this hand node within InToleranceCm and
    // InToleranceDegrees of InHeld.
    protected int32 Get_CarryFramesAt(FGuid InId, FTransform InHeld, float64 InToleranceCm, float64 InToleranceDegrees)
    {
        if (ck::Is_NOT_Valid(_CarryPiece) || _CarryPiece.Get_Id() != InId)
        { return 0; }

        auto Count = 0;
        for (const auto& Offset : _CarryHeld)
        {
            const auto Cm = Offset.GetLocation().Distance(InHeld.GetLocation());
            const auto Degrees = Get_AngleDegrees(Offset.GetRotation(), InHeld.GetRotation());
            if (Cm <= InToleranceCm && Degrees <= InToleranceDegrees)
            { ++Count; }
        }

        return Count;
    }

    // The worst location error of the sampled carry offsets against InHeld, in cm.
    protected float64 Get_CarryWorstCm(FTransform InHeld)
    {
        auto Worst = 0.0;
        for (const auto& Offset : _CarryHeld)
        { Worst = Math::Max(Worst, Offset.GetLocation().Distance(InHeld.GetLocation())); }

        return Worst;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerFeedFound() {}

    protected void On_ServerSourced() {}

    // The slabs, the first loaded once it is Ready.
    protected void On_ServerPlatterReady() override
    {
        _Slabs.Add(Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0));
        if (_SlabCount > 1)
        { _Slabs.Add(Spawn_ServerFood(mars_items::Food_MeatSlab(), _FloorTop + k_SecondSlabOffset)); }

        Load_WhenReady(_Slabs[0], 1);
    }

    // The next slab is loaded once the last has frozen; the station is spawned once every slab has.
    protected void On_ServerFrozen() override
    {
        const auto Held = _Platter.Get_HeldCount();
        if (Held < _Slabs.Num())
        {
            Load_WhenReady(_Slabs[Held], Held + 1);
            return;
        }

        Spawn_FeedStation();
    }

    // Server: the test station of _StationKind under the spawn owner, tracked; On_ServerFeedFound once its feed is found.
    protected void Spawn_FeedStation()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Params = FMars_TESTONLY_StationSpawnParams(
            FTransform(_FloorTop + constants_cooking_feed_net_autotest::k_StationOffset), FMars_Station_Spec());

        auto Pending = FCk_Handle_PendingEntityScript();
        if (_StationKind == EMars_TESTONLY_NetFeedStationKind::Instant)
        { Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetInstantFeedStation_EntityScript, Params); }
        else if (_StationKind == EMars_TESTONLY_NetFeedStationKind::Late)
        { Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetLateFeedStation_EntityScript, Params); }
        else if (_StationKind == EMars_TESTONLY_NetFeedStationKind::Born)
        { Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetBornFeedStation_EntityScript, Params); }
        else
        { Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetFeedStation_EntityScript, Params); }

        _StationEntity = Pending.Get_EntityUnderConstruction();
        Track_ForCleanup(_StationEntity);
        WaitUntil(n"Is_RigFeedFound", n"OnRigServerFeedFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigFeedFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindFeed());
    }

    UFUNCTION()
    private void OnRigServerFeedFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Feed == _StationEntity.As_CookingFeed(ECk_SanityCheck::UnChecked), "the server finds the feed of the station it spawned");
        On_ServerFeedFound();
    }

    // Server: k_ClientBindSeconds for the client's copy to compose and bind, then Source_Feed.
    protected void Source_AfterBind()
    {
        WaitSeconds(k_ClientBindSeconds, n"OnRigBound");
    }

    UFUNCTION()
    private void OnRigBound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Source_Feed();
    }

    // Server: the feed draws from the platter; On_ServerSourced once it reads sourced.
    protected void Source_Feed()
    {
        _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(_Platter));
        WaitUntil(n"Is_RigSourced", n"OnRigSourced", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Feed.Get_IsSourced());
    }

    UFUNCTION()
    private void OnRigSourced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerSourced();
    }

    // An add-food press with the station's gate open.
    protected void Begin_Transfer()
    {
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    // The admission answer for the active piece.
    protected void Answer(EMars_CookingFeed_Admission InAdmission)
    {
        const auto Active = _Feed.TryGet_ActivePiece();
        Assert_True(Active.IsSet(), "the feed has an active piece to answer for");
        if (Active.IsSet() == false)
        { return; }

        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(Active.GetValue(), InAdmission, "test answer"));
    }

    // InContinuation once the feed's phase reads InPhase.
    protected void Await_Phase(EMars_CookingFeed_Phase InPhase, FName InContinuation)
    {
        _AwaitedPhase = InPhase;
        WaitUntil(n"Is_RigPhase", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigPhase(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindFeed() && _Feed.Get_Phase() == _AwaitedPhase);
    }

    // InContinuation in the first frame TryGet_PieceHold reads InHand.
    protected void Await_InHand(FName InContinuation)
    {
        WaitUntil(n"Is_RigInHand", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigInHand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Hold = _Feed.TryGet_PieceHold();
        auto Result = OutResult;
        Result.Set(Hold.IsSet() && Hold.GetValue() == EMars_CookingFeed_PieceHold::InHand);
    }

    // InContinuation once the platter holds InHeld frozen pieces again and nothing else on its books.
    protected void Await_PileFrozen(int32 InHeld, FName InContinuation)
    {
        _AwaitedFeedStep = InHeld;
        WaitUntil(n"Is_RigPileFrozen", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigPileFrozen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Platter.Get_HeldCount() == _AwaitedFeedStep && _Platter.Get_Occupancy() == _AwaitedFeedStep);
    }

    // The server's last step: it holds k_ServerOutliveSeconds while the client asserts, logs InText, asserts no ensure
    // and ends clean.
    protected void End_FeedServer(FString InText)
    {
        _FeedEndText = InText;
        WaitSeconds(k_ServerOutliveSeconds, n"OnRigFeedServerOutlived");
    }

    UFUNCTION()
    private void OnRigFeedServerOutlived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the server");
        Log_Feed(_FeedEndText);
        End_Sampling();
        End_Server();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // InContinuation k_ClientSettleSeconds after this machine has its feed and both reports reached InStep.
    protected void Await_FeedStep(int32 InStep, FName InContinuation)
    {
        _AwaitedFeedStep = InStep;
        _StepContinuation = InContinuation;
        WaitUntil(n"Is_RigFeedStepArrived", n"OnRigFeedStepArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigFeedStepArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindFeed() && Get_FeedReport().Step >= _AwaitedFeedStep && Get_PlatterReport().Step >= _AwaitedFeedStep);
    }

    UFUNCTION()
    private void OnRigFeedStepArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, _StepContinuation);
    }

    // The client's last step: asserts no ensure, logs InText and waits until its X is clean.
    protected void End_FeedClient(FString InText)
    {
        End_Sampling();
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the client");
        Log_Feed(InText);
        End_Client();
    }
}
