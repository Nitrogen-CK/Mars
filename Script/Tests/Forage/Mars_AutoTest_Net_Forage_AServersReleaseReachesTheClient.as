// A fig vine spawned on the listen host releases once on the server's request: the yield spawns on the server alone and
// replicates, the ledger reaches the client, and the client raises OnReleased once with the server's reason. Both
// machines then read the same charges and release count, and each has exactly one fig lying under the vine.
// Surface: Ck.Forage.Net.AS_Forage_AServersReleaseReachesTheClient
class UCk_AutoTest_Net_Forage_AServersReleaseReachesTheClient : UMars_AutoTestRig_NetForage
{
    private const FVector k_Base = FVector(68000.0, 0.0, 5000.0);
    // Long enough that nothing regrows inside the test.
    private const float32 k_RegrowSeconds = 60.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ReleaseSeenWithAFig", n"OnClientSawRelease", k_SlowPolls);
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

    // A settled interval after the find, so the act reaches the client's copy after the state it was born into.
    UFUNCTION()
    private void OnServerVineFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerReadyToRelease");
    }

    UFUNCTION()
    private void OnServerReadyToRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Knock));
        WaitUntil(n"Is_ReleaseSeenWithAFig", n"OnServerReleased", k_SlowPolls);
    }

    // This machine has its vine, has raised a release and has a fig near the vine.
    UFUNCTION()
    private void Is_ReleaseSeenWithAFig(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourceFound(n"TAG_MarsForageVine") && _Released > 0 && Count_WorldItemsNear(mars_items::Fig()) > 0);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_Ledger("server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientSawRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Source), "the client's vine has no authority");
        Assert_True(_LastReason.IsSet() && _LastReason.GetValue() == EMars_Forage_ReleaseReason::Knock, "the client's release carries the server's reason");
        Check_Ledger("client");
        FinishSuccess();
    }

    // Only the client logs: one line per test.
    private void Check_Ledger(FString InMachine)
    {
        const auto Charges = _Forage.Get_ChargesLeft();
        const auto ReleasedCount = _Forage.Get_ReleasedCount();
        const auto Figs = Count_WorldItemsNear(mars_items::Fig());
        const auto Ensures = Get_NewEnsures();
        Assert_Equals_Int(Charges, 0, f"the {InMachine}'s vine has no fig left");
        Assert_Equals_Int(ReleasedCount, 1, f"the {InMachine}'s vine released once");
        Assert_Equals_Int(_Released, 1, f"the {InMachine} raised OnReleased once");
        Assert_Equals_Int(Figs, 1, f"one fig lies under the {InMachine}'s vine");
        Assert_Equals_Int(Ensures, 0, f"no ensure on the {InMachine}");
        if (Get_IsServer() == false)
        { Log(f"[ForageNetTest] AServersReleaseReachesTheClient {InMachine} charges={Charges} released={ReleasedCount} signals={_Released} figs={Figs} ensures={Ensures}"); }
    }
}
