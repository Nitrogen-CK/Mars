// A client that calls the drop request mixin on its own copy of the carrier changes nothing anywhere: the HeldItemUse
// drain launches only on the authority and drops a client's Drop and Throw, so no world item spawns and the server's
// hands keep the rock. Client intent travels as Cue.Mars.HeldItemUse.Launch instead (ThrownBodyLandsOnTheHost).
// Weak spot: until the hotbar replicates, the client's own HeldItem holds nothing, so its launch would find no item even
// without the gate; the server half (its hands still full, nothing spawned) is what pins that nothing crossed.
// Surface: Ck.WorldItem.Net.AS_WorldItem_ClientDropRequestIsDropped
class UCk_AutoTest_Net_WorldItem_ClientDropRequestIsDropped : UMars_AutoTestRig_NetWorldItem
{
    private const FVector k_HandLocation = FVector(21000.0, 0.0, 5080.0);
    // Long enough for the client to request and for a wrongful launch to have spawned.
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    private FMars_TESTONLY_NetCarrier _Carrier;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _Carrier = Compose_Carrier(k_HandLocation, 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitSeconds(k_ClientWatchSeconds, n"OnClientRequest");
            return;
        }

        Seed_ServerSlot(_Carrier.Hotbar, 0);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(ck::IsValid(_Carrier.Hotbar.Get_ItemAt(0)), "the server's slot still holds the rock");
        Assert_True(ck::Is_NOT_Valid(Find_WorldItemNear(k_HandLocation)), "no world item spawned on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientRequest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Carrier.Use), "the client's carrier has no authority");
        _Carrier.Use.Request_Drop(FMars_Request_HeldItemUse_Drop());
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Carrier.Use.Has_Fragment(FMars_Fragment_HeldItemUse_Requests), "the client's drain dropped its request");
        Assert_True(ck::Is_NOT_Valid(Find_WorldItemNear(k_HandLocation)), "no world item reached the client");
        FinishSuccess();
    }
}
