// A client's use of a lever crosses as Cue.Mars.Control.Engage to the authority, whose control drain flips the lever,
// whose mechanism graph powers the gate on the same channel; both ledgers replicate back, so the client sees its lever
// active and the gate open without having written either.
// Surface: Ck.Mechanism.Net.AS_Mechanism_ClientEngageCueOpensGateOnEveryMachine
class UCk_AutoTest_Net_Mechanism_ClientEngageCueOpensGateOnEveryMachine : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_ServerHoldSeconds = 2.0f;
    private const int32 k_SlowPolls = 5000;

    private FCk_Handle_Control _Lever;
    private FCk_Handle_Gate _Gate;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_BothOnThisMachine", n"OnClientFound", k_SlowPolls);
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
        auto LeverParams = UMars_Lever_EntityScript::Params();
        LeverParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(5000.0, 0.0, 0.0));
        LeverParams.Control.Interaction = ECk_Interaction_CompletionPolicy::Instant;
        LeverParams.Source.OutputChannel = GameplayTags::Mechanism_Channel_A;
        utils_entity_script::Request_SpawnEntity(Owner, UMars_Lever_EntityScript, LeverParams);

        auto GateParams = UMars_Gate_EntityScript::Params();
        GateParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(5000.0, 400.0, 0.0));
        GateParams.Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_A);
        utils_entity_script::Request_SpawnEntity(Owner, UMars_Gate_EntityScript, GateParams);

        WaitUntil(n"Is_BothOnThisMachine", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_BothOnThisMachine(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Lever = DoFind_Lever();
        _Gate = DoFind_Gate();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Lever) && ck::IsValid(_Gate));
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Track_ForCleanup(_Lever);
        Track_ForCleanup(_Gate);
        Assert_False(_Gate.Get_IsOpen(), "the gate starts closed");
        WaitUntil(n"Is_GateOpen", n"OnServerGateOpened", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGateOpened(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Lever.Get_IsActive(), "the server's lever is active");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Lever), "the client's lever has no authority");
        utils_cue_generic::Request_ExecuteCue(_Lever, GameplayTags::Cue_Mars_Control_Engage, UMars_Cue_Control_Engage::Params(),
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        WaitUntil(n"Is_LeverActiveAndGateOpen", n"OnClientConverged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_GateOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Gate.Get_IsOpen());
    }

    UFUNCTION()
    private void Is_LeverActiveAndGateOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Lever.Get_IsActive() && _Gate.Get_IsOpen());
    }

    UFUNCTION()
    private void OnClientConverged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    private FCk_Handle_Control DoFind_Lever()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsLever"))
        { return Candidate.As_Control(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Control();
    }

    private FCk_Handle_Gate DoFind_Gate()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsGate"))
        { return Candidate.As_Gate(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Gate();
    }
}
