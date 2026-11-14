// The client asks its copy of a disguised Pickle Mimic to stand, to gape, to drive, to bite, to cancel and to take a
// hit: a machine without authority drops every one of them, so its copy stays tucked, shut, unflinching and where it
// was, and the server's mimic and ledger never change.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_AClientsRequestsAreDropped
class UCk_AutoTest_Net_PickleMimic_AClientsRequestsAreDropped : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(615000.0, 0.0, 5000.0);
    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const float32 k_ClientHit = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MimicFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMimic(Make_RowSpec());
        WaitUntil(n"Is_MimicFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Mimic.Get_IsTucked(), "the server's mimic sits tucked");
        Assert_True(Get_HasMimicLedger(), "the server's mimic has its ledger");
        const auto Ledger = Get_MimicLedger();
        Assert_True(Ledger.Stance == EMars_PickleMimic_Stance::Tucked, "the server's ledger reads Tucked");
        Assert_True(Ledger.Gape == 0.0f, "the server's ledger reads a gape of 0");
        Assert_Equals_Int(_Mimic.Get_Hurt().FlinchCount, 0, "the server's mimic never flinched");
        Hold_MimicServerRow("AClientsRequestsAreDropped", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Mimic;
        _Mimic.Request_SetStance(FMars_Request_PickleMimic_SetStance(EMars_PickleMimic_Stance::Standing));
        _Mimic.Request_Gape(FMars_Request_PickleMimic_Gape(1.0f));
        _Mimic.Request_Drive(FMars_Request_PickleMimic_Drive(FVector::ForwardVector, 200.0f));
        _Mimic.Request_Start(FMars_Request_PickleMimic_Start(EMars_PickleMimic_Action::Bite, Root));
        _Mimic.Request_Cancel(FMars_Request_PickleMimic_Cancel());
        _Mimic.Request_TakeHit(FMars_Request_PickleMimic_TakeHit(FMars_DamageEvent(k_ClientHit, GameplayTags::DamageType_Mars_Sever)));
        WaitSampling(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Moved = (_Mimic.Get_Location() - _MimicFoundAt).Size();
        Assert_True(_Mimic.Get_IsTucked(), "the client's mimic sits tucked");
        Assert_True(_Mimic.Get_Rise() == 0.0f, "the client's Rise reads 0");
        Assert_True(_Mimic.Get_LidOpen() == 0.0f, "the client's lid reads 0");
        Assert_True(Moved <= 5.0, f"the client's root is within 5 of where it was found (moved {Moved})");
        Assert_False(_Mimic.Has_Fragment(FMars_Fragment_PickleMimic_Requests), "the client's copy carries no requests");
        Assert_Equals_Int(_Mimic.Get_Hurt().FlinchCount, 0, "the client's copy reads no flinch");
        Assert_False(_MimicEverFlinched, "the client's copy never read flinching");
        Finish_MimicRow("AClientsRequestsAreDropped", "");
    }
}
