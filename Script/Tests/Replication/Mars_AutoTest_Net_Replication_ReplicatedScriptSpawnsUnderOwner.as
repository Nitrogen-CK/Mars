// A Replicates Mars entity script spawned on the server under the spawn owner arrives on the client, constructed there
// with the server's spawn params (the client's own DoConstruct recorded Payload 4242) and without authority.
// Surface: Ck.Replication.Net.AS_Replication_ReplicatedScriptSpawnsUnderOwner
class UCk_AutoTest_Net_Replication_ReplicatedScriptSpawnsUnderOwner : UCk_AutoTest_NetBase
{
    private const int32 k_Payload = 4242;

    // Finishing destroys the tracked entity on the server, and that destroy replicates: the server holds it long
    // enough for the client to have seen it.
    private const float32 k_ServerHoldSeconds = 2.0f;

    private FCk_Handle_PendingEntityScript _PendingSmoke;

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

        // It hangs off the pooled channel, not this runner, so the harness teardown never reaches it.
        Track_ForCleanup(FCk_Handle(InEntityScriptHandle));
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
        Result.Set(utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsNetSmoke").Num() > 0);
    }

    UFUNCTION()
    private void OnClientSmokeArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Found = utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsNetSmoke");
        Assert_Equals_Int(Found.Num(), 1, "one smoke entity reached the client");
        if (Found.Num() == 0)
        { FinishFailure("the smoke entity left the client between the poll and the check"); return; }

        const auto Smoke = Found[0];
        Assert_True(Smoke.Has_Fragment(FMars_Fragment_NetSmoke_Local), "the client's DoConstruct ran");
        if (Smoke.Has_Fragment(FMars_Fragment_NetSmoke_Local))
        {
            Assert_Equals_Int(Smoke.Get_Fragment(FMars_Fragment_NetSmoke_Local).Payload, k_Payload,
                "the client constructed with the server's spawn params");
        }

        Assert_False(utils_net::Get_HasAuthority(Smoke), "the client's copy has no authority");
        FinishSuccess();
    }
}
