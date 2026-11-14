// The server's born rat watches beside its den. The client's own sweep strikes its copy (its dealer deals the hit, the
// copy's zone drops it, and no claim is sent), then it claims a blow with a tenderizer the server's player does not
// hold: the server refuses it for the item. Nothing reaches the rat on either machine: it still watches, alive, its
// body Health 1 and invulnerable, its zone on, and no change is seen but its emergence into the watch.
// Surface: Ck.PantryRat.Net.AS_PantryRat_AContactOrARefusedClaimNeverKills
class UCk_AutoTest_Net_PantryRat_AContactOrARefusedClaimNeverKills : UMars_AutoTestRig_NetPantryRatLoot
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(690000.0, 0.0, 5000.0);
    private const FString k_Row = "AContactOrARefusedClaimNeverKills";
    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_ClaimAfterContactSeconds = 0.6f;
    private const float32 k_ClaimSettleSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_LootRow(k_Base, k_BornHandFromBase);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatReadyToStrike", n"OnClientReady", k_SlowPolls);
            return;
        }

        Begin_ServerArmed(n"OnServerArmed");
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ServerBornCourt(Make_RowSpec(), n"OnServerCourt");
    }

    UFUNCTION()
    private void OnServerCourt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto BornThrough = TArray<EMars_PantryRat_Phase>();
        BornThrough.Add(EMars_PantryRat_Phase::Observe);
        Spawn_ServerBornLootRat(BornThrough, EMars_NetRatTest_Born::Alive);
        WaitUntil(n"Is_RowRatFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, Describe_Loot());
            FinishFailure("the server's rat was gone before it asserted");
            return;
        }

        const auto Tally = _Striker.Use.Get_StrikeTally();
        const auto Death = _RowRat.Get_Death();
        auto Monster = _RowRat.Get_Monster();
        const auto Health = Monster.Get_BodyHealth();
        Assert_Equals_Int(Tally.Applied, 0, "the server applied no claim");
        Assert_Equals_Int(Tally.Refused, 1, "the server refused one claim");
        Assert_True(Tally.LastRefusal.IsSet() && Tally.LastRefusal.GetValue() == EMars_HeldItemUse_StrikeRefusal::ItemMismatch,
            "the server refused it for the item");
        Assert_True(_RowRat.Get_Phase() == EMars_PantryRat_Phase::Observe, "the server's rat still watches");
        Assert_Equals_Int(_RowRat.Get_PhaseChanges(), 1, "the server's rat changed phase once");
        Assert_False(_RowRat.Get_IsDead(), "the server's rat is not dead");
        Assert_Equals_Int(Death.Sequence, 0, "the server's rat took no lethal hit");
        Assert_False(Death.LethalPending, "the server's rat has no lethal hit pending");
        Assert_True(Math::IsNearlyEqual(Health.Get_Current(), 1.0f, 0.0001f), "the server's rat body Health reads 1");
        Assert_True(Health.Get_IsInvulnerable(), "the server's rat body Health is invulnerable");
        Assert_False(Monster.Get_IsDead(), "the server's monster is alive");
        Assert_Equals_Int(_RatDiedSignals, 0, "the server's monster never died");
        Hold_LootServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Swing_AtRowRat(EMars_NetRatTest_Swing::ContactOnly);
        Wait_RowSampling(k_ClaimAfterContactSeconds, n"OnClientContacted");
    }

    UFUNCTION()
    private void OnClientContacted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, Describe_Loot());
            FinishFailure("the client's rat was gone before it claimed");
            return;
        }

        Claim_RowRat(mars_items::Tenderizer());
        Wait_RowSampling(k_ClaimSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, Describe_Loot());
            FinishFailure("the client's rat was gone before it asserted");
            return;
        }

        auto Monster = _RowRat.Get_Monster();
        auto OnlyEmergence = _RatChanges.Num() <= 1;
        for (const auto& Change : _RatChanges)
        {
            if (Change.From != EMars_PantryRat_Phase::Emerge || Change.To != EMars_PantryRat_Phase::Observe)
            { OnlyEmergence = false; }
        }

        Assert_Equals_Int(_StrikerDealt, 1, "the client's dealer dealt its contact once");
        Assert_True(_RowRat.Get_Phase() == EMars_PantryRat_Phase::Observe, "the client's rat still watches");
        Assert_True(Get_RowRatLedger().Phase == EMars_PantryRat_Phase::Observe, "the client's ledger reads Observe");
        Assert_False(_RowRat.Get_IsDead(), "the client's rat is not dead");
        Assert_True(Math::IsNearlyEqual(Monster.Get_BodyHealth().Get_Current(), 1.0f, 0.0001f), "the client's rat body Health reads 1");
        Assert_False(Monster.Get_IsDead(), "the client's monster is alive");
        Assert_Equals_Int(_RatDiedSignals, 0, "the client's monster never died");
        Assert_True(Monster.Get_BodyZone().Get_IsEnabled(), "the client's body zone is enabled");
        Assert_True(OnlyEmergence, "the client recorded no change but its rat's emergence into the watch");
        Finish_LootRow(k_Row, "");
    }
}
