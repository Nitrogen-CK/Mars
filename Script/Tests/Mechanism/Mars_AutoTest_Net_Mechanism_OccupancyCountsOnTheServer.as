// A pressure plate counts on the server: an occupant that exists only on the server stands on it, and the client,
// whose own trigger holds nobody, receives the count and the activation and sinks its own slab from them.
// Surface: Ck.Mechanism.Net.AS_Mechanism_OccupancyCountsOnTheServer
class UCk_AutoTest_Net_Mechanism_OccupancyCountsOnTheServer : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_ServerHoldSeconds = 2.0f;
    private const int32 k_SlowPolls = 5000;

    // Far from anything else the harness world holds.
    private const float64 k_PlateX = 8000.0;

    private FCk_Handle_PendingEntityScript _PendingPlate;
    private FCk_Handle_Occupancy _Occupancy;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_PlateOnClient", n"OnClientPlateArrived", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // Spawned under the replicated spawn owner, as every runtime replicated spawn is; it hangs off the pooled channel,
    // not this runner, so it is tracked for cleanup.
    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_PressurePlate_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(k_PlateX, 0.0, 0.0));
        _PendingPlate = utils_entity_script::Request_SpawnEntity(Owner, UMars_PressurePlate_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingPlate, FCk_Delegate_EntityScript_Constructed(this, n"OnServerPlateConstructed"));
    }

    UFUNCTION()
    private void OnServerPlateConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingPlate = FCk_Handle_PendingEntityScript();
        _Occupancy = FCk_Handle(InEntityScriptHandle).As_Occupancy();
        Track_ForCleanup(_Occupancy);

        // Local to the server and under the subject: nothing about it can reach the client.
        auto Occupant = MakeOccupant(Get_SubjectEntity(), FVector(k_PlateX, 0.0, 30.0));
        Track_ForCleanup(Occupant);
        WaitUntil(n"Is_ServerPlateActive", n"OnServerPlateActive", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPlateActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Occupancy.Get_IsActive());
    }

    UFUNCTION()
    private void OnServerPlateActive(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_PlateOnClient(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Occupancy = DoFind_Occupancy();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Occupancy));
    }

    UFUNCTION()
    private void OnClientPlateArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Occupancy), "the client's plate has no authority");
        WaitUntil(n"Is_ClientCountedAndSunk", n"OnClientConverged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientCountedAndSunk(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Mover = _Occupancy.Get_Mover();
        Result.Set(_Occupancy.Get_Count() == 1 && _Occupancy.Get_IsActive() && ck::IsValid(Mover) && Mover.Get_Alpha() > 0.5f);
    }

    UFUNCTION()
    private void OnClientConverged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    private FCk_Handle_Occupancy DoFind_Occupancy()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsPressurePlate"))
        { return Candidate.As_Occupancy(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Occupancy();
    }

    // A kinematic player-filtered probe: what the plate's default trigger detects.
    private FCk_Handle_Transform MakeOccupant(FCk_Handle InOwner, FVector InLocation)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InOwner);
        Owner.Request_OverrideToSelf();
        auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(Root, 30.0f, ProbeSpec);
        return Root;
    }
}
