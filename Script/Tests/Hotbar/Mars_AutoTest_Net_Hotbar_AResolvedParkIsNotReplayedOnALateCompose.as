// A park the authority already resolved is history, not a pending eject: the server parks a selection behind an occupied
// overflow (the eject serial advances to 1), then the overflow item is removed and the parked selection applies. Only
// then does the client compose its hotbar, onto a ledger that already reads serial 1 and nothing parked. Its mirror
// raises OnSelectionChanged once for the selection that arrived and never OnOverflowEjectRequested: an eject answered
// with a drop here would throw away whatever the chef holds now.
// Surface: Ck.Hotbar.Net.AS_Hotbar_AResolvedParkIsNotReplayedOnALateCompose
class UCk_AutoTest_Net_Hotbar_AResolvedParkIsNotReplayedOnALateCompose : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 18.0f;

    private const FVector k_HandLocation = FVector(25800.0, 0.0, 5080.0);
    // After the client's hotbar is ready: a replayed eject would land in this window.
    private const float32 k_ClientSettleSeconds = 1.0f;
    // The server outlives the client's late compose, its slot adoption and its settle.
    private const float32 k_ServerOutliveSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ResolvedParkOnTheSubject", n"OnClientSawTheResolvedPark", k_SlowPolls);
            return;
        }

        Compose_HotbarCarrier(k_HandLocation, 1);
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
        WaitUntil(n"Is_ServerParked", n"OnServerParked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerParked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto& Ledger = _Carrier.Hotbar.Get_Fragment(FMars_Fragment_Hotbar);
        auto Result = OutResult;
        Result.Set(Ledger.Park == EMars_Hotbar_Park::Parked && Ledger.EjectSerial == 1);
    }

    // The overflow item goes (as a drop would take it), so the sync pass applies the parked bag slot.
    UFUNCTION()
    private void OnServerParked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_EjectRequests, 1, "the server's drain asked for the eject once");

        const auto OverflowIndex = _Carrier.Hotbar.Get_OverflowIndex();
        auto Overflow = _Carrier.Hotbar.Get_Slot(OverflowIndex);
        auto Request = FCk_Request_Inventory_RemoveItem(_Carrier.Hotbar.Get_ItemAt(OverflowIndex));
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Overflow.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
        WaitUntil(n"Is_ResolvedParkOnTheSubject", n"OnServerResolved", k_SlowPolls);
    }

    // Both machines, read off the subject (the client has composed no hotbar yet: the ledger arrives as the fragment
    // itself): one park happened, nothing is parked any more and the bag slot it asked for is selected.
    UFUNCTION()
    private void Is_ResolvedParkOnTheSubject(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_Hotbar) == false)
        {
            Result.Set(false);
            return;
        }

        const auto& Ledger = Subject.Get_Fragment(FMars_Fragment_Hotbar);
        Result.Set(Ledger.EjectSerial == 1 && Ledger.Park == EMars_Hotbar_Park::Nothing && Ledger.SelectedIndex == TOptional<int32>(0));
    }

    UFUNCTION()
    private void OnServerResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_EjectRequests, 1, "resolving the park asked for no second eject on the server");
        WaitSeconds(k_ServerHoldSeconds + k_ServerOutliveSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientSawTheResolvedPark(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Compose_HotbarCarrier(k_HandLocation, 1);
        WaitUntil(n"Is_HotbarReady", n"OnClientReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Carrier.Hotbar), "the client's hotbar has no authority");
        Assert_Equals_Int(_Carrier.Hotbar.Get_Fragment(FMars_Fragment_Hotbar).EjectSerial, 1, "the late client reads the one past park");
        Assert_False(_Carrier.Hotbar.TryGet_ParkedSelection().IsSet(), "nothing is parked on the late client");
        Assert_True(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(0), "the late client reads the selection the park resolved to");
        Assert_Equals_Int(_SelectionChanges, 1, "the late client raised OnSelectionChanged exactly once for it");
        Assert_Equals_Int(_EjectRequests, 0, "the late client raised no OnOverflowEjectRequested for the resolved park");
        FinishSuccess();
    }
}
