// A spike trap's cycle runs on the server; the client sees the phases, raises its own spikes from them and receives the
// hazard's arming, one edge per change.
// Surface: Ck.Hazard.Net.AS_Hazard_SpikeTrapPhasesAndArmingReachTheClient
class UCk_AutoTest_Net_Hazard_SpikeTrapPhasesAndArmingReachTheClient : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_ServerHoldSeconds = 2.0f;
    private const int32 k_SlowPolls = 5000;
    private const int32 k_ServerActiveEntries = 2;

    // Far from anything else the harness world holds.
    private const float64 k_TrapX = 8000.0;

    private FCk_Handle_PendingEntityScript _PendingTrap;
    private FCk_Handle_Trap _Trap;

    private int32 _ServerActiveEntries = 0;

    private bool _SawActive = false;
    private bool _SawSafe = false;
    private bool _SawSpikesUp = false;
    private TArray<EMars_Hazard_Arming> _ArmingEdges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_TrapOnThisMachine", n"OnClientTrapArrived", k_SlowPolls);
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
        auto Spec = utils_trap::Make_SpikeTrapSpec();
        Spec.Cycle.Phases.Empty();
        Spec.Cycle.Phases.Add(FMars_CyclePhase(GameplayTags::Mechanism_Phase_Safe, 1.0f));
        Spec.Cycle.Phases.Add(FMars_CyclePhase(GameplayTags::Mechanism_Phase_Warn, 0.8f));
        Spec.Cycle.Phases.Add(FMars_CyclePhase(GameplayTags::Mechanism_Phase_Active, 1.0f));
        Spec.Cycle.Loop = true;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_SpikeTrap_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(k_TrapX, 0.0, 0.0));
        Params.Trap = Spec;
        _PendingTrap = utils_entity_script::Request_SpawnEntity(Owner, UMars_SpikeTrap_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingTrap, FCk_Delegate_EntityScript_Constructed(this, n"OnServerTrapConstructed"));
    }

    UFUNCTION()
    private void OnServerTrapConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingTrap = FCk_Handle_PendingEntityScript();
        _Trap = FCk_Handle(InEntityScriptHandle).As_Trap();
        Track_ForCleanup(_Trap);

        auto Cycle = _Trap.Get_Cycle();
        Cycle.BindTo_OnPhaseChanged(FMars_Delegate_Cycle_OnPhaseChanged(this, n"OnServerPhaseChanged"));
        WaitUntil(n"Is_ServerActiveTwice", n"OnServerActiveTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex)
    {
        if (InPhase == GameplayTags::Mechanism_Phase_Active)
        { ++_ServerActiveEntries; }
    }

    UFUNCTION()
    private void Is_ServerActiveTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ServerActiveEntries >= k_ServerActiveEntries);
    }

    UFUNCTION()
    private void OnServerActiveTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_TrapOnThisMachine(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Trap = DoFind_Trap();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Trap));
    }

    UFUNCTION()
    private void OnClientTrapArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Trap), "the client's trap has no authority");

        auto Cycle = _Trap.Get_Cycle();
        Cycle.BindTo_OnPhaseChanged(FMars_Delegate_Cycle_OnPhaseChanged(this, n"OnClientPhaseChanged"));
        auto Hazard = _Trap.Get_Hazard();
        Hazard.BindTo_OnArmedChanged(FMars_Delegate_Hazard_OnArmedChanged(this, n"OnClientArmedChanged"));

        WaitUntil(n"Is_ClientConverged", n"OnClientConverged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientPhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex)
    {
        if (InPhase == GameplayTags::Mechanism_Phase_Active)
        { _SawActive = true; }

        if (InPhase == GameplayTags::Mechanism_Phase_Safe)
        { _SawSafe = true; }
    }

    UFUNCTION()
    private void OnClientArmedChanged(FCk_Handle_Hazard InHazard, EMars_Hazard_Arming InArming)
    {
        _ArmingEdges.Add(InArming);
    }

    // The spikes are sampled here: phases may coalesce, so presence is asserted, never order.
    UFUNCTION()
    private void Is_ClientConverged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Mover = _Trap.Get_Mover();
        if (ck::IsValid(Mover) && Mover.Get_Alpha() > 0.9f)
        { _SawSpikesUp = true; }

        auto Result = OutResult;
        Result.Set(_SawActive && _SawSafe && _SawSpikesUp && _ArmingEdges.Contains(EMars_Hazard_Arming::Armed));
    }

    UFUNCTION()
    private void OnClientConverged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        for (int32 Index = 1; Index < _ArmingEdges.Num(); ++Index)
        { Assert_True(_ArmingEdges[Index] != _ArmingEdges[Index - 1], f"arming edge [{Index}] repeats the previous one"); }

        FinishSuccess();
    }

    private FCk_Handle_Trap DoFind_Trap()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsSpikeTrap"))
        { return Candidate.As_Trap(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Trap();
    }
}
