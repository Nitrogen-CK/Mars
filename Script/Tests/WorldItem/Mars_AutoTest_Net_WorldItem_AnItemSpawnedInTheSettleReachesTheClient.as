// Three World-mode rocks spawned through the world-item funnel for nobody (so under the replicated spawn owner), one per
// scheduler pass: one whose spawn is executed in the script group's settle barrier (forced by a processor ordered after
// the framework's begin-play processor), one in the main pass, one in the tail pump. On the host each completes
// replication and is let go by the check with no ensure, and the client sees all three, each a World-mode world item
// holding its item. Isolated floor: X 25000, Z 5000.
// Surface: Ck.WorldItem.Net.AS_WorldItem_AnItemSpawnedInTheSettleReachesTheClient
class UCk_AutoTest_Net_WorldItem_AnItemSpawnedInTheSettleReachesTheClient : UMars_AutoTestRig_NetWorldItem
{
    default _TimeoutSeconds = 22.0f;

    private const FVector k_FloorTop = FVector(25000.0, 0.0, 5000.0);
    // Between the rocks along Y, past Find_WorldItemNear's 300 cm radius.
    private const float64 k_SpacingCm = 600.0;
    private const float64 k_DropHeightCm = 20.0;
    // Polls for the three rocks to complete and be let go: the harness polls twice a frame, so four polls per budgeted
    // frame leave a wide margin.
    private const int32 k_ServerMaxPolls = constants_net_spawn::k_ReplicationFrameBudget * 4;
    // Outlasts the client's window.
    private const float32 k_ServerKeepSeconds = 10.0f;
    // The client's window for the three rocks (8 s at the pinned 60 fps).
    private const int32 k_ClientMaxFrames = 480;

    private int32 _EnsuresBefore = 0;
    private int32 _ServerPolls = 0;
    private int32 _ClientFrame = 0;
    private int32 _ClientSeenAtFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Poll_ClientSeesAll", n"OnClientWatched", k_ClientMaxFrames + 10);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Subject = Get_SubjectEntity();
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        utils_net_spawn_test::Add_OrderAtSettle(Subject, Make_Order(EMars_TESTONLY_NetSpawn_Pass::Settle));
        utils_net_spawn_test::Add_OrderAtMain(Subject, Make_Order(EMars_TESTONLY_NetSpawn_Pass::Main));
        utils_net_spawn_test::Add_OrderAtTail(Subject, Make_Order(EMars_TESTONLY_NetSpawn_Pass::Tail));
        WaitUntil(n"Is_ServerAllLetGo", n"OnServerAllLetGo", k_ServerMaxPolls + 10);
    }

    private FMars_TESTONLY_NetSpawn_Order Make_Order(EMars_TESTONLY_NetSpawn_Pass InPass) const
    {
        auto Order = FMars_TESTONLY_NetSpawn_Order(EMars_TESTONLY_NetSpawn_OrderKind::WorldItem, EMars_TESTONLY_NetSpawn_OrderOwner::SpawnOwner, 0);
        Order.Location = Get_RestNear(InPass) + FVector(0.0, 0.0, k_DropHeightCm);
        return Order;
    }

    // Where InPass's rock lies on the floor: Main, Settle and Tail side by side along Y.
    private FVector Get_RestNear(EMars_TESTONLY_NetSpawn_Pass InPass) const
    {
        return k_FloorTop + FVector(0.0, k_SpacingCm * float64(int32(InPass) - 1), 0.0);
    }

    // The rock completed replication on the host and the check stopped watching it.
    private bool Get_IsLetGo(EMars_TESTONLY_NetSpawn_Pass InPass)
    {
        FCk_Handle Rock = Find_WorldItemNear(Get_RestNear(InPass));
        return utils_net_spawn_test::Get_IsComplete(Rock) && Rock.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication) == false;
    }

    UFUNCTION()
    private void Is_ServerAllLetGo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _ServerPolls += 1;
        const auto AllLetGo = Get_IsLetGo(EMars_TESTONLY_NetSpawn_Pass::Main) && Get_IsLetGo(EMars_TESTONLY_NetSpawn_Pass::Settle)
            && Get_IsLetGo(EMars_TESTONLY_NetSpawn_Pass::Tail);
        auto Result = OutResult;
        Result.Set(AllLetGo || _ServerPolls >= k_ServerMaxPolls);
    }

    UFUNCTION()
    private void OnServerAllLetGo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Server(EMars_TESTONLY_NetSpawn_Pass::Main);
        Assert_Server(EMars_TESTONLY_NetSpawn_Pass::Settle);
        Assert_Server(EMars_TESTONLY_NetSpawn_Pass::Tail);
        const auto NewEnsures = utils_ensure::Get_EnsureCount() - _EnsuresBefore;
        const auto MainLine = Get_ServerLine(EMars_TESTONLY_NetSpawn_Pass::Main);
        const auto SettleLine = Get_ServerLine(EMars_TESTONLY_NetSpawn_Pass::Settle);
        const auto TailLine = Get_ServerLine(EMars_TESTONLY_NetSpawn_Pass::Tail);
        Log(f"[WorldItemNetSpawnTest-server] Main={MainLine} Settle={SettleLine} Tail={TailLine} "
            + f"after {_ServerPolls} polls, new ensures={NewEnsures}");
        Assert_Equals_Int(NewEnsures, 0, "nothing ensured while the three rocks were built and replicated");
        WaitSeconds(k_ServerKeepSeconds, n"OnServerKept");
    }

    private void Assert_Server(EMars_TESTONLY_NetSpawn_Pass InPass)
    {
        FCk_Handle Rock = Find_WorldItemNear(Get_RestNear(InPass));
        Assert_True(ck::IsValid(Rock), f"the host built the {InPass :n}-pass rock");
        if (ck::Is_NOT_Valid(Rock))
        { return; }

        Track_ForCleanup(Rock);
        Assert_True(utils_net_spawn_test::Get_IsComplete(Rock), f"the {InPass :n}-pass rock completed replication on the host ({utils_net_spawn_test::Get_HostState(Rock)})");
        Assert_False(Rock.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication), f"the check let the {InPass :n}-pass rock go");
    }

    private FString Get_ServerLine(EMars_TESTONLY_NetSpawn_Pass InPass)
    {
        FCk_Handle Rock = Find_WorldItemNear(Get_RestNear(InPass));
        const auto Awaiting = ck::IsValid(Rock) && Rock.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication);
        return f"{utils_net_spawn_test::Get_HostState(Rock)}/awaiting={Awaiting}";
    }

    UFUNCTION()
    private void OnServerKept(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // The rock is a World-mode world item on this machine whose holder holds its item.
    private bool Get_IsClientSeen(EMars_TESTONLY_NetSpawn_Pass InPass)
    {
        const auto Rock = Find_WorldItemNear(Get_RestNear(InPass));
        return ck::IsValid(Rock) && ck::IsValid(Rock.Get_HeldItem());
    }

    UFUNCTION()
    private void Poll_ClientSeesAll(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _ClientFrame += 1;
        const auto AllSeen = Get_IsClientSeen(EMars_TESTONLY_NetSpawn_Pass::Main) && Get_IsClientSeen(EMars_TESTONLY_NetSpawn_Pass::Settle)
            && Get_IsClientSeen(EMars_TESTONLY_NetSpawn_Pass::Tail);
        if (AllSeen && _ClientSeenAtFrame < 0)
        { _ClientSeenAtFrame = _ClientFrame; }

        auto Result = OutResult;
        Result.Set(AllSeen || _ClientFrame >= k_ClientMaxFrames);
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto MainSeen = Get_IsClientSeen(EMars_TESTONLY_NetSpawn_Pass::Main);
        const auto SettleSeen = Get_IsClientSeen(EMars_TESTONLY_NetSpawn_Pass::Settle);
        const auto TailSeen = Get_IsClientSeen(EMars_TESTONLY_NetSpawn_Pass::Tail);
        Log(f"[WorldItemNetSpawnTest] client Main={MainSeen} Settle={SettleSeen} Tail={TailSeen} all seen at poll {_ClientSeenAtFrame}");
        Assert_True(MainSeen, f"the client sees the Main-pass rock with its item (window {k_ClientMaxFrames} frames)");
        Assert_True(SettleSeen, f"the client sees the Settle-pass rock with its item (window {k_ClientMaxFrames} frames)");
        Assert_True(TailSeen, f"the client sees the Tail-pass rock with its item (window {k_ClientMaxFrames} frames)");
        FinishSuccess();
    }
}
