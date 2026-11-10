// The spawn anchor exists where replicated spawns happen and nowhere else: on the listen host UMars_Net_Subsystem
// publishes a replicated channel entity as the spawn owner; on the client the lookup answers invalid, since a client
// never spawns a replicated thing.
// Surface: Ck.Replication.Net.AS_Replication_SpawnOwnerIsServerPublished
class UCk_AutoTest_Net_Replication_SpawnOwnerIsServerPublished : UCk_AutoTest_NetBase
{
    // Long enough for the host to have published its owner: an owner that leaked to the client would be there by then.
    private const float32 k_ClientSettleSeconds = 1.0f;

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

        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Subject = Get_SubjectEntity();
        if (utils_mars_net::Get_HasReplicatedSpawnOwner(Subject) == false)
        { Result.Set(false); return; }

        const auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Subject);
        Result.Set(utils_net::Get_Replication(Owner) == ECk_Replication::Replicates);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Subject = Get_SubjectEntity();
        Assert_Invalid(utils_mars_net::Get_ReplicatedSpawnOwner(Subject), "a client has no replicated spawn owner");
        Assert_False(utils_mars_net::Get_HasReplicatedSpawnOwner(Subject), "a client never reports a spawn owner ready");
        FinishSuccess();
    }
}
