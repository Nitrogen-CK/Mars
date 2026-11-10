// A client that calls the gate's request mixin on its own copy changes nothing anywhere: the gate's request drain is
// authority-gated and drops the client's requests, and nothing the client wrote crosses the wire.
// Surface: Ck.Mechanism.Net.AS_Mechanism_ClientRequestIsDropped
class UCk_AutoTest_Net_Mechanism_ClientRequestIsDropped : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 12.0f;

    // Long enough for the client to find the gate, request, and watch it stay shut.
    private const float32 k_ServerWatchSeconds = 5.0f;

    // A wrongful open would have landed and travelled the leaf by now.
    private const float32 k_ClientWatchSeconds = 1.5f;

    private const int32 k_SlowPolls = 3000;

    private FCk_Handle_PendingEntityScript _PendingGate;
    private FCk_Handle_Gate _Gate;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_GateOnClient", n"OnClientGateArrived", k_SlowPolls);
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
        auto Params = UMars_Gate_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(6000.0, 0.0, 0.0));
        _PendingGate = utils_entity_script::Request_SpawnEntity(Owner, UMars_Gate_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingGate, FCk_Delegate_EntityScript_Constructed(this, n"OnServerGateConstructed"));
    }

    UFUNCTION()
    private void OnServerGateConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingGate = FCk_Handle_PendingEntityScript();
        _Gate = FCk_Handle(InEntityScriptHandle).As_Gate();
        Track_ForCleanup(_Gate);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Gate.Get_IsOpen(), "the server's gate is still closed");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_GateOnClient(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(DoFind_Gate()));
    }

    UFUNCTION()
    private void OnClientGateArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Gate = DoFind_Gate();
        if (ck::Is_NOT_Valid(_Gate))
        { FinishFailure("the gate left the client between the poll and the request"); return; }

        _Gate.Request_SetPosition(FMars_Request_Gate_SetPosition(EMars_Gate_Position::Open));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Gate.Get_IsOpen(), "the client's gate is still closed");
        Assert_True(_Gate.Get_MovingNode().As_Mover().Get_Alpha() < 0.01f, "the client's leaf did not move");
        Assert_False(_Gate.Has_Fragment(FMars_Fragment_Gate_Requests), "the client's drain dropped its request");
        FinishSuccess();
    }

    private FCk_Handle_Gate DoFind_Gate()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsGate"))
        { return Candidate.As_Gate(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Gate();
    }
}
