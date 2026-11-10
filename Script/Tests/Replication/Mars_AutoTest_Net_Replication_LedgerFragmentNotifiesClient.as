// A replicated script fragment written on the server reaches the client, which binds the rep-notify and reconciles
// once right after binding: a value that arrived before the bind never re-fires, so the reconcile covers that race and
// the notify covers the rest. The server writes the ledger some frames after the spawn so either path can deliver it.
// Surface: Ck.Replication.Net.AS_Replication_LedgerFragmentNotifiesClient
class UCk_AutoTest_Net_Replication_LedgerFragmentNotifiesClient : UCk_AutoTest_NetBase
{
    private const int32 k_Payload = 7007;
    private const int32 k_LedgerValue = 7;
    private const int32 k_FramesBeforeWrite = 10;

    // Finishing destroys the tracked entity on the server, and that destroy replicates: the server holds it long
    // enough for the client to have seen the write.
    private const float32 k_ServerHoldSeconds = 2.0f;

    private FCk_Handle_PendingEntityScript _PendingSmoke;
    private FCk_Handle _Smoke;
    private bool _LedgerDeliveredByNotify = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject))
        {
            WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished");
            return;
        }

        WaitUntil(n"Is_SmokeEntityOnClient", n"OnClientSmokeArrived");
    }

    UFUNCTION()
    private void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        _PendingSmoke = utils_entity_script::Request_SpawnEntity(
            Owner, UMars_NetSmoke_EntityScript, UMars_NetSmoke_EntityScript::Params(k_Payload));
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingSmoke, FCk_Delegate_EntityScript_Constructed(this, n"OnSmokeConstructed"));
    }

    UFUNCTION()
    private void OnSmokeConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingSmoke = FCk_Handle_PendingEntityScript();
        _Smoke = FCk_Handle(InEntityScriptHandle);

        // It hangs off the pooled channel, not this runner, so the harness teardown never reaches it.
        Track_ForCleanup(_Smoke);
        WaitFrames(k_FramesBeforeWrite, n"OnServerWrite");
    }

    UFUNCTION()
    private void OnServerWrite(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto& Ledger = _Smoke.Get_Fragment(FMars_Fragment_NetSmoke_Ledger);
        Ledger.Value = k_LedgerValue;
        _Smoke.Request_MarkReplicationDirty(FMars_Fragment_NetSmoke_Ledger);

        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_SmokeEntityOnClient(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(DoFind_SmokeOnClient()));
    }

    UFUNCTION()
    private void OnClientSmokeArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Smoke = DoFind_SmokeOnClient();
        if (ck::Is_NOT_Valid(_Smoke))
        { FinishFailure("the smoke entity left the client between the poll and the bind"); return; }

        // Bind, then reconcile: the order every client-side ledger reader uses.
        _Smoke.BindTo_OnRepNotify(FMars_Fragment_NetSmoke_Ledger, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerNotify"));
        if (Get_HasLedgerArrived())
        {
            Log("[MarsNet] the ledger value arrived before the bind: delivered by the reconcile");
            FinishSuccess();
            return;
        }

        // A value that lands without its notify never satisfies this wait, which is what pins bind-then-reconcile.
        WaitUntil(n"Is_LedgerDeliveredByNotify", n"OnClientLedgerDelivered");
    }

    UFUNCTION()
    private void OnLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (Get_HasLedgerArrived())
        { _LedgerDeliveredByNotify = true; }
    }

    UFUNCTION()
    private void Is_LedgerDeliveredByNotify(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_LedgerDeliveredByNotify);
    }

    UFUNCTION()
    private void OnClientLedgerDelivered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log("[MarsNet] the ledger value arrived after the bind: delivered by the rep-notify");
        FinishSuccess();
    }

    private FCk_Handle DoFind_SmokeOnClient()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsNetSmoke"))
        {
            if (Candidate.Has_Fragment(FMars_Fragment_NetSmoke_Local) == false)
            { continue; }

            if (Candidate.Get_Fragment(FMars_Fragment_NetSmoke_Local).Payload == k_Payload)
            { return Candidate; }
        }

        return FCk_Handle();
    }

    private bool Get_HasLedgerArrived()
    {
        if (_Smoke.Has_Fragment(FMars_Fragment_NetSmoke_Ledger) == false)
        { return false; }

        return _Smoke.Get_Fragment(FMars_Fragment_NetSmoke_Ledger).Value == k_LedgerValue;
    }
}
