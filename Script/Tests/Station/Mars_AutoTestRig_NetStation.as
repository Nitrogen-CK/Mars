// The station net tests' shared steps. The subject composes the Operator feature on both machines, as the pawn does. The
// server spawns a bare test station (the base station's composition and nothing else, tagged so each machine finds its
// copy) and, for the tests that need a second operator, a replicated operator entity, both under the replicated spawn
// owner. Each machine counts the OnReserved, OnReleased and OnReserveRejected its own copy of the station raises.

// The bare test station, tagged on its root: no meshes, no label, no probe, so only the reservation is under test.
class UMars_TESTONLY_NetStation_EntityScript : UMars_TESTONLY_Station_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        utils_entity_tag::Add(InRoot.H(), n"TAG_MarsTestNetStation");
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
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Params = FMars_TESTONLY_StationSpawnParams(FTransform(FRotator::ZeroRotator, InLocation), FMars_Station_Spec());
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetStation_EntityScript, Params);
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
    }

    UFUNCTION()
    private void OnStationReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        _Released.Add(InOperator);
        _ReleaseReasons.Add(InReason);
    }

    UFUNCTION()
    private void OnStationReserveRejected(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        _Rejected.Add(InOperator);
        _RejectReasons.Add(InReason);
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }
}
