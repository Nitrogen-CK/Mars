// The client claims one cleaver blow on a disguised Pickle Mimic's body zone: the authority applies it (its body Health
// reads 100 on both machines, the client's copy raising OnDamaged exactly once), the mimic flinches once, found Tucked,
// and is startled up; the client's copy reads the flinch from the ledger, pops its lid wide (at least 0.9) and stands
// with it.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_AClientsBlowWakesTheMimicOnBothMachines
class UCk_AutoTest_Net_PickleMimic_AClientsBlowWakesTheMimicOnBothMachines : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(618000.0, 0.0, 5000.0);
    // Inside the tucked jar's hurtbox (body frame: centre (0, 0, 36), half extents (32, 32, 40); the body 11 up).
    private const FVector k_ContactFromBase = FVector(-20.0, 0.0, 40.0);
    private const float32 k_StruckHealth = 100.0f;
    private const float32 k_RisingRise = 0.5f;
    private const float32 k_PoppedLid = 0.9f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Strike(k_Base);
        Spawn_MimicFloor();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToClaimTheMimic", n"OnClientReady", k_SlowPolls);
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
        Spawn_ServerMimic(Make_RowSpec());
        WaitUntil(n"Is_MimicFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerStruckAndUp", n"OnServerStruckAndUp", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerStruckAndUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_IsCurrent(k_StruckHealth) && _MimicStandingStances > 0);
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
        const auto Hurt = _Mimic.Get_Hurt();
        Assert_Equals_Int(Hurt.FlinchCount, 1, "the server's mimic flinched once");
        Assert_True(Hurt.FlinchFoundIn == EMars_PickleMimic_Stance::Tucked, "the server's flinch found the mimic tucked");
        Hold_MimicServerRow("AClientsBlowWakesTheMimicOnBothMachines", f"flinches={Hurt.FlinchCount} tally={Get_Tally().Applied}/{Get_Tally().Refused}");
    }

    UFUNCTION()
    private void Is_ClientReadyToClaimTheMimic(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsArmed() && Get_IsMimicFound());
    }

    // The client's copy's body zone, the cleaver, a contact inside the tucked jar, +X.
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
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_IsCurrent(k_StruckHealth) && _MimicHighestRise > k_RisingRise);
    }

    UFUNCTION()
    private void OnClientStruckAndRising(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Hurt = _Mimic.Get_Hurt();
        Assert_Equals_Int(_MimicDamaged, 1, "the client's copy's body Health raised OnDamaged exactly once");
        Assert_Equals_Int(Hurt.FlinchCount, 1, "the client's copy reads one flinch");
        Assert_True(Hurt.FlinchFoundIn == EMars_PickleMimic_Stance::Tucked, "the client's flinch found the mimic tucked");
        Assert_True(_MimicWidestSinceFlinch >= k_PoppedLid, f"the client's lid popped to at least 0.9 ({_MimicWidestSinceFlinch})");
        Finish_MimicRow("AClientsBlowWakesTheMimicOnBothMachines", "");
    }
}
