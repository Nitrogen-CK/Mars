// A client that calls a selection request mixin on its own copy of the hotbar changes nothing anywhere: the drain applies
// requests only on the authority and drops a client's, so the server keeps slot 0 selected and so does the client's
// replicated copy. Client intent travels as Cue.Mars.Hotbar.Select instead (ClientSelectCueRoundTrips).
// Surface: Ck.Hotbar.Net.AS_Hotbar_ClientRequestIsDropped
class UCk_AutoTest_Net_Hotbar_ClientRequestIsDropped : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_HandLocation = FVector(24600.0, 0.0, 5080.0);
    // Long enough for the client to request and for a wrongful change to have replicated back.
    private const float32 k_WatchSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Compose_HotbarCarrier(k_HandLocation, 2);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_SeededAndOnSlotZero", n"OnClientSeeded", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_HotbarReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Rock());
        Seed_ServerSlotWith(1, mars_items::Cog());
        WaitUntil(n"Is_SeededAndOnSlotZero", n"OnServerSeeded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_SeededAndOnSlotZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_SlotHolds(0, mars_items::Rock()) && Get_SlotHolds(1, mars_items::Cog())
            && _Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_WatchSeconds * 2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(0), "the server's hotbar kept slot 0 selected");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Carrier.Hotbar), "the client's hotbar has no authority");
        _Carrier.Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
        WaitSeconds(k_WatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Carrier.Hotbar.Has_Fragment(FMars_Fragment_Hotbar_Requests), "the client's drain dropped its request");
        Assert_True(_Carrier.Hotbar.Get_SelectedIndex() == TOptional<int32>(0), "the client's copy still reads slot 0 selected");
        FinishSuccess();
    }
}
