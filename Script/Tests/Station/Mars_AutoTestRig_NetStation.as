// The station net tests' shared steps. The subject composes the Operator feature on both machines, as the pawn does. The
// server spawns a bare test station (the base station's composition and nothing else, tagged so each machine finds its
// copy) and, for the tests that need a second operator, a replicated operator entity, both under the replicated spawn
// owner. Each machine counts the OnReserved, OnReleased and OnReserveRejected its own copy of the station raises, with
// the frame of each; a client that watches its station also records the rep-notifies of the ledger.

// The bare test station, tagged on its root: no meshes, no label, no probe, so only the reservation is under test.
class UMars_TESTONLY_NetStation_EntityScript : UMars_TESTONLY_Station_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        utils_entity_tag::Add(InRoot.H(), n"TAG_MarsTestNetStation");
    }
}

// A harness fixture: the bare test station whose authority, as it composes, asks to reserve it for the first two live
// test operators in that order, so its arbiter seats the first and refuses the second Occupied in the spawn frame. A
// copy is born into a held station with one refusal.
class UMars_TESTONLY_NetStation_BornHeldAndRefused_EntityScript : UMars_TESTONLY_NetStation_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return Flow; }

        // A rejected station already ensured in utils_station::Add.
        auto Station = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Station))
        { return Flow; }

        auto Operators = TArray<FCk_Handle>();
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsTestNetOperator"))
        {
            if (ck::Is_NOT_Valid(Candidate.As_Operator(ECk_SanityCheck::UnChecked))
                || utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            Operators.Add(Candidate);
        }

        if (ck::EnsureIfNot(Operators.Num() >= 2, f"[StationNetTest] the born station found {Operators.Num()} live test operators, not two"))
        { return Flow; }

        Station.Request_Reserve(FMars_Request_Station_Reserve(Operators[0]));
        Station.Request_Reserve(FMars_Request_Station_Reserve(Operators[1]));
        return Flow;
    }
}

// A replicated entity that can operate a station: the Operator feature on every machine, tagged so each finds its copy.
class UMars_TESTONLY_NetOperator_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity, its transform and its back-ref replicate.
    default _Replication = ECk_Replication::Replicates;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, FTransform::Identity, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetOperator");
        utils_operator::Add(InHandle);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetStation : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 20.0f;

    protected const int32 k_SlowPolls = 5000;
    protected const float32 k_ServerHoldSeconds = 2.0f;
    // Long enough for a replicated ledger and the requests its signals queue to land.
    protected const float32 k_SettleSeconds = 1.0f;

    protected FCk_Handle_Station _Station;
    protected FCk_Handle_Operator _SecondOperator;
    protected int32 _EnsuresAtStart = 0;

    protected TArray<FCk_Handle> _Reserved;
    protected TArray<FCk_Handle> _Released;
    protected TArray<EMars_Station_ReleaseReason> _ReleaseReasons;
    protected TArray<FCk_Handle> _Rejected;
    protected TArray<EMars_Station_RejectReason> _RejectReasons;
    // In parallel with _Reserved, _Rejected and _Released: the frame counter at each.
    protected TArray<int64> _ReservedFrames;
    protected TArray<int64> _RejectedFrames;
    protected TArray<int64> _ReleasedFrames;

    // The live tagged test operators this machine has found.
    protected TArray<FCk_Handle_Operator> _Operators;
    // When Is_StationFoundAndWatched first found this machine's station: the frame counter and the ledger as it read.
    protected int64 _StationFoundFrame = -1;
    protected FMars_Fragment_Station _StationLedgerAtFind;
    // The station's InitialState as this machine read it when it found the station.
    protected EMars_Net_InitialState _StationInitialAtFind = EMars_Net_InitialState::Awaited;
    // Off authority: each rep-notify of the station's ledger, its frame counter and the ledger as it then read.
    protected TArray<int64> _StationNotifyFrames;
    protected TArray<FMars_Fragment_Station> _StationNotifyLedgers;

    // Both machines, first thing: the ensure count and the subject's Operator feature.
    protected void Begin_NetStationTest()
    {
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        auto Subject = Get_SubjectEntity();
        utils_operator::Add(Subject);
    }

    protected FCk_Handle_Operator Get_SubjectOperator()
    {
        return Get_SubjectEntity().As_Operator();
    }

    // Server: the station at InLocation, under the spawn owner.
    protected void Spawn_ServerStation(FVector InLocation)
    {
        Spawn_ServerStationOfClass(InLocation, UMars_TESTONLY_NetStation_EntityScript);
    }

    // Server: a station of InClass (the bare test station or a subclass) at InLocation, under the spawn owner.
    protected void Spawn_ServerStationOfClass(FVector InLocation, TSubclassOf<UCk_EntityScript_UE> InClass)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Params = FMars_TESTONLY_StationSpawnParams(FTransform(FRotator::ZeroRotator, InLocation), FMars_Station_Spec());
        utils_entity_script::Request_SpawnEntity(Owner, InClass, Params);
    }

    // Server: a second operator, under the spawn owner.
    protected void Spawn_ServerOperator()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetOperator_EntityScript, FInstancedStruct());
    }

    // This machine's station has composed; the first time, its signals are counted from here (and the server tracks it).
    protected bool Get_IsStationFound()
    {
        if (ck::IsValid(_Station))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetStation"))
        {
            auto Station = Candidate.As_Station(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Station))
            { continue; }

            _Station = Station;
            _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnStationReserved"));
            _Station.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnStationReleased"));
            _Station.BindTo_OnReserveRejected(FMars_Delegate_Station_OnReserveRejected(this, n"OnStationReserveRejected"));
            if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // This machine's second operator has composed (the server tracks it).
    protected bool Get_IsSecondOperatorFound()
    {
        if (ck::IsValid(_SecondOperator))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetOperator"))
        {
            auto Operator = Candidate.As_Operator(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Operator))
            { continue; }

            _SecondOperator = Operator;
            if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // This machine has found two live tagged test operators (the server tracks each).
    protected bool Get_AreTwoOperatorsFound()
    {
        if (_Operators.Num() >= 2)
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetOperator"))
        {
            auto Operator = Candidate.As_Operator(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Operator)
                || utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            auto IsKnown = false;
            for (const auto& Known : _Operators)
            {
                if (Known == Operator)
                { IsKnown = true; }
            }

            if (IsKnown)
            { continue; }

            _Operators.Add(Operator);
            if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(Candidate); }
        }

        return _Operators.Num() >= 2;
    }

    // Get_IsStationFound; the first time it holds, the frame, the ledger as it reads then and, off authority, a record
    // of every later rep-notify of the ledger.
    protected bool Get_IsStationFoundAndWatched()
    {
        if (Get_IsStationFound() == false)
        { return false; }

        if (_StationFoundFrame >= 0)
        { return true; }

        _StationFoundFrame = utils_time::Get_FrameCounter();
        _StationLedgerAtFind = _Station.Get_Fragment(FMars_Fragment_Station);
        _StationInitialAtFind = Get_StationInitialState();
        if (utils_net::Get_HasAuthority(Get_SubjectEntity()) == false)
        {
            FCk_Handle Entity = _Station;
            Entity.BindTo_OnRepNotify(FMars_Fragment_Station, FCk_DynamicFragment_OnRepNotify(this, n"OnRigStationLedgerNotify"));
        }

        return true;
    }

    // This machine's station's level now; Awaited while there is none.
    protected EMars_Net_InitialState Get_StationInitialState()
    {
        if (ck::Is_NOT_Valid(_Station) || _Station.Has_Fragment(FMars_Fragment_Station_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Station.Get_Fragment(FMars_Fragment_Station_Local).InitialState;
    }

    // The ledger the first recorded rep-notify read; the composed default while none is recorded.
    protected FMars_Fragment_Station Get_FirstStationNotifyLedger() const
    {
        if (_StationNotifyLedgers.Num() == 0)
        { return FMars_Fragment_Station(); }

        return _StationNotifyLedgers[0];
    }

    protected int64 Get_FirstStationNotifyFrame() const
    {
        if (_StationNotifyFrames.Num() == 0)
        { return -1; }

        return _StationNotifyFrames[0];
    }

    protected FString Describe_StationFind()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _StationNotifyFrames.Num(); ++Index)
        {
            const auto& Ledger = _StationNotifyLedgers[Index];
            Notifies += f"{_StationNotifyFrames[Index]}:{Ledger.Occupancy :n}/{Ledger.ReleaseSerial}/{Ledger.RefusalSerial} ";
        }

        auto Events = "";
        for (const auto Frame : _ReservedFrames)
        { Events += f"Reserved@{Frame} "; }

        for (const auto Frame : _RejectedFrames)
        { Events += f"Rejected@{Frame} "; }

        for (const auto Frame : _ReleasedFrames)
        { Events += f"Released@{Frame} "; }

        const auto HolderResolved = ck::IsValid(utils_station::Get_HeldBy(Get_FirstStationNotifyLedger()));
        return f"found@{_StationFoundFrame} initialAtFind={_StationInitialAtFind :n} initial={Get_StationInitialState() :n} "
            + f"notifies=[{Notifies}] events=[{Events}] holderResolved={HolderResolved}";
    }

    // Both ends of the link name each other on this machine.
    protected bool Get_IsHeldBy(FCk_Handle_Operator InOperator)
    {
        return ck::IsValid(_Station) && ck::IsValid(InOperator) && _Station.Get_IsOperatedBy(InOperator)
            && InOperator.Get_Station() == _Station;
    }

    // Neither end names anyone on this machine.
    protected bool Get_IsFreeOf(FCk_Handle_Operator InOperator)
    {
        return ck::IsValid(_Station) && _Station.Get_IsOperated() == false
            && (ck::Is_NOT_Valid(InOperator) || ck::Is_NOT_Valid(InOperator.Get_Station()));
    }

    protected bool Get_UseIsClaimed()
    {
        return _Station.Get_Interactable().Get_IsDisabledFor(EMars_Interactable_DisableReason::Operated);
    }

    UFUNCTION()
    protected void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    UFUNCTION()
    protected void Is_StationFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFound());
    }

    UFUNCTION()
    protected void Is_StationFoundAndWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFoundAndWatched());
    }

    UFUNCTION()
    protected void Is_TwoOperatorsFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_AreTwoOperatorsFound());
    }

    UFUNCTION()
    protected void Is_StationAndSecondOperatorFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFound() && Get_IsSecondOperatorFound());
    }

    UFUNCTION()
    protected void Is_HeldBySubject(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFound() && Get_IsHeldBy(Get_SubjectOperator()));
    }

    UFUNCTION()
    protected void Is_HeldBySecond(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFound() && Get_IsSecondOperatorFound() && Get_IsHeldBy(_SecondOperator));
    }

    UFUNCTION()
    protected void Is_FreeOfSubject(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFound() && Get_IsFreeOf(Get_SubjectOperator()));
    }

    UFUNCTION()
    protected void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void OnStationReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        _Reserved.Add(InOperator);
        _ReservedFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnStationReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        _Released.Add(InOperator);
        _ReleaseReasons.Add(InReason);
        _ReleasedFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnStationReserveRejected(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        _Rejected.Add(InOperator);
        _RejectReasons.Add(InReason);
        _RejectedFrames.Add(utils_time::Get_FrameCounter());
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnRigStationLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Station) == false)
        { return; }

        _StationNotifyFrames.Add(utils_time::Get_FrameCounter());
        _StationNotifyLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Station));
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }
}
