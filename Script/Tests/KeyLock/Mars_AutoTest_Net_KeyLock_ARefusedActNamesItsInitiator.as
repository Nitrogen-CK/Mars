// A client's take at a lock that keeps its key reaches the authority, which asks Get_ActionFor again, reads
// Blocked_KeyKept and refuses: the lock's replicated ledger advances by one on both machines, names the subject and says
// ActionBlocked, the lock still holds its key, and nobody ensures (a stale or racing Act is not a broken caller).
// Surface: Ck.KeyLock.Net.AS_KeyLock_ARefusedActNamesItsInitiator
class UCk_AutoTest_Net_KeyLock_ARefusedActNamesItsInitiator : UMars_AutoTestRig_NetKeyLock
{
    private const FVector k_Base = FVector(39000.0, 0.0, 5000.0);

    private int32 _SerialAtAct = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Compose_HotbarCarrier(k_Base + FVector(-200.0, 0.0, 100.0), 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_LockHoldingKey", n"OnClientLockHolds", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLock(k_Base, EMars_KeyLock_Release::Kept);
        WaitUntil(n"Is_HotbarReady", n"OnServerHotbarReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHotbarReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Key_Red());
        WaitUntil(n"Is_LockFoundAndKeyHeld", n"OnServerSeeded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Insert_ServerKey();
        WaitUntil(n"Is_LockHoldingKey", n"OnServerLockHolds", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLockHolds(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialAtAct = _Lock.Get_RefusalSerial();
        WaitUntil(n"Is_Refused", n"OnServerRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Refusal("server");
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientLockHolds(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialAtAct = _Lock.Get_RefusalSerial();
        utils_key_lock::Request_ActFor(_Lock, Get_SubjectEntity(), EMars_KeyLock_Action::Take);
        WaitUntil(n"Is_Refused", n"OnClientRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Refusal("client");
        const auto NewEnsures = Get_NewEnsures();
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        const auto Serial = _Lock.Get_RefusalSerial();
        const auto Reason = _Lock.Get_LastRefusal();
        const auto NamesSubject = _Lock.Get_LastRefused() == Get_SubjectEntity();
        Log(f"[KeyLockNetTest] refused take serial={_SerialAtAct}->{Serial} reason={Reason :n} namesSubject={NamesSubject} newEnsures={NewEnsures}");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Lock.Get_RefusalSerial() > _SerialAtAct && _Lock.Get_LastRefused() == Get_SubjectEntity());
    }

    private void Assert_Refusal(FString InMachine)
    {
        Assert_True(_Lock.Get_RefusalSerial() == _SerialAtAct + 1, f"the {InMachine}'s ledger advanced by one (got {_SerialAtAct} -> {_Lock.Get_RefusalSerial()})");
        Assert_True(_Lock.Get_LastRefusal() == EMars_Interaction_FailReason::ActionBlocked,
            f"the {InMachine}'s ledger says ActionBlocked (got [{_Lock.Get_LastRefusal() :n}])");
        Assert_True(_Lock.Get_Key() == _Key, f"the {InMachine}'s lock still holds its key");
    }
}
