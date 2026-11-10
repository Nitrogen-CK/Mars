// The late-join shape for a ledger: the server charges a lamp bank's countdown the moment it is built, before the
// client's copy exists, so the client first sees it already charged; then only the server's clock drains it, and the
// client receives each step through the replicated Remaining.
// Surface: Ck.Mechanism.Net.AS_Mechanism_CountdownChargedBeforeClientLooksArrives
class UCk_AutoTest_Net_Mechanism_CountdownChargedBeforeClientLooksArrives : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const int32 k_Steps = 3;

    // Slow enough that the bank is still charged when the client first sees it.
    private const float32 k_SecondsPerStep = 1.0f;

    private const float32 k_ServerHoldSeconds = 2.0f;
    private const int32 k_SlowPolls = 5000;

    private FCk_Handle_PendingEntityScript _PendingBank;
    private FCk_Handle_Countdown _Countdown;
    private int32 _FirstSeenRemaining = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_BankOnClient", n"OnClientBankArrived", k_SlowPolls);
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
        auto Params = UMars_LampBank_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(7000.0, 0.0, 0.0));
        Params.Countdown = FMars_Countdown_Spec(k_Steps, k_SecondsPerStep, false);
        Params.Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_A);
        _PendingBank = utils_entity_script::Request_SpawnEntity(Owner, UMars_LampBank_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingBank, FCk_Delegate_EntityScript_Constructed(this, n"OnServerBankConstructed"));
    }

    UFUNCTION()
    private void OnServerBankConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingBank = FCk_Handle_PendingEntityScript();
        _Countdown = FCk_Handle(InEntityScriptHandle).As_Countdown();
        Track_ForCleanup(_Countdown);
        _Countdown.Request_Charge();
        WaitUntil(n"Is_ServerDrainedOneStep", n"OnServerDrained", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerDrainedOneStep(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Countdown.Get_Remaining() == k_Steps - 1);
    }

    UFUNCTION()
    private void OnServerDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_BankOnClient(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Countdown = DoFind_Countdown();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Countdown) && _Countdown.Get_Remaining() > 0);
    }

    UFUNCTION()
    private void OnClientBankArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Countdown), "the client's lamp bank has no authority");
        _FirstSeenRemaining = _Countdown.Get_Remaining();
        Assert_True(_FirstSeenRemaining > 0, "the client first sees the bank already charged");
        WaitUntil(n"Is_ClientDroppedOneStep", n"OnClientDropped", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientDroppedOneStep(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Countdown.Get_Remaining() < _FirstSeenRemaining);
    }

    UFUNCTION()
    private void OnClientDropped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Countdown.Get_Remaining(), _FirstSeenRemaining - 1, "the client received one step at a time");
        FinishSuccess();
    }

    private FCk_Handle_Countdown DoFind_Countdown()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsLampBank"))
        { return Candidate.As_Countdown(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Countdown();
    }
}
