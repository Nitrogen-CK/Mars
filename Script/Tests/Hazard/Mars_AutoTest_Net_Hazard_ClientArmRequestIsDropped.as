// A client's arm request on its copy of a hazard is dropped by the drain: the hazard stays disarmed on every machine.
// Surface: Ck.Hazard.Net.AS_Hazard_ClientArmRequestIsDropped
class UCk_AutoTest_Net_Hazard_ClientArmRequestIsDropped : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 12.0f;

    private const float32 k_ServerWatchSeconds = 3.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const int32 k_SlowPolls = 5000;

    // Far from anything else the harness world holds.
    private const float64 k_TrapX = 10000.0;

    private FCk_Handle_PendingEntityScript _PendingTrap;
    private FCk_Handle_Trap _Trap;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_TrapOnThisMachine", n"OnClientTrapArrived", k_SlowPolls);
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

    // Never running, so nothing on the server ever arms it.
    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = utils_trap::Make_SpikeTrapSpec();
        Spec.Cycle.StartRunning = false;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_SpikeTrap_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(k_TrapX, 0.0, 0.0));
        Params.Trap = Spec;
        _PendingTrap = utils_entity_script::Request_SpawnEntity(Owner, UMars_SpikeTrap_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingTrap, FCk_Delegate_EntityScript_Constructed(this, n"OnServerTrapConstructed"));
    }

    UFUNCTION()
    private void OnServerTrapConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingTrap = FCk_Handle_PendingEntityScript();
        _Trap = FCk_Handle(InEntityScriptHandle).As_Trap();
        Track_ForCleanup(_Trap);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Trap.Get_Hazard().Get_IsArmed(), "the server's hazard stays disarmed");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_TrapOnThisMachine(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Trap = DoFind_Trap();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Trap));
    }

    UFUNCTION()
    private void OnClientTrapArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Trap), "the client's trap has no authority");

        auto Hazard = _Trap.Get_Hazard();
        Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Armed));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Hazard = _Trap.Get_Hazard();
        Assert_False(Hazard.Get_IsArmed(), "the client's arm request did not arm its copy");
        Assert_False(Hazard.Has_Fragment(FMars_Fragment_Hazard_Requests), "the drain consumed the client's request");
        FinishSuccess();
    }

    private FCk_Handle_Trap DoFind_Trap()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsSpikeTrap"))
        { return Candidate.As_Trap(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Trap();
    }
}
