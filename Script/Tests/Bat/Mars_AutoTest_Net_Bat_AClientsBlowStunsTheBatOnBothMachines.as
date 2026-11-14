// The client claims one cleaver blow on a roosting Cellar Bat's body zone: the authority applies it (its body Health
// reads 20 on both machines, the client's copy raising OnDamaged exactly once) and the bat is stunned or flinches,
// once; the client's copy shows that phase once from the ledger and counts no hit of its own.
// Surface: Ck.Bat.Net.AS_Bat_AClientsBlowStunsTheBatOnBothMachines
class UCk_AutoTest_Net_Bat_AClientsBlowStunsTheBatOnBothMachines : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(665000.0, 0.0, 5000.0);
    // Inside the hurtbox (root frame: centre (0, 0, 0), half extents (22, 34, 16)).
    private const FVector k_ContactFromHang = FVector(-20.0, 0.0, 0.0);
    private const float32 k_StruckHealth = 20.0f;

    // The frame the client fired its claim.
    private int32 _ClaimFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatStrikeRow(k_Floor);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToClaimTheBat", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    private int32 Count_Reactions() const
    {
        return Count_PhaseArrivals(EMars_Bat_Phase::Stunned) + Count_PhaseArrivals(EMars_Bat_Phase::Hit);
    }

    private FString Describe_Reaction() const
    {
        return f"stunned={Count_PhaseArrivals(EMars_Bat_Phase::Stunned)} hit={Count_PhaseArrivals(EMars_Bat_Phase::Hit)} claimFrame={_ClaimFrame}";
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
        Begin_ServerWorld(n"OnServerBatReady");
    }

    UFUNCTION()
    private void OnServerBatReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_StruckAndReacted", n"OnServerStruck", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_StruckAndReacted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && Get_IsCurrent(k_StruckHealth) && Count_Reactions() > 0);
    }

    UFUNCTION()
    private void OnServerStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Tally(1, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        Assert_Equals_Int(_Bat.Get_Hurt().HitCount, 1, "the server's bat was hit once");
        Hold_BatServerRow("AClientsBlowStunsTheBatOnBothMachines", f"{Describe_Reaction()} tally={Get_Tally().Applied}/{Get_Tally().Refused}");
    }

    UFUNCTION()
    private void Is_ClientReadyToClaimTheBat(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsArmed() && Get_IsBatFound());
    }

    // The client's copy's body zone, the cleaver, a contact inside the hurtbox, +X.
    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Address = _Zone.Get_Address();
        auto Claim = FMars_HeldItemUse_Strike();
        Claim.ZoneRoot = Address.Root;
        Claim.ZoneIndex = Address.Index;
        Claim.Item = utils_held_item::Make_DefinitionSoft(mars_items::Cleaver());
        Claim.Location = _HangAt + k_ContactFromHang;
        Claim.Normal = FVector(-1.0, 0.0, 0.0);
        Claim.Impulse = FVector::ForwardVector;
        _ClaimFrame = int32(utils_time::Get_FrameCounter());
        Fire_Claim(Claim);
        WaitUntil(n"Is_StruckAndReacted", n"OnClientStruck", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_BatDamaged, 1, "the client's copy's body Health raised OnDamaged exactly once");
        Assert_Equals_Int(Count_Reactions(), 1, "the client recorded Stunned or Hit exactly once");
        Assert_Equals_Int(_Bat.Get_Hurt().HitCount, 0, "the client's copy counts no hit of its own");
        Finish_BatRow("AClientsBlowStunsTheBatOnBothMachines", Describe_Reaction());
    }
}
