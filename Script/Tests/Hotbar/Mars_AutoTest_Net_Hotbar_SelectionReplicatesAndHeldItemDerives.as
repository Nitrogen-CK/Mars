// The selection is the authority's and replicates with the hotbar's ledger: the server seeds a rock into slot 0 (the
// arrival rule selects it) and a cog into slot 1, then selects slot 1; the client's copy reads slot 1 selected, raised
// OnSelectionChanged from what replicated, and its HeldItem, derived on the client, holds the client's cog.
// Surface: Ck.Hotbar.Net.AS_Hotbar_SelectionReplicatesAndHeldItemDerives
class UCk_AutoTest_Net_Hotbar_SelectionReplicatesAndHeldItemDerives : UMars_AutoTestRig_NetHotbar
{
    private const FVector k_HandLocation = FVector(23400.0, 0.0, 5080.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Compose_HotbarCarrier(k_HandLocation, 2);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientHoldsTheCog", n"OnClientHoldsTheCog", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_HotbarReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Rock());
        Seed_ServerSlotWith(1, mars_items::Cog());
        WaitUntil(n"Is_ServerSeeded", n"OnServerSeeded", k_SlowPolls);
    }

    // Both seeded and the arrival rule has selected slot 0.
    UFUNCTION()
    private void Is_ServerSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_SlotHolds(0, mars_items::Rock()) && Get_SlotHolds(1, mars_items::Cog())
            && _Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Carrier.Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
        WaitUntil(n"Is_ServerHoldsTheCog", n"OnServerHoldsTheCog", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHoldsTheCog(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Carrier.HeldItem.Get_CurrentItem() == _Carrier.Hotbar.Get_ItemAt(1) && ck::IsValid(_Carrier.Hotbar.Get_ItemAt(1)));
    }

    UFUNCTION()
    private void OnServerHoldsTheCog(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void Is_ClientHoldsTheCog(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && _Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(1)
            && ck::IsValid(_Carrier.HeldItem.Get_CurrentItem()));
    }

    UFUNCTION()
    private void OnClientHoldsTheCog(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Carrier.Hotbar), "the client's hotbar has no authority");
        Assert_True(_Carrier.HeldItem.Get_CurrentItem() == _Carrier.Hotbar.Get_ItemAt(1), "the client's HeldItem holds its own slot 1 item");
        Assert_True(Get_SlotHolds(1, mars_items::Cog()), "the client's slot 1 holds the cog");
        Assert_True(_SelectionChanges >= 1, f"the client's hotbar raised OnSelectionChanged from the replicated ledger (got {_SelectionChanges})");
        FinishSuccess();
    }
}
