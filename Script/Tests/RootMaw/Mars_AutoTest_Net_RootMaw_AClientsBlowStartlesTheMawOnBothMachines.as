// The client claims one cleaver blow on a buried Root Maw's body zone: the authority applies it (its body Health reads
// 120 on both machines, the client's copy raising OnDamaged exactly once), the Maw flinches once and is startled up,
// and the client's copy rises with it from the ledger.
// Surface: Ck.RootMaw.Net.AS_RootMaw_AClientsBlowStartlesTheMawOnBothMachines
class UCk_AutoTest_Net_RootMaw_AClientsBlowStartlesTheMawOnBothMachines : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(576000.0, 0.0, 5000.0);
    private const FVector k_ContactFromBase = FVector(-20.0, 0.0, 12.0);
    private const float32 k_StruckHealth = 120.0f;
    private const float32 k_RisingEmerge = 0.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Strike(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToClaimTheMaw", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Arm_Server();
        WaitUntil(n"Is_Armed", n"OnServerArmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(FMars_RootMaw_Spec());
        WaitUntil(n"Is_MawFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerStruckAndUp", n"OnServerStruckAndUp", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerStruckAndUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsCurrent(k_StruckHealth) && _MawEmergedStances > 0);
    }

    UFUNCTION()
    private void OnServerStruckAndUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Tally(1, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        const auto Flinches = _Maw.Get_Hurt().FlinchCount;
        Assert_Equals_Int(Flinches, 1, "the server's Maw flinched once");
        Hold_MawServerRow("AClientsBlowStartlesTheMawOnBothMachines", f"flinches={Flinches} tally={Get_Tally().Applied}/{Get_Tally().Refused}");
    }

    UFUNCTION()
    private void Is_ClientReadyToClaimTheMaw(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsArmed() && Get_IsMawFound());
    }

    // The client's copy's body zone, the cleaver, a contact on the buried bulb's crown, +X.
    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Address = _Zone.Get_Address();
        auto Claim = FMars_HeldItemUse_Strike();
        Claim.ZoneRoot = Address.Root;
        Claim.ZoneIndex = Address.Index;
        Claim.Item = utils_held_item::Make_DefinitionSoft(mars_items::Cleaver());
        Claim.Location = _Base + k_ContactFromBase;
        Claim.Normal = FVector(-1.0, 0.0, 0.0);
        Claim.Impulse = FVector::ForwardVector;
        Fire_Claim(Claim);
        WaitUntil(n"Is_ClientStruckAndRising", n"OnClientStruckAndRising", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientStruckAndRising(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsCurrent(k_StruckHealth) && _MawHighestEmerge > k_RisingEmerge);
    }

    UFUNCTION()
    private void OnClientStruckAndRising(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_MawDamaged, 1, "the client's copy's body Health raised OnDamaged exactly once");
        Finish_MawRow("AClientsBlowStartlesTheMawOnBothMachines", "");
    }
}
