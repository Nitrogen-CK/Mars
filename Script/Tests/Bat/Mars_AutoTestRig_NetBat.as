// One OnPhaseChanged as a machine raised it, with the frame it was raised in.
struct FMars_NetBatTest_Phase
{
    UPROPERTY()
    EMars_Bat_Phase From = EMars_Bat_Phase::Roosting;

    UPROPERTY()
    EMars_Bat_Phase To = EMars_Bat_Phase::Roosting;

    UPROPERTY()
    int32 Frame = -1;
}

// The highest and the lowest swoop progress sampled in one stage; Samples is 0 while none was.
struct FMars_NetBatTest_AlphaRange
{
    UPROPERTY()
    float32 Highest = 0.0f;

    UPROPERTY()
    float32 Lowest = 0.0f;

    UPROPERTY()
    int32 Samples = 0;
}

// At one telegraph sample: the root's yaw and pitch error against the bearing to a row's facing point (the pitch
// clamped as the telegraph clamps it).
struct FMars_NetBatTest_Facing
{
    UPROPERTY()
    float64 Yaw = -1.0;

    UPROPERTY()
    float64 Pitch = -1.0;
}

// The swoop as this machine's copy was sampled: each stage as it was first sampled (the first sample's included), the
// progress range in each stage, the rewinds (a stage's clock read lower than at the sample before in the same stage),
// the lowest telemetry pitch and, against a row's facing point, the facing at the first and the last telegraph sample
// and how far the root turned (yaw and pitch summed) between successive telegraph samples.
struct FMars_NetBatTest_Swoop
{
    UPROPERTY()
    TArray<EMars_Bat_SwoopStage> Stages;

    UPROPERTY()
    FMars_NetBatTest_AlphaRange Telegraph;

    UPROPERTY()
    FMars_NetBatTest_AlphaRange Dive;

    UPROPERTY()
    FMars_NetBatTest_AlphaRange Recover;

    UPROPERTY()
    int32 Rewinds = 0;

    UPROPERTY()
    float32 LowestPitch = 1000.0f;

    UPROPERTY()
    int32 FacingSamples = 0;

    UPROPERTY()
    FMars_NetBatTest_Facing FacingFirst;

    UPROPERTY()
    FMars_NetBatTest_Facing FacingLast;

    UPROPERTY()
    float64 Turned = 0.0;
}

// The Cellar Bat net tests' shared steps, on top of the strike rig (whose striker only the strike row composes). The
// server lays the single-machine rig's world, owned by its subject: a static floor (3000 square, its top at the floor
// point), a roost entity 580 over the floor point and a flight volume over the floor, baked once every static is in;
// the client lays nothing (its copy flies nothing). The server then spawns the bat through its real entity script under
// the replicated spawn owner, at the hang point (500 over the floor point) or a row's offset from it, with the rig's
// volume in its spec and the roost given or left to be discovered. Each machine finds its copy by its tag near the
// base, records its OnPhaseChanged (with the frame), counts its OnSwoopLanded, OnSwoopCancelled, OnRouteOutcome,
// OnPerchLost, OnTargetChanged, its monster's OnDied and its body Health's OnDamaged, and samples it from the row's
// polled predicates: the largest step between two samples, the farthest from the hang point, the highest telemetry
// speed, the largest turn rate either way, the largest yaw change between two samples, the lowest height over the
// floor point, the swoop as its copy shows it (FMars_NetBatTest_Swoop) and the frame its root first stood where it was
// spawned.
UCLASS(Abstract)
class UMars_AutoTestRig_NetBat : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 28.0f;

    protected const FVector k_BatFloorHalfExtents = FVector(1500.0, 1500.0, 10.0);
    protected const float64 k_RoostHeight = 580.0;
    // A strike row's hand is level with a hanging bat: the strike rig's hand stands 60 over its base.
    protected const float64 k_StrikeBaseUnderHang = 60.0;

    // The row's choices, set before Begin_ServerWorld.
    protected FMars_Bat_Spec _Spec;
    protected FVector _SpawnOffset = FVector::ZeroVector;
    protected ECk_EnableDisable _GivesRoost = ECk_EnableDisable::Enable;
    protected bool _WithVisuals = false;
    // Set: the bat is spawned through the held fixture, whose authority holds this ledger from its construct on.
    protected TOptional<FMars_Fragment_Bat_Net> _HeldLedger;
    // Set on both machines alike: the place the telegraph's facing is measured against.
    protected TOptional<FVector> _FacingPoint;
    // Passed to the held fixture: its authority moves the bat's root this far from its spawn place as it composes.
    protected FVector _HeldRootOffset = FVector::ZeroVector;

    protected FVector _Floor = FVector::ZeroVector;
    protected FVector _HangAt = FVector::ZeroVector;

    protected FCk_Handle_Bat _Bat;
    protected FCk_Handle_Monster _BatMonster;
    protected FCk_Handle _Roost;
    protected FCk_Handle_VoxelNavVolume _Volume;
    protected FCk_Handle _PreyEntity;
    protected TArray<FCk_Handle_JoltBody> _BatStatics;
    protected FVector _BatFoundAt = FVector::ZeroVector;

    protected TArray<FMars_NetBatTest_Phase> _BatPhases;
    protected int32 _BatSwoopsLanded = 0;
    protected int32 _BatSwoopsCancelled = 0;
    protected int32 _BatRouteOutcomes = 0;
    protected int32 _BatPerchLost = 0;
    protected int32 _BatTargetChanges = 0;
    protected int32 _BatDied = 0;
    protected int32 _BatDiedFrame = -1;
    protected int32 _BatDamaged = 0;
    protected TArray<EMars_Bat_SwoopCancel> _BatCancelReasons;
    protected TArray<FCk_Handle_HitZone> _BatLandedZones;

    // The server's prey stand-in's Health and zone, and how many times its Health raised OnDamaged.
    protected FCk_Handle_Health _PreyHealth;
    protected FCk_Handle_HitZone _PreyZone;
    protected int32 _PreyDamaged = 0;

    protected FMars_NetBatTest_Swoop _BatSwoop;
    // The frame the root was first sampled within 1 of its spawn place (the hang point, the row's offsets); -1 before.
    protected int32 _BatSettledFrame = -1;
    private TOptional<EMars_Bat_SwoopStage> _BatLastStage;
    private float32 _BatLastStageElapsed = 0.0f;
    private TOptional<FRotator> _BatLastTelegraphRotation;

    // The frame this machine found its copy and the copy's InitialState then, and off authority every ledger
    // rep-notify from then on with its frame.
    protected int32 _BatFoundFrame = -1;
    protected EMars_Net_InitialState _BatInitialAtFind = EMars_Net_InitialState::Awaited;
    protected TArray<int32> _BatNotifyFrames;
    protected TArray<FMars_Fragment_Bat_Net> _BatNotifyLedgers;

    protected float64 _BatLargestStep = 0.0;
    protected float64 _BatFarthestFromHang = 0.0;
    protected float32 _BatHighestSpeed = 0.0f;
    protected float32 _BatLargestTurnRate = 0.0f;
    protected float64 _BatLargestYawChange = 0.0;
    protected float64 _BatLowestHeight = 100000.0;
    private TOptional<FVector> _BatLastSample;
    private TOptional<float64> _BatLastYaw;
    private float64 _BatSampleUntil = 0.0;

    // The bake: requested, completed, and the frames and seconds between.
    private int32 _BakeStartFrame = -1;
    private float64 _BakeStartSeconds = 0.0;
    protected int32 _BakeFrames = -1;
    protected float64 _BakeSeconds = -1.0;
    private int32 _BakeCompletions = 0;
    private bool _BakeSucceeded = false;
    private FName _ServerContinuation;

    // A row without the striker: the floor point, the base and the target point at the hang point, the ensure count.
    protected void Begin_BatRow(FVector InFloor)
    {
        _Floor = InFloor;
        _HangAt = InFloor + FVector(0.0, 0.0, k_RoostHeight) + FMars_Bat_Roost().HangOffset;
        _Base = _HangAt;
        _TargetAt = _HangAt;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        _Spec = FMars_Bat_Spec();
    }

    // The strike row: the floor point, then the striker with its hand level with the hanging bat.
    protected void Begin_BatStrikeRow(FVector InFloor)
    {
        _Floor = InFloor;
        _HangAt = InFloor + FVector(0.0, 0.0, k_RoostHeight) + FMars_Bat_Roost().HangOffset;
        _Spec = FMars_Bat_Spec();
        Begin_Strike(_HangAt - FVector(0.0, 0.0, k_StrikeBaseUnderHang));
    }

    // The strike row with the striker's hand at the floor point plus InHandFromFloor.
    protected void Begin_BatStrikeRowAt(FVector InFloor, FVector InHandFromFloor)
    {
        _Floor = InFloor;
        _HangAt = InFloor + FVector(0.0, 0.0, k_RoostHeight) + FMars_Bat_Roost().HangOffset;
        _Spec = FMars_Bat_Spec();
        Begin_Strike(InFloor + InHandFromFloor - k_HandFromBase);
    }

    protected FVector Get_RoostAnchor() const
    {
        return _Floor + FVector(0.0, 0.0, k_RoostHeight);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the world, the bake, the bat, the prey
    //----------------------------------------------------------------------------------------------------------------------

    // Lays the world and runs, one wait at a time: every static in, the bake requested and done, the spawn owner
    // published, the bat spawned, found and (with the roost given) holding it; then InContinuation.
    protected void Begin_ServerWorld(FName InContinuation)
    {
        _ServerContinuation = InContinuation;
        auto Subject = Get_SubjectEntity();
        Spawn_BatStatic(FTransform(FRotator::ZeroRotator, _Floor - FVector(0.0, 0.0, k_BatFloorHalfExtents.Z)), k_BatFloorHalfExtents);

        _Roost = utils_entity_lifetime::Request_CreateEntity(Subject);
        utils_transform::Add(_Roost, FTransform(FRotator::ZeroRotator, Get_RoostAnchor()), ECk_Replication::DoesNotReplicate);
        utils_bat::Add_Roost(_Roost);

        auto VolumeOwner = utils_entity_lifetime::Request_CreateEntity(Subject);
        utils_transform::Add(VolumeOwner, FTransform(FRotator::ZeroRotator, _Floor), ECk_Replication::DoesNotReplicate);
        const auto Bounds = FBox(_Floor + FVector(-1200.0, -1200.0, -40.0), _Floor + FVector(1200.0, 1200.0, 760.0));
        _Volume = utils_bat::Add_FlightVolume(VolumeOwner,
            FMars_Bat_FlightVolume_Spec(Bounds, 40.0f, _Spec.Flight.AgentRadius, ECk_EnableDisable::Disable));

        WaitUntil(n"Is_BatStaticsIn", n"OnBatStaticsIn", k_SlowPolls);
    }

    // A static Jolt box owned by the subject; the server's chain waits for every one a row adds before
    // Begin_ServerWorld.
    protected void Spawn_BatStatic(FTransform InTransform, FVector InHalfExtents)
    {
        auto Box = utils_entity_lifetime::Request_CreateEntity(Get_SubjectEntity());
        utils_transform::Add(Box, InTransform, ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        _BatStatics.Add(utils_jolt_body::Add(Box, BoxSpec));
    }

    UFUNCTION()
    private void Is_BatStaticsIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllIn = true;
        for (auto Body : _BatStatics)
        {
            if (ck::Is_NOT_Valid(Body) || utils_jolt_body::Get_IsBodyAdded(Body) == false)
            { AllIn = false; }
        }

        auto Result = OutResult;
        Result.Set(AllIn);
    }

    UFUNCTION()
    private void OnBatStaticsIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _BakeStartFrame = int32(utils_time::Get_FrameCounter());
        _BakeStartSeconds = Get_BatWorldSeconds();
        utils_voxel_nav_volume::Request_Build(_Volume, FCk_Request_VoxelNavVolume_Build(),
            FCk_Delegate_Request_OnCompleted(this, n"OnBakeCompleted"));
        WaitUntil(n"Is_BakeDone", n"OnBakeDone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnBakeCompleted(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        _BakeCompletions += 1;
        _BakeSucceeded = InResult == ECk_Request_OperationResult::Succeeded;
        _BakeFrames = int32(utils_time::Get_FrameCounter()) - _BakeStartFrame;
        _BakeSeconds = Get_BatWorldSeconds() - _BakeStartSeconds;
    }

    UFUNCTION()
    private void Is_BakeDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_BakeCompletions > 0);
    }

    UFUNCTION()
    private void OnBakeDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_BakeSucceeded == false || utils_voxel_nav_volume::Get_IsBuilt(_Volume) == false)
        {
            Log_BatRow("bake", "");
            FinishFailure("the flight volume's bake failed");
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnBatOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnBatOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBat();
        WaitUntil(n"Is_ServerBatReady", _ServerContinuation, k_SlowPolls);
    }

    // The real script under the replicated spawn owner, the rig's volume in its spec; the held fixture when the row
    // set _HeldLedger.
    protected void Spawn_ServerBat()
    {
        auto Spec = _Spec;
        Spec.Volume = _Volume;
        if (_GivesRoost == ECk_EnableDisable::Enable)
        { Spec.Roost.PerchOwner = _Roost; }

        if (_HeldLedger.IsSet())
        {
            auto HeldParams = FMars_NetBat_Held_SpawnParams();
            HeldParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _HangAt + _SpawnOffset);
            HeldParams.Spec = Spec;
            HeldParams.WithVisuals = _WithVisuals;
            HeldParams.HeldLedger = _HeldLedger.GetValue();
            HeldParams.HeldRootOffset = _HeldRootOffset;
            utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
                UMars_NetBat_Held_EntityScript, HeldParams);
            return;
        }

        auto Params = UMars_CellarBat_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _HangAt + _SpawnOffset);
        Params.Spec = Spec;
        Params.WithVisuals = _WithVisuals;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_CellarBat_EntityScript, Params);
    }

    // Server: found and, with the roost given, holding it.
    UFUNCTION()
    protected void Is_ServerBatReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatFound() && Get_IsBatGone() == false
            && (_GivesRoost == ECk_EnableDisable::Disable || _Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Held));
    }

    // The mimic rig's prey stand-in at InOffset from the floor point (its root 90 up), owned by the subject: team One
    // (Hostile to the bat), Health 100, a flesh body zone with one box hurtbox, TAG_MarsSharedCombatTarget last. Its
    // Health and zone are kept and its Health's OnDamaged counted.
    protected void Spawn_ServerPrey(FVector InOffset)
    {
        auto Subject = Get_SubjectEntity();
        _PreyEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        auto Root = utils_transform::Add(_PreyEntity, FTransform(FRotator::ZeroRotator, _Floor + InOffset + FVector(0.0, 0.0, 90.0)),
            ECk_Replication::DoesNotReplicate);
        utils_team::Add(_PreyEntity, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _PreyHealth = utils_health::Add(_PreyEntity, FMars_Health_Spec(100.0f));
        _PreyHealth.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnPreyDamaged"));
        auto Zone = utils_hit_zone::Add(_PreyEntity, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        _PreyZone = Zone;
        utils_hit_zone::AddHurtbox_Box(Zone, Root, FMars_HitZone_Hurtbox(FVector(35.0, 35.0, 90.0), FTransform::Identity));
        utils_entity_tag::Add(_PreyEntity, n"TAG_MarsSharedCombatTarget");
    }

    // The prey's place for a row whose prey stands at InOffset from the floor point (its root, 90 up).
    protected FVector Get_PreyPlace(FVector InOffset) const
    {
        return _Floor + InOffset + FVector(0.0, 0.0, 90.0);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copy
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_BatFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBatFound());
    }

    // This machine's copy near the base has composed; the first time, its signals are counted from here, the frame is
    // kept, the server tracks it and a machine without authority records every ledger rep-notify.
    protected bool Get_IsBatFound()
    {
        if (ck::IsValid(_Bat))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), utils_bat::BatTag))
        {
            if (Get_IsNear(Candidate, _HangAt) == false)
            { continue; }

            auto Bat = Candidate.As_Bat(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Bat))
            { continue; }

            _Bat = Bat;
            _BatMonster = Bat.Get_Monster();
            _Target = Candidate;
            _Health = _BatMonster.Get_BodyHealth();
            _Zone = _BatMonster.Get_BodyZone();
            _BatFoundAt = Bat.Get_Location();
            _Bat.BindTo_OnPhaseChanged(FMars_Delegate_Bat_OnPhaseChanged(this, n"OnBatPhaseChanged"));
            _Bat.BindTo_OnSwoopLanded(FMars_Delegate_Bat_OnSwoopLanded(this, n"OnBatSwoopLanded"));
            _Bat.BindTo_OnSwoopCancelled(FMars_Delegate_Bat_OnSwoopCancelled(this, n"OnBatSwoopCancelled"));
            _Bat.BindTo_OnRouteOutcome(FMars_Delegate_Bat_OnRouteOutcome(this, n"OnBatRouteOutcome"));
            _Bat.BindTo_OnPerchLost(FMars_Delegate_Bat_OnPerchLost(this, n"OnBatPerchLost"));
            _Bat.BindTo_OnTargetChanged(FMars_Delegate_Bat_OnTargetChanged(this, n"OnBatTargetChanged"));
            _BatMonster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnBatDied"));
            _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnBatDamaged"));
            _BatFoundFrame = int32(utils_time::Get_FrameCounter());
            _BatInitialAtFind = Get_BatInitialState();
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            FCk_Handle Entity = _Bat;
            if (utils_net::Get_HasAuthority(Entity) == false)
            { Entity.BindTo_OnRepNotify(FMars_Fragment_Bat_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnBatLedgerNotify")); }

            Sample_Bat();
            return true;
        }

        return false;
    }

    UFUNCTION()
    protected void Is_BatGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBatGone());
    }

    // Unset, destroyed or being destroyed (a predicate that reads a copy returns quietly once this holds).
    protected bool Get_IsBatGone()
    {
        FCk_Handle Entity = _Bat;
        return ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    UFUNCTION()
    protected void Is_BatDead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatFound() && Get_IsBatGone() == false && _Bat.Get_IsDead());
    }

    protected bool Get_HasBatLedger()
    {
        return Get_IsBatGone() == false && _Bat.Has_Fragment(FMars_Fragment_Bat_Net);
    }

    // The copy's ledger; a default one when it has none (a row asserts Get_HasBatLedger first).
    protected FMars_Fragment_Bat_Net Get_BatLedger()
    {
        if (Get_HasBatLedger() == false)
        { return FMars_Fragment_Bat_Net(); }

        return _Bat.Get_Fragment(FMars_Fragment_Bat_Net);
    }

    // This machine's copy's level now; Awaited while there is none.
    protected EMars_Net_InitialState Get_BatInitialState()
    {
        if (Get_IsBatGone() || _Bat.Has_Fragment(FMars_Fragment_Bat_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Bat.Get_Fragment(FMars_Fragment_Bat_Local).InitialState;
    }

    // The ledger the first recorded rep-notify read; unset while none is recorded.
    protected TOptional<FMars_Fragment_Bat_Net> TryGet_BatFirstNotifyLedger() const
    {
        if (_BatNotifyLedgers.Num() == 0)
        { return TOptional<FMars_Fragment_Bat_Net>(); }

        return TOptional<FMars_Fragment_Bat_Net>(_BatNotifyLedgers[0]);
    }

    protected int32 Get_BatFirstNotifyFrame() const
    {
        if (_BatNotifyFrames.Num() == 0)
        { return -1; }

        return _BatNotifyFrames[0];
    }

    protected FString Describe_BatFind()
    {
        auto Notifies = FString();
        for (int32 Index = 0; Index < _BatNotifyFrames.Num(); ++Index)
        { Notifies += f"{_BatNotifyFrames[Index]}:{_BatNotifyLedgers[Index].Phase :n} "; }

        const auto PhaseClock = Get_IsBatGone() ? -1.0f : _Bat.Get_PhaseClock();
        return f"found@{_BatFoundFrame} initialAtFind={_BatInitialAtFind :n} initial={Get_BatInitialState() :n} notifies=[{Notifies}] phaseClock={PhaseClock}";
    }

    // The held fixture's frames on this machine's bat; "none" without it.
    protected FString Describe_BatHeld()
    {
        if (Get_IsBatGone() || _Bat.Has_Fragment(FMars_TESTONLY_Fragment_Bat_HeldLedger) == false)
        { return FString("none"); }

        const auto Held = _Bat.Get_Fragment(FMars_TESTONLY_Fragment_Bat_HeldLedger);
        return f"{Held.ConstructFrame} {Held.FirstHoldFrame}";
    }

    protected float64 Get_BatFromHang()
    {
        if (Get_IsBatGone())
        { return -1.0; }

        return (_Bat.Get_Location() - _HangAt).Size();
    }

    // One sample of this machine's copy.
    protected void Sample_Bat()
    {
        if (Get_IsBatGone())
        { return; }

        const auto Root = _Bat.Get_RootTransform();
        const auto Here = Root.GetLocation();
        const auto Yaw = Root.GetRotation().Rotator().Yaw;
        if (_BatLastSample.IsSet())
        { _BatLargestStep = Math::Max(_BatLargestStep, (Here - _BatLastSample.GetValue()).Size()); }

        if (_BatLastYaw.IsSet())
        { _BatLargestYawChange = Math::Max(_BatLargestYawChange, Math::Abs(Math::FindDeltaAngleDegrees(_BatLastYaw.GetValue(), Yaw))); }

        _BatLastSample = Here;
        _BatLastYaw = Yaw;
        _BatFarthestFromHang = Math::Max(_BatFarthestFromHang, (Here - _HangAt).Size());
        _BatLowestHeight = Math::Min(_BatLowestHeight, Here.Z - _Floor.Z);

        const auto Telemetry = _Bat.Get_Telemetry();
        _BatHighestSpeed = Math::Max(_BatHighestSpeed, Telemetry.Speed);
        _BatLargestTurnRate = Math::Max(_BatLargestTurnRate, Math::Abs(Telemetry.SignedTurnRate));
        _BatSwoop.LowestPitch = Math::Min(_BatSwoop.LowestPitch, Telemetry.Pitch);

        if (_BatSettledFrame < 0 && (Here - (_HangAt + _SpawnOffset + _HeldRootOffset)).Size() <= 1.0)
        { _BatSettledFrame = int32(utils_time::Get_FrameCounter()); }

        Sample_BatSwoop(Root);
    }

    private void Sample_BatSwoop(FTransform InRoot)
    {
        const auto Frame = _Bat.Get_SwoopFrame();
        const auto Elapsed = _Bat.Get_SwoopLedger().StageElapsed;
        if (_BatLastStage.IsSet() == false || _BatLastStage.GetValue() != Frame.Stage)
        { _BatSwoop.Stages.Add(Frame.Stage); }
        else if (Elapsed < _BatLastStageElapsed)
        { _BatSwoop.Rewinds += 1; }

        _BatLastStage = Frame.Stage;
        _BatLastStageElapsed = Elapsed;

        if (Frame.Stage == EMars_Bat_SwoopStage::Telegraphing)
        { Add_AlphaSample(_BatSwoop.Telegraph, Frame.Alpha); }
        else if (Frame.Stage == EMars_Bat_SwoopStage::Committed)
        { Add_AlphaSample(_BatSwoop.Dive, Frame.Alpha); }
        else if (Frame.Stage == EMars_Bat_SwoopStage::Recovering)
        { Add_AlphaSample(_BatSwoop.Recover, Frame.Alpha); }

        if (Frame.Stage != EMars_Bat_SwoopStage::Telegraphing || _FacingPoint.IsSet() == false)
        { return; }

        const auto Rotation = InRoot.GetRotation().Rotator();
        const auto Bearing = (_FacingPoint.GetValue() - InRoot.GetLocation()).Rotation();
        auto Facing = FMars_NetBatTest_Facing();
        Facing.Yaw = Math::Abs(Math::FindDeltaAngleDegrees(Rotation.Yaw, Bearing.Yaw));
        Facing.Pitch = Math::Abs(Math::FindDeltaAngleDegrees(Rotation.Pitch, Math::Clamp(Bearing.Pitch, -50.0, 20.0)));
        if (_BatSwoop.FacingSamples == 0)
        { _BatSwoop.FacingFirst = Facing; }

        _BatSwoop.FacingLast = Facing;
        _BatSwoop.FacingSamples += 1;

        if (_BatLastTelegraphRotation.IsSet())
        {
            const auto Last = _BatLastTelegraphRotation.GetValue();
            _BatSwoop.Turned += Math::Abs(Math::FindDeltaAngleDegrees(Last.Yaw, Rotation.Yaw))
                + Math::Abs(Math::FindDeltaAngleDegrees(Last.Pitch, Rotation.Pitch));
        }

        _BatLastTelegraphRotation = Rotation;
    }

    private void Add_AlphaSample(FMars_NetBatTest_AlphaRange& InOutRange, float32 InAlpha)
    {
        if (InOutRange.Samples == 0)
        {
            InOutRange.Highest = InAlpha;
            InOutRange.Lowest = InAlpha;
        }

        InOutRange.Highest = Math::Max(InOutRange.Highest, InAlpha);
        InOutRange.Lowest = Math::Min(InOutRange.Lowest, InAlpha);
        InOutRange.Samples += 1;
    }

    // The sampled stages are exactly InExpected, in that order.
    protected bool Get_SampledStagesAre(const TArray<EMars_Bat_SwoopStage>& InExpected) const
    {
        if (_BatSwoop.Stages.Num() != InExpected.Num())
        { return false; }

        for (auto Index = 0; Index < InExpected.Num(); ++Index)
        {
            if (_BatSwoop.Stages[Index] != InExpected[Index])
            { return false; }
        }

        return true;
    }

    // InExpected appears among the sampled stages in this order (other stages may come between).
    protected bool Get_SampledStagesInOrder(const TArray<EMars_Bat_SwoopStage>& InExpected) const
    {
        auto Next = 0;
        for (const auto& Sampled : _BatSwoop.Stages)
        {
            if (Next < InExpected.Num() && Sampled == InExpected[Next])
            { ++Next; }
        }

        return Next == InExpected.Num();
    }

    protected EMars_Bat_SwoopStage Get_LastSampledStage() const
    {
        if (_BatSwoop.Stages.Num() == 0)
        { return EMars_Bat_SwoopStage::None; }

        return _BatSwoop.Stages[_BatSwoop.Stages.Num() - 1];
    }

    protected FString Describe_Stages() const
    {
        FString Text = "";
        for (const auto& Sampled : _BatSwoop.Stages)
        { Text += f"{Sampled :n},"; }

        return Text;
    }

    protected FString Describe_BatSwoop()
    {
        const auto IsFound = Get_IsBatGone() == false;
        const auto Frame = IsFound ? _Bat.Get_SwoopFrame() : FMars_Bat_SwoopFrame();
        const auto Ledger = IsFound ? _Bat.Get_SwoopLedger() : FMars_Bat_SwoopLedger();
        FString Reasons = "";
        for (const auto& Reason : _BatCancelReasons)
        { Reasons += f"{Reason :n},"; }

        const auto PreyHealth = ck::IsValid(_PreyHealth) ? _PreyHealth.Get_Current() : -1.0f;
        const auto& S = _BatSwoop;
        return f"swoop=[stage {Frame.Stage :n} alpha {Frame.Alpha} elapsed {Ledger.StageElapsed} stages {Describe_Stages()} "
            + f"highest {S.Telegraph.Highest}/{S.Dive.Highest}/{S.Recover.Highest} lowest {S.Telegraph.Lowest}/{S.Dive.Lowest}/{S.Recover.Lowest} "
            + f"rewinds {S.Rewinds} facingFirst {S.FacingFirst.Yaw}/{S.FacingFirst.Pitch} facingLast {S.FacingLast.Yaw}/{S.FacingLast.Pitch} "
            + f"turned {S.Turned} lowestPitch {S.LowestPitch} reasons {Reasons} generation {Ledger.Generation} landed {Ledger.Landed} "
            + f"prey {PreyHealth}/{_PreyDamaged} rootAtFind {_BatFoundAt.ToString()} settledFrame {_BatSettledFrame}]";
    }

    // A wall-clock settle that keeps sampling the copy every frame, then InContinuation.
    protected void WaitSampling(float32 InSeconds, FName InContinuation)
    {
        _BatSampleUntil = Get_BatWorldSeconds() + InSeconds;
        WaitUntil(n"Is_BatSampledLongEnough", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_BatSampledLongEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_BatWorldSeconds() >= _BatSampleUntil);
    }

    protected float64 Get_BatWorldSeconds()
    {
        const auto SubjectWorld = utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
        return float64(SubjectWorld.GetTimeSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The recorded phases
    //----------------------------------------------------------------------------------------------------------------------

    // InExpected appears among the recorded arrivals in this order (other phases may come between).
    protected bool Get_SawPhasesInOrder(const TArray<EMars_Bat_Phase>& InExpected) const
    {
        auto Next = 0;
        for (const auto& Recorded : _BatPhases)
        {
            if (Next < InExpected.Num() && Recorded.To == InExpected[Next])
            { ++Next; }
        }

        return Next == InExpected.Num();
    }

    // The recorded arrivals are exactly InExpected, each change's From the To of the one before.
    protected bool Get_SawExactlyPhases(const TArray<EMars_Bat_Phase>& InExpected) const
    {
        if (_BatPhases.Num() != InExpected.Num())
        { return false; }

        for (auto Index = 0; Index < _BatPhases.Num(); ++Index)
        {
            if (_BatPhases[Index].To != InExpected[Index])
            { return false; }

            if (Index > 0 && _BatPhases[Index].From != _BatPhases[Index - 1].To)
            { return false; }
        }

        return true;
    }

    protected int32 Count_PhaseArrivals(EMars_Bat_Phase InPhase) const
    {
        auto Count = 0;
        for (const auto& Recorded : _BatPhases)
        {
            if (Recorded.To == InPhase)
            { ++Count; }
        }

        return Count;
    }

    // A Roosting was recorded after a Perching.
    protected bool Get_HasRoostedAfterPerching() const
    {
        auto PerchedAt = -1;
        for (auto Index = 0; Index < _BatPhases.Num(); ++Index)
        {
            if (_BatPhases[Index].To == EMars_Bat_Phase::Perching && PerchedAt < 0)
            { PerchedAt = Index; }

            if (PerchedAt >= 0 && Index > PerchedAt && _BatPhases[Index].To == EMars_Bat_Phase::Roosting)
            { return true; }
        }

        return false;
    }

    protected FString Describe_BatPhases() const
    {
        FString Text = "";
        for (const auto& Recorded : _BatPhases)
        { Text += f"{Recorded.From :n}>{Recorded.To :n}@{Recorded.Frame},"; }

        return Text;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line and the finish
    //----------------------------------------------------------------------------------------------------------------------

    protected void Log_BatRow(FString InRow, FString InExtra)
    {
        const auto IsFound = Get_IsBatGone() == false;
        const auto Phase = IsFound ? f"{_Bat.Get_Phase() :n}" : FString("gone");
        const auto Location = IsFound ? _Bat.Get_Location() : FVector::ZeroVector;
        const auto Anchor = IsFound ? _Bat.Get_PerchAnchor() : FVector::ZeroVector;
        FString LedgerText = "none";
        if (IsFound && Get_HasBatLedger())
        {
            const auto Ledger = Get_BatLedger();
            LedgerText = f"{Ledger.Phase :n} {Ledger.PerchAnchor.ToString()}";
        }

        FString HandlesText = "none";
        if (IsFound)
        {
            FCk_Handle Root = _Bat;
            const auto Perch = _Bat.Get_Fragment(FMars_Fragment_Bat).Perch;
            const auto Shown = Perch.ShownAnchor.IsSet() ? Perch.ShownAnchor.GetValue().ToString() : FString("unset");
            HandlesText = f"agent {ck::IsValid(_Bat.Get_Agent())} path {ck::IsValid(_Bat.Get_Path())} dealer {ck::IsValid(_Bat.Get_Dealer())} volume {ck::IsValid(_Bat.Get_Volume())} target {ck::IsValid(_Bat.Get_Target())} sm {ck::IsValid(Root.As_StateMachine(ECk_SanityCheck::UnChecked))} claim {Perch.Claim :n} owner {ck::IsValid(Perch.Owner)} shown {Shown} authority {utils_net::Get_HasAuthority(Root)} hits {_Bat.Get_Hurt().HitCount}";
        }

        const auto Body = IsFound && ck::IsValid(_Health) ? _Health.Get_Current() : -1.0f;
        const auto Phases = Describe_BatPhases();
        const auto Line = f"[BatNetTest] {InRow} {Get_MachineName()} phase={Phase} root={Location.ToString()} anchor={Anchor.ToString()} ledger=[{LedgerText}] phases=[{Phases}] landed={_BatSwoopsLanded} cancelled={_BatSwoopsCancelled} routes={_BatRouteOutcomes} perchLost={_BatPerchLost} targets={_BatTargetChanges} died={_BatDied} diedFrame={_BatDiedFrame} damaged={_BatDamaged} body={Body} largestStep={_BatLargestStep} farthestFromHang={_BatFarthestFromHang} highestSpeed={_BatHighestSpeed} largestTurn={_BatLargestTurnRate} largestYawChange={_BatLargestYawChange} lowestHeight={_BatLowestHeight} handles=[{HandlesText}] bake=[frames {_BakeFrames} seconds {_BakeSeconds}] ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra} {Describe_BatFind()} held=[{Describe_BatHeld()}] {Describe_BatSwoop()}";
        Log(Line);
    }

    // Off authority: the copy raised none of the authority's swoop and target signals and keeps none of its swoop but
    // the stage it shows (no generation, no blow, no cancel, no target, no dealer).
    protected void Assert_CopyKeepsNoSwoopOfItsOwn()
    {
        Assert_Equals_Int(_BatSwoopsLanded, 0, "the client raised no OnSwoopLanded");
        Assert_Equals_Int(_BatSwoopsCancelled, 0, "the client raised no OnSwoopCancelled");
        Assert_Equals_Int(_BatTargetChanges, 0, "the client raised no OnTargetChanged");
        if (Get_IsBatGone())
        {
            Assert_True(false, "the client's copy is there to read");
            return;
        }

        const auto Ledger = _Bat.Get_SwoopLedger();
        Assert_False(ck::IsValid(_Bat.Get_Target()), "the client's copy holds no target");
        Assert_False(ck::IsValid(_Bat.Get_Dealer()), "the client's copy has no dealer");
        Assert_Equals_Int(Ledger.Generation, 0, "the client's swoop ledger reads generation 0");
        Assert_Equals_Int(Ledger.Landed, 0, "the client's swoop ledger landed nothing");
        Assert_Equals_Int(Ledger.Cancelled, 0, "the client's swoop ledger cancelled nothing");
    }

    // At this machine's last telegraph sample the root faced the facing point within InDegrees on yaw and pitch.
    protected void Assert_FacedTheFacingPoint(float64 InDegrees)
    {
        const auto& Last = _BatSwoop.FacingLast;
        Assert_True(_BatSwoop.FacingSamples > 0, f"the {Get_MachineName()} sampled its telegraph's facing");
        Assert_True(Last.Yaw >= 0.0 && Last.Yaw <= InDegrees, f"the {Get_MachineName()}'s yaw error at its last telegraph sample is {InDegrees} or less (reads {Last.Yaw})");
        Assert_True(Last.Pitch >= 0.0 && Last.Pitch <= InDegrees, f"the {Get_MachineName()}'s pitch error at its last telegraph sample is {InDegrees} or less (reads {Last.Pitch})");
    }

    protected void Finish_BatRow(FString InRow, FString InExtra)
    {
        Log_BatRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_BatServerRow(FString InRow, FString InExtra)
    {
        Log_BatRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnBatPhaseChanged(FCk_Handle_Bat InBat, EMars_Bat_Phase InFrom, EMars_Bat_Phase InTo)
    {
        auto Recorded = FMars_NetBatTest_Phase();
        Recorded.From = InFrom;
        Recorded.To = InTo;
        Recorded.Frame = int32(utils_time::Get_FrameCounter());
        _BatPhases.Add(Recorded);
    }

    UFUNCTION()
    private void OnBatSwoopLanded(FCk_Handle_Bat InBat, int32 InGeneration, FCk_Handle_HitZone InZone)
    {
        _BatSwoopsLanded += 1;
        _BatLandedZones.Add(InZone);
    }

    UFUNCTION()
    private void OnBatSwoopCancelled(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_SwoopCancel InReason)
    {
        _BatSwoopsCancelled += 1;
        _BatCancelReasons.Add(InReason);
    }

    UFUNCTION()
    private void OnPreyDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _PreyDamaged += 1;
    }

    UFUNCTION()
    private void OnBatRouteOutcome(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_RouteOutcome InOutcome)
    {
        _BatRouteOutcomes += 1;
    }

    UFUNCTION()
    private void OnBatPerchLost(FCk_Handle_Bat InBat, FCk_Handle InOwner)
    {
        _BatPerchLost += 1;
    }

    UFUNCTION()
    private void OnBatTargetChanged(FCk_Handle_Bat InBat, FCk_Handle InTarget)
    {
        _BatTargetChanges += 1;
    }

    UFUNCTION()
    private void OnBatDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        _BatDied += 1;
        if (_BatDiedFrame < 0)
        { _BatDiedFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnBatDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _BatDamaged += 1;
    }

    // A notify can land on a bat already ending.
    UFUNCTION()
    private void OnBatLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Bat_Net) == false)
        { return; }

        _BatNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BatNotifyLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Bat_Net));
    }
}
