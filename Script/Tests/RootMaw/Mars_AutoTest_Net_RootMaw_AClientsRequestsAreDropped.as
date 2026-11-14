// The client asks its copy of a buried Root Maw to rise, to gape, to drive and to bite: a machine without authority
// drops every one of them, so its copy stays buried, shut and where it was, and the server's Maw and ledger never
// change.
// Surface: Ck.RootMaw.Net.AS_RootMaw_AClientsRequestsAreDropped
class UCk_AutoTest_Net_RootMaw_AClientsRequestsAreDropped : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(573000.0, 0.0, 5000.0);
    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(FMars_RootMaw_Spec());
        WaitUntil(n"Is_MawFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Maw.Get_IsBuried(), "the server's Maw lies buried");
        Assert_True(Get_HasMawLedger(), "the server's Maw has its ledger");
        const auto Ledger = Get_MawLedger();
        Assert_True(Ledger.Stance == EMars_RootMaw_Stance::Buried, "the server's ledger reads Buried");
        Assert_True(Ledger.Gape == 0.0f, "the server's ledger reads a gape of 0");
        Hold_MawServerRow("AClientsRequestsAreDropped", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Maw;
        _Maw.Request_SetStance(FMars_Request_RootMaw_SetStance(EMars_RootMaw_Stance::Emerged));
        _Maw.Request_Gape(FMars_Request_RootMaw_Gape(1.0f));
        _Maw.Request_Drive(FMars_Request_RootMaw_Drive(FVector::ForwardVector, 200.0f));
        _Maw.Request_Start(FMars_Request_RootMaw_Start(EMars_RootMaw_Action::Bite, Root));
        WaitSampling(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Moved = (_Maw.Get_Location() - _MawFoundAt).Size();
        Assert_True(_Maw.Get_IsBuried(), "the client's Maw lies buried");
        Assert_True(_Maw.Get_Emerge() == 0.0f, "the client's Emerge reads 0");
        Assert_True(_Maw.Get_JawOpen() == 0.0f, "the client's jaw reads 0");
        Assert_True(Moved <= 5.0, f"the client's root is within 5 of where it was found (moved {Moved})");
        Assert_False(_Maw.Has_Fragment(FMars_Fragment_RootMaw_Requests), "the client's copy carries no requests");
        Finish_MawRow("AClientsRequestsAreDropped", "");
    }
}
