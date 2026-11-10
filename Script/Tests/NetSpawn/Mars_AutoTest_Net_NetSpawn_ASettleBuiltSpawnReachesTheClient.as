// A plain Replicates spawn under the replicated spawn owner whose request is executed in the script group's settle
// barrier (forced by a processor ordered after the framework's begin-play processor), stamped with
// utils_net_spawn::Expect_Replicated: on the host it completes replication, the check lets it go, and no ensure fires;
// the client sees it.
// Surface: Ck.NetSpawn.Net.AS_NetSpawn_ASettleBuiltSpawnReachesTheClient
class UCk_AutoTest_Net_NetSpawn_ASettleBuiltSpawnReachesTheClient : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 14.0f;

    private const int32 k_Payload = 3621;
    private const FVector k_Location = FVector(32000.0, 0.0, 0.0);
    // Polls for the spawn to complete: the harness polls twice a frame (main pass and tail pump), so four polls per
    // budgeted frame leave a wide margin.
    private const int32 k_ServerMaxPolls = constants_net_spawn::k_ReplicationFrameBudget * 4;
    // Outlasts the client's watch.
    private const float32 k_ServerHoldSeconds = 5.0f;
    // The client's watch (4 s at the pinned 60 fps).
    private const int32 k_ClientWatchFrames = 240;
    private const int32 k_SlowPolls = 5000;

    private int32 _EnsuresBefore = 0;
    private int32 _ServerPolls = 0;
    private bool _ClientSaw = false;
    private int32 _ClientFrame = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Poll_ClientSees", n"OnClientWatched", k_ClientWatchFrames + 10);
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

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Subject = Get_SubjectEntity();
        auto Order = FMars_TESTONLY_NetSpawn_Order(EMars_TESTONLY_NetSpawn_OrderKind::PlainSpawn, EMars_TESTONLY_NetSpawn_OrderOwner::SpawnOwner, k_Payload);
        Order.Location = k_Location;
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        utils_net_spawn_test::Add_OrderAtSettle(Subject, Order);
        WaitUntil(n"Is_CheckSettled", n"OnServerSettled", k_ServerMaxPolls + 10);
    }

    // The spawn exists and the check has stopped watching it (or the poll budget ran out: the asserts then say which).
    UFUNCTION()
    private void Is_CheckSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _ServerPolls += 1;
        const auto Spawned = utils_net_spawn_test::Find_Spike(Get_SubjectEntity(), k_Payload);
        const auto Settled = ck::IsValid(Spawned) && Spawned.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication) == false;
        auto Result = OutResult;
        Result.Set(Settled || _ServerPolls >= k_ServerMaxPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Spawned = utils_net_spawn_test::Find_Spike(Get_SubjectEntity(), k_Payload);
        Assert_True(ck::IsValid(Spawned), "the host built the settle-pass spawn");
        if (ck::IsValid(Spawned))
        {
            Track_ForCleanup(Spawned);
            Log(f"[NetSpawnTest-server] settle-built spawn state={utils_net_spawn_test::Get_HostState(Spawned)} after {_ServerPolls} polls");
            Assert_True(utils_net_spawn_test::Get_IsComplete(Spawned), "the settle-pass spawn completed replication on the host");
            Assert_False(Spawned.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication), "the check let it go");
        }

        Assert_Equals_Int(utils_ensure::Get_EnsureCount() - _EnsuresBefore, 0, "no ensure fired for the settle-pass spawn");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // Watches every poll for the client's window, or until the spawn shows up.
    UFUNCTION()
    private void Poll_ClientSees(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _ClientFrame += 1;
        if (ck::IsValid(utils_net_spawn_test::Find_Spike(Get_SubjectEntity(), k_Payload)))
        { _ClientSaw = true; }

        auto Result = OutResult;
        Result.Set(_ClientSaw || _ClientFrame >= k_ClientWatchFrames);
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_ClientSaw, f"the client sees the settle-pass spawn (window {k_ClientWatchFrames} polls)");
        FinishSuccess();
    }
}
