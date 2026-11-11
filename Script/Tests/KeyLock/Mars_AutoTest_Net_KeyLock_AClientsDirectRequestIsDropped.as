// A client that bypasses the cue and requests an Insert on its own copy of the lock moves nothing: its drain drops the
// request (it has no authority), so after a settle the lock is empty on both machines and the key is still in slot 0.
// Surface: Ck.KeyLock.Net.AS_KeyLock_AClientsDirectRequestIsDropped
class UCk_AutoTest_Net_KeyLock_AClientsDirectRequestIsDropped : UMars_AutoTestRig_NetKeyLock
{
    private const FVector k_Base = FVector(38000.0, 0.0, 5000.0);
    // The server checks after the client has requested and settled.
    private const float32 k_ServerCheckSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Compose_HotbarCarrier(k_Base + FVector(-200.0, 0.0, 100.0), 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_LockFoundAndKeyHeld", n"OnClientReady", k_SlowPolls);
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
        WaitSeconds(k_ServerCheckSeconds, n"OnServerChecked");
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(ck::Is_NOT_Valid(_Lock.Get_Key()), "the server's lock is still empty");
        Assert_True(Get_SlotHolds(0, mars_items::Key_Red()), "the server's slot 0 still holds the key");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Lock.Request_Insert(FMars_Request_KeyLock_Insert(_Key));
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto LockEmpty = ck::Is_NOT_Valid(_Lock.Get_Key());
        const auto SlotHolds = Get_SlotHolds(0, mars_items::Key_Red());
        Assert_True(LockEmpty, "the client's lock is still empty");
        Assert_True(SlotHolds, "the client's slot 0 still holds the key");
        Log(f"[KeyLockNetTest] client direct insert dropped lockEmpty={LockEmpty} slotHolds={SlotHolds}");
        FinishSuccess();
    }
}
