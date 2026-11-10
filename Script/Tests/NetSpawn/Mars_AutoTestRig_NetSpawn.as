enum EMars_TESTONLY_NetSpawn_Pass
{
    Main,
    Settle,
    Tail
}

// The two-machine shape the parent-with-child tests share: the server waits for the replicated spawn owner, then orders,
// in the pass the test names (_Pass), a parent that requests one Replicates child in its own DoConstruct, once under the
// spawn owner and once under the subject. Two seconds later the server asserts each parent and its child are replication
// complete and that no ensure fired; the client waits for both families and asserts they arrived whole.
class UMars_AutoTestRig_NetSpawnParent : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 22.0f;

    protected EMars_TESTONLY_NetSpawn_Pass _Pass = EMars_TESTONLY_NetSpawn_Pass::Main;
    // Distinct per test, so two tests' parents never alias.
    protected int32 _PayloadBase = 3600;
    protected FVector _Location = FVector(30000.0, 0.0, 0.0);

    private const float32 k_ServerReadSeconds = 2.0f;
    // Outlasts the client's window, so nothing it could still see is destroyed early.
    private const float32 k_ServerHoldSeconds = 10.0f;
    private const int32 k_SlowPolls = 5000;
    // The client's window for both families (8 s at the pinned 60 fps).
    private const int32 k_ClientMaxFrames = 480;

    private int32 _Frame = 0;
    private int32 _SeenAtFrame = -1;
    private int32 _EnsuresBefore = 0;

    int32 Get_SpawnOwnerPayload() const { return _PayloadBase + 1; }
    int32 Get_SubjectPayload() const { return _PayloadBase + 2; }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Poll_ClientFamilies", n"OnClientFamilies", k_ClientMaxFrames + 10);
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
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        Stamp(Subject, Make_Order(EMars_TESTONLY_NetSpawn_OrderOwner::SpawnOwner, Get_SpawnOwnerPayload()));
        Stamp(Subject, Make_Order(EMars_TESTONLY_NetSpawn_OrderOwner::Carrier, Get_SubjectPayload()));
        WaitSeconds(k_ServerReadSeconds, n"OnServerRead");
    }

    private FMars_TESTONLY_NetSpawn_Order Make_Order(EMars_TESTONLY_NetSpawn_OrderOwner InOwner, int32 InPayload)
    {
        auto Order = FMars_TESTONLY_NetSpawn_Order(EMars_TESTONLY_NetSpawn_OrderKind::LegacyParent, InOwner, InPayload);
        Order.Location = _Location + FVector(0.0, 200.0 * float64(InPayload - _PayloadBase), 0.0);
        return Order;
    }

    private void Stamp(FCk_Handle& InSubject, const FMars_TESTONLY_NetSpawn_Order& InOrder)
    {
        switch (_Pass)
        {
            case EMars_TESTONLY_NetSpawn_Pass::Main: utils_net_spawn_test::Add_OrderAtMain(InSubject, InOrder); break;
            case EMars_TESTONLY_NetSpawn_Pass::Settle: utils_net_spawn_test::Add_OrderAtSettle(InSubject, InOrder); break;
            case EMars_TESTONLY_NetSpawn_Pass::Tail: utils_net_spawn_test::Add_OrderAtTail(InSubject, InOrder); break;
        }
    }

    UFUNCTION()
    private void OnServerRead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Subject = Get_SubjectEntity();
        Assert_Family(Subject, Get_SpawnOwnerPayload(), "under the spawn owner");
        Assert_Family(Subject, Get_SubjectPayload(), "under the subject");

        const auto NewEnsures = utils_ensure::Get_EnsureCount() - _EnsuresBefore;
        Log(f"[NetSpawnTest-server] {_Pass :n} spawnOwner={Get_FamilyLine(Subject, Get_SpawnOwnerPayload())} "
            + f"subject={Get_FamilyLine(Subject, Get_SubjectPayload())} newEnsures={NewEnsures}");
        Assert_Equals_Int(NewEnsures, 0, "no ensure fired while the families replicated");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    private void Assert_Family(FCk_Handle InSubject, int32 InPayload, FString InWhere)
    {
        const auto Parent = utils_net_spawn_test::Find_Spike(InSubject, InPayload);
        const auto Child = utils_net_spawn_test::Find_Spike(InSubject, utils_net_spike::Get_ConstructChildPayload(InPayload));
        Track(Parent);
        Track(Child);
        Assert_True(utils_net_spawn_test::Get_IsComplete(Parent), f"the parent {InWhere} replicated on the host ({utils_net_spawn_test::Get_HostState(Parent)})");
        Assert_True(utils_net_spawn_test::Get_IsComplete(Child), f"its DoConstruct child replicated on the host ({utils_net_spawn_test::Get_HostState(Child)})");
    }

    private FString Get_FamilyLine(FCk_Handle InSubject, int32 InPayload) const
    {
        return f"{utils_net_spawn_test::Get_HostState(utils_net_spawn_test::Find_Spike(InSubject, InPayload))}/"
            + f"{utils_net_spawn_test::Get_HostState(utils_net_spawn_test::Find_Spike(InSubject, utils_net_spike::Get_ConstructChildPayload(InPayload)))}";
    }

    private void Track(FCk_Handle InEntity)
    {
        if (ck::IsValid(InEntity))
        { Track_ForCleanup(InEntity); }
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Poll_ClientFamilies(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Frame += 1;
        const auto AllSeen = Get_IsFamilySeen(Get_SpawnOwnerPayload()) && Get_IsFamilySeen(Get_SubjectPayload());
        if (AllSeen && _SeenAtFrame < 0)
        { _SeenAtFrame = _Frame; }

        auto Result = OutResult;
        Result.Set(AllSeen || _Frame >= k_ClientMaxFrames);
    }

    private bool Get_IsFamilySeen(int32 InPayload)
    {
        auto Subject = Get_SubjectEntity();
        return ck::IsValid(utils_net_spawn_test::Find_Spike(Subject, InPayload))
            && ck::IsValid(utils_net_spawn_test::Find_Spike(Subject, utils_net_spike::Get_ConstructChildPayload(InPayload)));
    }

    UFUNCTION()
    private void OnClientFamilies(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsFamilySeen(Get_SpawnOwnerPayload()), f"the client sees the spawn owner's parent and its child (window {k_ClientMaxFrames} frames)");
        Assert_True(Get_IsFamilySeen(Get_SubjectPayload()), f"the client sees the subject's parent and its child (window {k_ClientMaxFrames} frames)");
        Log(f"[NetSpawnTest] {_Pass :n} families seen at poll {_SeenAtFrame}");
        FinishSuccess();
    }
}
