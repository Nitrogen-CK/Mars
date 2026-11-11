// A client's take from a Removable lock crosses as Cue.Mars.KeyLock.Act to the authority, whose drain moves the key into
// the subject's hotbar take target; on both machines the lock is empty and the subject's hotbar holds the key, and the
// client's key visual is gone.
// Surface: Ck.KeyLock.Net.AS_KeyLock_AClientTakeReturnsTheKeyToItsHotbar
class UCk_AutoTest_Net_KeyLock_AClientTakeReturnsTheKeyToItsHotbar : UMars_AutoTestRig_NetKeyLock
{
    private const FVector k_Base = FVector(37000.0, 0.0, 5000.0);

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
        Spawn_ServerLock(k_Base, EMars_KeyLock_Release::Removable);
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
        WaitUntil(n"Is_Taken", n"OnServerTaken", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerTaken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientLockHolds(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Lock.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_KeyLock_Action::Take, f"the client reads Take with empty hands at a Removable lock (got [{Action :n}])");
        utils_key_lock::Request_ActFor(_Lock, Get_SubjectEntity(), EMars_KeyLock_Action::Take);
        WaitUntil(n"Is_TakenWithoutVisual", n"OnClientTaken", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Taken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTaken());
    }

    UFUNCTION()
    private void Is_TakenWithoutVisual(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTaken() && ck::Is_NOT_Valid(_Lock.Get_Visual()));
    }

    UFUNCTION()
    private void OnClientTaken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Slot = _Carrier.Hotbar.TryGet_SlotIndexOf(_Key);
        const auto SlotIndex = Slot.IsSet() ? Slot.GetValue() : -1;
        const auto NewEnsures = Get_NewEnsures();
        Assert_True(NewEnsures == 0, f"the client saw no ensure (got {NewEnsures})");
        Log(f"[KeyLockNetTest] client take landed slot={SlotIndex} visualGone=true newEnsures={NewEnsures}");
        FinishSuccess();
    }

    private bool Get_IsTaken()
    {
        return ck::IsValid(_Lock) && ck::IsValid(_Key) && ck::Is_NOT_Valid(_Lock.Get_Key())
            && _Carrier.Hotbar.TryGet_SlotIndexOf(_Key).IsSet();
    }
}
