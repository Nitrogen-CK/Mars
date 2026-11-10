// A client presses a seal: the engage cue reaches the authority, whose Momentary control pulses once; the client sees
// the engagement and the control return to inactive.
// Surface: Ck.Hazard.Net.AS_Hazard_SealEngageCuePulsesOnEveryMachine
class UCk_AutoTest_Net_Hazard_SealEngageCuePulsesOnEveryMachine : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_ServerHoldSeconds = 2.0f;
    private const float32 k_PulseSeconds = 1.0f;
    private const int32 k_SlowPolls = 5000;

    // Far from anything else the harness world holds.
    private const float64 k_SealX = 13000.0;

    private FCk_Handle_PendingEntityScript _PendingSeal;
    private FCk_Handle_Control _Seal;

    private int32 _Engagements = 0;
    private bool _SawActive = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_SealOnThisMachine", n"OnClientSealArrived", k_SlowPolls);
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
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_Seal_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(k_SealX, 0.0, 0.0));
        Params.Control.ActiveSeconds = k_PulseSeconds;
        _PendingSeal = utils_entity_script::Request_SpawnEntity(Owner, UMars_Seal_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingSeal, FCk_Delegate_EntityScript_Constructed(this, n"OnServerSealConstructed"));
    }

    UFUNCTION()
    private void OnServerSealConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingSeal = FCk_Handle_PendingEntityScript();
        _Seal = FCk_Handle(InEntityScriptHandle).As_Control();
        Track_ForCleanup(_Seal);
        WaitUntil(n"Is_ServerPulsedOnce", n"OnServerPulsed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPulsedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Seal.Get_Fragment(FMars_Fragment_Control).Engagements == 1 && _Seal.Get_IsActive() == false);
    }

    UFUNCTION()
    private void OnServerPulsed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_SealOnThisMachine(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Seal = DoFind_Seal();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Seal));
    }

    UFUNCTION()
    private void OnClientSealArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Seal), "the client's seal has no authority");

        _Seal.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnClientEngaged"));
        _Seal.BindTo_OnActiveChanged(FMars_Delegate_Control_OnActiveChanged(this, n"OnClientActiveChanged"));

        utils_cue_generic::Request_ExecuteCue(_Seal, GameplayTags::Cue_Mars_Control_Engage, UMars_Cue_Control_Engage::Params(),
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        WaitUntil(n"Is_ClientPulsed", n"OnClientPulsed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEngaged(FCk_Handle_Control InControl)
    {
        ++_Engagements;
    }

    UFUNCTION()
    private void OnClientActiveChanged(FCk_Handle_Control InControl, EMars_Control_Activation InActivation)
    {
        if (InActivation == EMars_Control_Activation::Active)
        { _SawActive = true; }
    }

    UFUNCTION()
    private void Is_ClientPulsed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Seal.Get_IsActive())
        { _SawActive = true; }

        auto Result = OutResult;
        Result.Set(_Engagements >= 1 && _Seal.Get_IsActive() == false);
    }

    UFUNCTION()
    private void OnClientPulsed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[MarsNet] seal pulse of {k_PulseSeconds} s seen Active on the client: {_SawActive}");
        Assert_True(_Engagements == 1, f"the client saw one engagement, not [{_Engagements}]");
        FinishSuccess();
    }

    private FCk_Handle_Control DoFind_Seal()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsSeal"))
        { return Candidate.As_Control(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Control();
    }
}
