// A park decided on the authority reaches the owning machine: with a rock in the one bag slot and a cog in the overflow
// (which selects itself), the server selects the bag slot; the overflow is occupied, so the target is parked and the
// eject serial advances once. The client's replicated copy reads the parked selection and the serial, and its mirror
// raises OnOverflowEjectRequested exactly once; the overflow stays selected on both until someone drops the cog.
// Surface: Ck.Hotbar.Net.AS_Hotbar_OverflowParkReachesTheOwner
class UCk_AutoTest_Net_Hotbar_OverflowParkReachesTheOwner : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_HandLocation = FVector(25000.0, 0.0, 5080.0);
    // After the park arrives: a second signal from a re-sent or re-applied ledger would land in this window.
    private const float32 k_ClientSettleSeconds = 1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Compose_HotbarCarrier(k_HandLocation, 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_Parked", n"OnClientParked", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_HotbarReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Rock());
        Seed_ServerSlotWith(_Carrier.Hotbar.Get_OverflowIndex(), mars_items::Cog());
        WaitUntil(n"Is_ServerOnTheOverflow", n"OnServerOnTheOverflow", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOnTheOverflow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_SlotHolds(0, mars_items::Rock()) && Get_SlotHolds(_Carrier.Hotbar.Get_OverflowIndex(), mars_items::Cog())
            && _Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(_Carrier.Hotbar.Get_OverflowIndex()));
    }

    UFUNCTION()
    private void OnServerOnTheOverflow(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Carrier.Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
        WaitUntil(n"Is_Parked", n"OnServerParked", k_SlowPolls);
    }

    // The bag slot is parked behind the occupied overflow, which stays selected, and the serial advanced once.
    UFUNCTION()
    private void Is_Parked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_IsCarrierReady(_Carrier) == false)
        {
            auto NotYet = OutResult;
            NotYet.Set(false);
            return;
        }

        const auto Parked = _Carrier.Hotbar.TryGet_ParkedSelection();
        const auto& Ledger = _Carrier.Hotbar.Get_Fragment(FMars_Fragment_Hotbar);
        auto Result = OutResult;
        Result.Set(Parked.IsSet() && Parked.GetValue().Index == TOptional<int32>(0) && Ledger.EjectSerial == 1
            && _Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(_Carrier.Hotbar.Get_OverflowIndex()));
    }

    UFUNCTION()
    private void OnServerParked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_EjectRequests, 1, "the server's drain asked for the eject once");
        WaitSeconds(k_ServerHoldSeconds + k_ClientSettleSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientParked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Carrier.Hotbar), "the client's hotbar has no authority");
        Assert_Equals_Int(_Carrier.Hotbar.Get_Fragment(FMars_Fragment_Hotbar).EjectSerial, 1, "the client reads one park");
        Assert_Equals_Int(_EjectRequests, 1, "the client's mirror raised OnOverflowEjectRequested exactly once");
        Assert_True(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(_Carrier.Hotbar.Get_OverflowIndex()),
            "the overflow stays selected on the client");
        FinishSuccess();
    }
}
