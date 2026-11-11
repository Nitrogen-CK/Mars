// A client that requests a Release on its own copy of a fig vine changes nothing: its drain drops the request (it has no
// authority), so after a settle the vine still holds its fig on both machines and no fig lies on either.
// Surface: Ck.Forage.Net.AS_Forage_AClientsReleaseIsDropped
class UCk_AutoTest_Net_Forage_AClientsReleaseIsDropped : UMars_AutoTestRig_NetForage
{
    private const FVector k_Base = FVector(69000.0, 0.0, 5000.0);
    private const float32 k_RegrowSeconds = 60.0f;
    // The server checks after the client has requested and settled.
    private const float32 k_ServerCheckSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_VineFound", n"OnClientVineFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFigVine(k_RegrowSeconds);
        WaitUntil(n"Is_VineFound", n"OnServerVineFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_VineFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourceFound(n"TAG_MarsForageVine"));
    }

    UFUNCTION()
    private void OnServerVineFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerCheckSeconds, n"OnServerChecked");
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_Untouched("server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientVineFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Plucked));
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_Untouched("client");
        FinishSuccess();
    }

    // Only the client logs: one line per test.
    private void Check_Untouched(FString InMachine)
    {
        const auto Charges = _Forage.Get_ChargesLeft();
        const auto ReleasedCount = _Forage.Get_ReleasedCount();
        const auto Figs = Count_WorldItemsNear(mars_items::Fig());
        Assert_Equals_Int(Charges, 1, f"the {InMachine}'s vine still holds its fig");
        Assert_Equals_Int(ReleasedCount, 0, f"the {InMachine}'s vine released nothing");
        Assert_Equals_Int(_Released, 0, f"the {InMachine} raised no OnReleased");
        Assert_Equals_Int(Figs, 0, f"no fig lies under the {InMachine}'s vine");
        if (Get_IsServer() == false)
        { Log(f"[ForageNetTest] AClientsReleaseIsDropped {InMachine} charges={Charges} released={ReleasedCount} signals={_Released} figs={Figs}"); }
    }
}
