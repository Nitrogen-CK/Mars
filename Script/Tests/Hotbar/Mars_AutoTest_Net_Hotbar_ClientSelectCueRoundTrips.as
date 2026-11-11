// A client's selection crosses as Cue.Mars.Hotbar.Select with the absolute target: with a rock in slot 0 (selected by
// the arrival rule) and a cog in slot 1, the client fires the cue for a Select of slot 1 from its own view; the server's
// hotbar applies slot 1, and the client's copy reads it back through the replicated ledger and holds its cog.
// Surface: Ck.Hotbar.Net.AS_Hotbar_ClientSelectCueRoundTrips
class UCk_AutoTest_Net_Hotbar_ClientSelectCueRoundTrips : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_HandLocation = FVector(24200.0, 0.0, 5080.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Compose_HotbarCarrier(k_HandLocation, 2);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientSeededAndOnSlotZero", n"OnClientSeeded", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_HotbarReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Rock());
        Seed_ServerSlotWith(1, mars_items::Cog());
        WaitUntil(n"Is_ServerOnSlotOne", n"OnServerOnSlotOne", k_SlowPolls);
    }

    // Only the client's cue moves the server's selection to slot 1.
    UFUNCTION()
    private void Is_ServerOnSlotOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(1));
    }

    UFUNCTION()
    private void OnServerOnSlotOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_SlotHolds(1, mars_items::Cog()), "the server's slot 1 still holds the cog");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void Is_ClientSeededAndOnSlotZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_SlotHolds(0, mars_items::Rock()) && Get_SlotHolds(1, mars_items::Cog())
            && _Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    private void OnClientSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Carrier.Hotbar), "the client's hotbar has no authority");
        utils_hotbar::Fire_SelectCue(_Carrier.Hotbar, FMars_Hotbar_SelectionChangeRequest(FMars_Request_Hotbar_Select(1)));
        WaitUntil(n"Is_ClientOnSlotOne", n"OnClientOnSlotOne", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientOnSlotOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(1)
            && _Carrier.HeldItem.Get_CurrentItem() == _Carrier.Hotbar.Get_ItemAt(1));
    }

    UFUNCTION()
    private void OnClientOnSlotOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_SlotHolds(1, mars_items::Cog()), "the client holds its cog from slot 1");
        FinishSuccess();
    }
}
