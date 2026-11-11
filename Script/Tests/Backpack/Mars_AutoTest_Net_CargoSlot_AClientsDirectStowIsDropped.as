// A client that bypasses the cue and requests a Stow on its own copy of the slot moves nothing: its drain drops the
// request (it has no authority), so after a settle the slot is empty on both machines and the rock is still in bag slot 0.
// Surface: Ck.Backpack.Net.AS_CargoSlot_AClientsDirectStowIsDropped
class UCk_AutoTest_Net_CargoSlot_AClientsDirectStowIsDropped : UMars_AutoTestRig_NetBackpack
{
    private const FVector k_FloorTop = FVector(51000.0, 0.0, 5000.0);
    // The server checks after the client has requested and settled.
    private const float32 k_ServerCheckSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetBackpack(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_PackReadyAndRockHeld", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPack();
        WaitUntil(n"Is_PackReady", n"OnServerPackReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPackReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Rock());
        WaitUntil(n"Is_PackReadyAndRockHeld", n"OnServerSeeded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerCheckSeconds, n"OnServerChecked");
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Slot0.Get_IsOccupied(), "the server's slot is still empty");
        Assert_True(Get_SlotHolds(0, mars_items::Rock()), "the server's bag slot 0 still holds the rock");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Slot0.Request_Stow(FMars_Request_CargoSlot_Stow(_Item));
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto SlotEmpty = _Slot0.Get_IsOccupied() == false;
        const auto BagHolds = Get_SlotHolds(0, mars_items::Rock());
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[CargoSlotNetTest] client direct stow dropped slotEmpty={SlotEmpty} bagHolds={BagHolds} newEnsures={NewEnsures}");
        Assert_True(SlotEmpty, "the client's slot is still empty");
        Assert_True(BagHolds, "the client's bag slot 0 still holds the rock");
        FinishSuccess();
    }
}
