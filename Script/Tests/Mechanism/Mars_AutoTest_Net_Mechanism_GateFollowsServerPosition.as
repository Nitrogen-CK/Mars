// A gate the server opens opens on the client too: the gate ledger replicates, and the client's setup moves its own leaf
// and broadcasts OnOpenChanged once, from the replicated position (its own request drain never runs).
// Surface: Ck.Mechanism.Net.AS_Mechanism_GateFollowsServerPosition
class UCk_AutoTest_Net_Mechanism_GateFollowsServerPosition : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 12.0f;

    // Gives the client time to receive the closed gate and bind before the server opens it.
    private const int32 k_FramesBeforeOpen = 60;

    // Finishing destroys what the server spawned, and that destroy replicates.
    private const float32 k_ServerHoldSeconds = 2.0f;

    private const int32 k_SlowPolls = 3000;

    private FCk_Handle_PendingEntityScript _PendingGate;
    private FCk_Handle_Gate _Gate;
    private int32 _OpenEdges = 0;
    private EMars_Gate_Position _LastEdge = EMars_Gate_Position::Closed;

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
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(4000.0, 0.0, 0.0));
        Params.Gate.StartOpen = false;
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
        WaitFrames(k_FramesBeforeOpen, n"OnServerOpen");
    }

    UFUNCTION()
    private void OnServerOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Gate.Request_SetPosition(FMars_Request_Gate_SetPosition(EMars_Gate_Position::Open));
        WaitUntil(n"Is_GateOpen", n"OnServerOpened", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOpened(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
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
        { FinishFailure("the gate left the client between the poll and the bind"); return; }

        Assert_False(utils_net::Get_HasAuthority(_Gate), "the client's gate has no authority");
        _Gate.BindTo_OnOpenChanged(FMars_Delegate_Gate_OnOpenChanged(this, n"OnClientOpenChanged"));
        WaitUntil(n"Is_ClientGateOpenAndMoved", n"OnClientGateOpened", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientOpenChanged(FCk_Handle_Gate InGate, EMars_Gate_Position InPosition)
    {
        _OpenEdges += 1;
        _LastEdge = InPosition;
    }

    UFUNCTION()
    private void Is_GateOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Gate.Get_IsOpen());
    }

    UFUNCTION()
    private void Is_ClientGateOpenAndMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Gate.Get_IsOpen() && _Gate.Get_MovingNode().As_Mover().Get_Alpha() > 0.99f);
    }

    UFUNCTION()
    private void OnClientGateOpened(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_OpenEdges, 1, "the client broadcast OnOpenChanged exactly once");
        Assert_True(_LastEdge == EMars_Gate_Position::Open, "the client's one edge was Open");
        FinishSuccess();
    }

    private FCk_Handle_Gate DoFind_Gate()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsGate"))
        { return Candidate.As_Gate(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Gate();
    }
}
