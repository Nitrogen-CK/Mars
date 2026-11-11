// A client that composes its hotbar after the server already wrote the selection still reads it, and raises
// OnSelectionChanged once for it: the server seeds a cog into slot 1 (the arrival rule selects it) before the client has
// a hotbar at all; the client composes its carrier a second and a half later, and its mirror's reconcile at bind (or the
// notify that follows) delivers the selection the server wrote first. The closest the harness gets to a late join: the
// client's subject exists from the start.
// Surface: Ck.Hotbar.Net.AS_Hotbar_LateJoinSeesTheSelection
class UCk_AutoTest_Net_Hotbar_LateJoinSeesTheSelection : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 18.0f;

    private const FVector k_HandLocation = FVector(23800.0, 0.0, 5080.0);
    private const float32 k_ClientLateSeconds = 1.5f;
    private const float32 k_ClientSettleSeconds = 0.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitSeconds(k_ClientLateSeconds, n"OnClientLate");
            return;
        }

        Compose_HotbarCarrier(k_HandLocation, 2);
        WaitUntil(n"Is_HotbarReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(1, mars_items::Cog());
        WaitUntil(n"Is_ServerSelected", n"OnServerSelected", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(1));
    }

    UFUNCTION()
    private void OnServerSelected(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // Holds past the client's late compose and its settle.
        WaitSeconds(k_ClientLateSeconds + k_ServerHoldSeconds + 2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientLate(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Compose_HotbarCarrier(k_HandLocation, 2);
        WaitUntil(n"Is_ClientSelected", n"OnClientSelected", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && _Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(1));
    }

    UFUNCTION()
    private void OnClientSelected(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(1), "the late client reads the selection the server wrote first");
        Assert_Equals_Int(_SelectionChanges, 1, "the late client raised OnSelectionChanged exactly once for it");
        Assert_True(Get_SlotHolds(1, mars_items::Cog()), "the late client's slot 1 holds the cog");
        FinishSuccess();
    }
}
