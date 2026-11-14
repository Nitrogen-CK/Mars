// The client asks its den copy to emerge, to mark a rat outside, to let a resident die, to admit a return and to hide
// its eyes, and its raid copy to spawn a rat, to record a death and a homecoming, and to release and grant a lease: a
// machine without authority drops every one of them, so neither copy changes, counts or raises anything, and the
// server's den, raid and world never change.
// Surface: Ck.PantryRaid.Net.AS_PantryRaid_AClientsRequestsAreDropped
class UCk_AutoTest_Net_PantryRaid_AClientsRequestsAreDropped : UMars_AutoTestRig_NetPantryRaid
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(672000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const FString k_Row = "AClientsRequestsAreDropped";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRaidAndDenFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerRaid(Make_RowSpec());
        Spawn_ServerDen(2);
        WaitUntil(n"Is_RowRaidAndDenFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_RowDen.Get_SlotCountIn(EMars_RatDen_SlotState::Dormant), 2, "the server's den: both residents Dormant");
        Assert_True(Get_IsRowEyeSlot(0), "the server's den: eye slot 0");
        Assert_Equals_Int(_RowDen.Get_StaleRequests(), 0, "the server's den counted no stale request");
        Assert_Equals_Int(_EmergeReadySignals + _ReturnRefusedSignals + _EyeChanges.Num(), 0, "the server's den raised nothing");
        Assert_Equals_Int(_RowRaid.Get_RatCount(), 0, "the server's raid has no rat");
        Assert_Equals_Int(_RowRaid.Get_StaleSpawns(), 0, "the server's raid counted no stale spawn");
        Assert_Equals_Int(_RowRaid.Get_LeasesGranted(), 0, "the server's raid granted no lease");
        Assert_Equals_Int(Count_RatsHere(), 0, "no rat exists on the server");
        Hold_PantryServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle RaidEntity = _RowRaid;
        FCk_Handle DenEntity = _RowDen;
        _RowDen.Request_Emerge(FMars_Request_RatDen_Emerge(5, 0.0f));
        _RowDen.Request_MarkOutside(FMars_Request_RatDen_MarkOutside(0, 5));
        _RowDen.Request_ResidentDied(FMars_Request_RatDen_ResidentDied(0, 5, 0.0f));
        _RowDen.Request_AdmitReturn(FMars_Request_RatDen_AdmitReturn(RaidEntity, 0, 5));
        _RowDen.Request_SetEyes(FMars_Request_RatDen_SetEyes(false));
        _RowRaid.Request_SpawnRat(FMars_Request_PantryRaid_SpawnRat(_RowDen, 0, 1));
        _RowRaid.Request_RatDied(FMars_Request_PantryRaid_RatDied(DenEntity));
        _RowRaid.Request_RatHome(FMars_Request_PantryRaid_RatHome(DenEntity));
        _RowRaid.Request_ReleaseLease(FMars_Request_PantryRaid_ReleaseLease(DenEntity, 1));
        _RowRaid.Request_GrantLease(FMars_Request_PantryRaid_GrantLease(DenEntity, FCk_Handle_WorldItem(), 1, FCk_Handle_Item()));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowEnding(_RowRaid) || Get_IsRowEnding(_RowDen))
        {
            Log_PantryRow(k_Row, "copies=gone");
            FinishFailure("the client's copies were gone before it asserted");
            return;
        }

        Assert_False(_RowDen.Has_Fragment(FMars_Fragment_RatDen_Requests), "the client's den copy carries no requests");
        Assert_False(_RowRaid.Has_Fragment(FMars_Fragment_PantryRaid_Requests), "the client's raid copy carries no requests");
        Assert_True(Get_IsRowEyeSlot(0), "the client's den copy: eye slot 0");
        Assert_Equals_Int(_RowDen.Get_StaleRequests(), 0, "the client's den copy counted no stale request");
        Assert_Equals_Int(_RowDen.Get_RefusedReturns(), 0, "the client's den copy refused no return");
        Assert_Equals_Int(_EmergeReadySignals + _ReturnRefusedSignals + _EyeChanges.Num(), 0, "the client's den copy raised nothing");
        Assert_Equals_Int(_RowRaid.Get_StaleSpawns(), 0, "the client's raid copy counted no stale spawn");
        Assert_Equals_Int(_RowRaid.Get_RatCount(), 0, "the client's raid copy has no rat record");
        Assert_Equals_Int(_RatSpawnedSignals, 0, "the client's raid copy never raised OnRatSpawned");
        Assert_Equals_Int(Count_RatsHere(), 0, "no rat exists on the client");
        Finish_PantryRow(k_Row, "");
    }
}
