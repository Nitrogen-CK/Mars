// An armed spike trap hits on the server only: the client holds its own occupant inside its copy of the trigger, sees the
// replicated arming, and counts no hit and no trigger.
// Surface: Ck.Hazard.Net.AS_Hazard_HitsOnlyOnTheServer
class UCk_AutoTest_Net_Hazard_HitsOnlyOnTheServer : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_ServerHoldSeconds = 2.0f;
    private const float32 k_ClientWatchSeconds = 2.0f;
    private const int32 k_SlowPolls = 5000;

    // Far from anything else the harness world holds.
    private const float64 k_TrapX = 9000.0;

    private FCk_Handle_PendingEntityScript _PendingTrap;
    private FCk_Handle_Trap _Trap;

    private int32 _Hits = 0;
    private int32 _Triggers = 0;

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

    // One looping Active phase: the hazard is armed and the spikes up for the whole test.
    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = FMars_Trap_Spec();
        Spec.Cycle.Phases.Add(FMars_CyclePhase(GameplayTags::Mechanism_Phase_Active, 1.0f));
        Spec.Cycle.Loop = true;

        auto ActiveAction = FMars_Trap_PhaseAction();
        ActiveAction.Phase = GameplayTags::Mechanism_Phase_Active;
        ActiveAction.MoverAtEnd = TOptional<bool>(true);
        ActiveAction.HazardArmed = TOptional<bool>(true);
        Spec.Actions.Add(ActiveAction);

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

        auto Hazard = _Trap.Get_Hazard();
        Hazard.BindTo_OnHit(FMars_Delegate_Hazard_OnHit(this, n"OnHazardHit"));

        // Local to the server and under the subject: nothing about it can reach the client.
        auto Occupant = MakeOccupant(Get_SubjectEntity(), FVector(k_TrapX, 0.0, 30.0));
        Track_ForCleanup(Occupant);
        WaitUntil(n"Is_HitAtLeastOnce", n"OnServerHit", k_SlowPolls);
    }

    UFUNCTION()
    private void OnHazardHit(FCk_Handle_Hazard InHazard, FCk_Handle InEntity)
    {
        ++_Hits;
    }

    UFUNCTION()
    private void OnTrapTriggered(FCk_Handle_Trap InTrap, FCk_Handle InEntity)
    {
        ++_Triggers;
    }

    UFUNCTION()
    private void Is_HitAtLeastOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Hits >= 1);
    }

    UFUNCTION()
    private void OnServerHit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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

        auto Hazard = _Trap.Get_Hazard();
        Hazard.BindTo_OnHit(FMars_Delegate_Hazard_OnHit(this, n"OnHazardHit"));
        _Trap.BindTo_OnTriggered(FMars_Delegate_Trap_OnTriggered(this, n"OnTrapTriggered"));

        // The client's own occupant, inside the client's copy of the trigger.
        auto Occupant = MakeOccupant(Get_SubjectEntity(), FVector(k_TrapX, 0.0, 30.0));
        Track_ForCleanup(Occupant);

        WaitUntil(n"Is_ClientArmed", n"OnClientArmed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientArmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Trap.Get_Hazard().Get_IsArmed());
    }

    UFUNCTION()
    private void OnClientArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Hits == 0, f"the client's hazard hit [{_Hits}] times");
        Assert_True(_Triggers == 0, f"the client's trap triggered [{_Triggers}] times");
        FinishSuccess();
    }

    private FCk_Handle_Trap DoFind_Trap()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsSpikeTrap"))
        { return Candidate.As_Trap(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Trap();
    }

    // A kinematic player-filtered probe: what the trap's trigger detects. Not a character, so nothing is launched.
    private FCk_Handle_Transform MakeOccupant(FCk_Handle InOwner, FVector InLocation)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InOwner);
        Owner.Request_OverrideToSelf();
        auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(Root, 30.0f, ProbeSpec);
        return Root;
    }
}
