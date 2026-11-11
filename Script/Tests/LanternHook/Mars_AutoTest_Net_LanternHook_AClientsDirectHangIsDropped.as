// A client that bypasses the cue and requests a Hang on its own copy of the sconce's hook moves nothing: its drain drops
// the request (it has no authority), so after a settle the hook is empty on both machines and the lantern is still in
// slot 0.
// Surface: Ck.LanternHook.Net.AS_LanternHook_AClientsDirectHangIsDropped
class UCk_AutoTest_Net_LanternHook_AClientsDirectHangIsDropped : UMars_AutoTestRig_NetLanternHook
{
    private const FVector k_FloorTop = FVector(45000.0, 0.0, 5000.0);
    // The server checks after the client has requested and settled.
    private const float32 k_ServerCheckSeconds = 5.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetLanternHook(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_LanternHeld", n"OnClientHeld", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSconceAndLantern();
        WaitUntil(n"Is_ServerLanternLinked", n"OnServerLinked", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLinked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        PickUp_ServerLantern();
        WaitUntil(n"Is_LanternHeld", n"OnServerLanternHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLanternHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerCheckSeconds, n"OnServerChecked");
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(ck::Is_NOT_Valid(_Hook.Get_Item()), "the server's hook is still empty");
        Assert_True(Get_IsLanternInSlot(), "the server's slot 0 still holds the lantern");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(_Lantern));
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HookEmpty = ck::Is_NOT_Valid(_Hook.Get_Item());
        const auto InSlot = Get_IsLanternInSlot();
        Log(f"[LanternHookNetTest] client direct hang dropped hookEmpty={HookEmpty} inSlot={InSlot}");
        Assert_True(HookEmpty, "the client's hook is still empty");
        Assert_True(InSlot, "the client's slot 0 still holds the lantern");
        FinishSuccess();
    }

    private bool Get_IsLanternInSlot()
    {
        return Get_SlotItemCount(0) == 1 && _Carrier.Hotbar.Get_ItemAt(0) == _Lantern;
    }
}
