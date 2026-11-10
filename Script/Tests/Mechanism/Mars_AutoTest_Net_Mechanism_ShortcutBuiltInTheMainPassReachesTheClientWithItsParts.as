// A Shortcut whose spawn executes in the script group's main pass (forced by a processor ordered before the spawn
// processor, as a level's spawner can build one when the relay channel is ready at once) replicates with its gate and its
// lever, which it requests in its DoConstruct (their spawns execute in the script group's settle barrier).
// Surface: Ck.Mechanism.Net.AS_Mechanism_ShortcutBuiltInTheMainPassReachesTheClientWithItsParts
class UCk_AutoTest_Net_Mechanism_ShortcutBuiltInTheMainPassReachesTheClientWithItsParts : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_ShortcutLocation = FVector(26000.0, 0.0, 0.0);
    private const float64 k_NearCm = 600.0;
    private const float32 k_ServerReadSeconds = 2.0f;
    private const float32 k_ServerHoldSeconds = 9.0f;
    private const int32 k_SlowPolls = 5000;
    // The client's window for the parts (8 s at the pinned 60 fps).
    private const int32 k_ClientMaxFrames = 480;

    private int32 _Frame = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Poll_ClientParts", n"OnClientPartsWatched", k_ClientMaxFrames + 10);
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
        auto Order = FMars_TESTONLY_NetSpawn_Order(EMars_TESTONLY_NetSpawn_OrderKind::Shortcut, EMars_TESTONLY_NetSpawn_OrderOwner::SpawnOwner, 0);
        Order.Location = k_ShortcutLocation;
        utils_net_spawn_test::Add_OrderAtMain(Subject, Order);
        WaitSeconds(k_ServerReadSeconds, n"OnServerRead");
    }

    UFUNCTION()
    private void OnServerRead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Gate = DoFind_Near(n"TAG_MarsGate");
        const auto Lever = DoFind_Near(n"TAG_MarsLever");
        const auto GateState = utils_net_spawn_test::Get_HostState(Gate);
        const auto LeverState = utils_net_spawn_test::Get_HostState(Lever);
        Log(f"[MechanismTest-server] main-pass shortcut gate={GateState} lever={LeverState}");
        Assert_True(utils_net_spawn_test::Get_IsComplete(Gate), f"the shortcut's gate replicated on the host ({GateState})");
        Assert_True(utils_net_spawn_test::Get_IsComplete(Lever), f"the shortcut's lever replicated on the host ({LeverState})");

        if (ck::IsValid(Gate))
        {
            const auto Shortcut = utils_entity_lifetime::Get_LifetimeOwner(Gate);
            if (ck::IsValid(Shortcut))
            { Track_ForCleanup(Shortcut); }
        }

        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Poll_ClientParts(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Frame += 1;
        auto Result = OutResult;
        Result.Set((ck::IsValid(DoFind_Near(n"TAG_MarsGate")) && ck::IsValid(DoFind_Near(n"TAG_MarsLever"))) || _Frame >= k_ClientMaxFrames);
    }

    UFUNCTION()
    private void OnClientPartsWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasGate = ck::IsValid(DoFind_Near(n"TAG_MarsGate"));
        const auto HasLever = ck::IsValid(DoFind_Near(n"TAG_MarsLever"));
        Log(f"[MechanismTest] main-pass shortcut on the client: gate={HasGate} lever={HasLever} at poll {_Frame}");
        Assert_True(HasGate, f"the client has the shortcut's gate (window {k_ClientMaxFrames} frames)");
        Assert_True(HasLever, f"the client has the shortcut's lever (window {k_ClientMaxFrames} frames)");
        FinishSuccess();
    }

    private FCk_Handle DoFind_Near(FName InTag)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            if (utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            const auto Transform = Candidate.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Transform))
            { continue; }

            if ((utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - k_ShortcutLocation).Size() < k_NearCm)
            { return Candidate; }
        }

        return FCk_Handle();
    }
}
