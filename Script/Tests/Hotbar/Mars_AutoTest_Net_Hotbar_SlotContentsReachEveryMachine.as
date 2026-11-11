// Each slot of a replicated carrier's hotbar is a root of its own, so its contents replicate on their own: the server
// seeds a rock into slot 0 and a cog into slot 1, and the client's copy holds exactly the rock in slot 0, the cog in slot
// 1 and nothing in the overflow, each slot on a replicated slot root under the client's subject. Before slot roots, the
// slots shared one owner and the last one written overwrote the others on every client.
// Surface: Ck.Hotbar.Net.AS_Hotbar_SlotContentsReachEveryMachine
class UCk_AutoTest_Net_Hotbar_SlotContentsReachEveryMachine : UMars_AutoTestRig_NetHotbar
{
    private const FVector k_HandLocation = FVector(23000.0, 0.0, 5080.0);
    // The client's copy has to settle: a later write would show as a second item or a swapped slot.
    private const float32 k_ClientSettleSeconds = 1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Compose_HotbarCarrier(k_HandLocation, 2);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientFilled", n"OnClientFilled", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_HotbarReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsReplicatedSlotOfTheSubject(0) && Get_IsReplicatedSlotOfTheSubject(1) && Get_IsReplicatedSlotOfTheSubject(2),
            "the server's slots are replicated slot roots under the subject");
        Seed_ServerSlotWith(0, mars_items::Rock());
        Seed_ServerSlotWith(1, mars_items::Cog());
        WaitUntil(n"Is_ServerFilled", n"OnServerFilled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_SlotHolds(0, mars_items::Rock()) && Get_SlotHolds(1, mars_items::Cog()));
    }

    UFUNCTION()
    private void OnServerFilled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + k_ClientSettleSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void Is_ClientFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_SlotItemCount(0) > 0 && Get_SlotItemCount(1) > 0);
    }

    UFUNCTION()
    private void OnClientFilled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Rock = _Carrier.Hotbar.Get_ItemAt(0);
        const auto Cog = _Carrier.Hotbar.Get_ItemAt(1);
        Log(f"[MarsNet] hotbar slots on the client: slot0={Get_SlotItemCount(0)} slot1={Get_SlotItemCount(1)} "
            + f"overflow={Get_SlotItemCount(2)}");

        Assert_False(utils_net::Get_HasAuthority(_Carrier.Hotbar), "the client's hotbar has no authority");
        Assert_True(Get_IsReplicatedSlotOfTheSubject(0) && Get_IsReplicatedSlotOfTheSubject(1) && Get_IsReplicatedSlotOfTheSubject(2),
            "the client's slots are replicated slot roots under its subject");
        Assert_True(Get_SlotHolds(0, mars_items::Rock()), "the client's slot 0 holds exactly the rock");
        Assert_True(Get_SlotHolds(1, mars_items::Cog()), "the client's slot 1 holds exactly the cog");
        Assert_Equals_Int(Get_SlotItemCount(2), 0, "the client's overflow slot is empty");
        Assert_False(Rock == Cog, "the two slots hold two distinct items");
        FinishSuccess();
    }
}
