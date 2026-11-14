// The server's court emerges one rat, which steals the Monk's Rind; the server's hand follows it. The moment the
// client sees it flee, the client claims one cleaver blow on its copy pushing +Y: the server applies it, the rat dies
// once (its ledger carries the blow's impulse), releases the Rind once into one World-mode world item at its corpse and
// holds; its den's slot cools down. The client's copy dies once from the ledger, its zone off, with the blow's impulse
// (which side it topples depends on the heading it fled on, so the side is left to the rows whose rat stands still),
// its pocket empty and its carry visual gone; one World-mode Rind lies at its corpse and no Visual one is left.
// Surface: Ck.PantryRat.Net.AS_PantryRat_AClientsBlowKillsALoadedRatAndTheRindDropsOnce
class UCk_AutoTest_Net_PantryRat_AClientsBlowKillsALoadedRatAndTheRindDropsOnce : UMars_AutoTestRig_NetPantryRatLoot
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(689000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsBlowKillsALoadedRatAndTheRindDropsOnce";
    private const float32 k_DeathSeconds = 25.0f;
    private const float64 k_AtCorpseCm = 300.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_LootRow(k_Base, k_CourtHandFromBase);
        _RowLootDefinition = mars_items::MonksRind();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatFoundAndArmed", n"OnClientReady", k_SlowPolls);
            return;
        }

        Begin_ServerArmed(n"OnServerArmed");
    }

    private FMars_NetRatTest_ItemQuery Make_CorpseQuery(EMars_WorldItem_Mode InMode)
    {
        auto Query = Make_ItemQuery(mars_items::MonksRind(), InMode, _Base);
        if (Get_IsRowRatGone() == false)
        {
            Query.Near = _RowRat.Get_Location();
            Query.Cm = k_AtCorpseCm;
        }

        return Query;
    }

    private FString Describe_Rinds()
    {
        const auto AtCorpse = Count_WorldItemsOf(Make_CorpseQuery(EMars_WorldItem_Mode::World));
        const auto World = Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::World, _Base));
        const auto Visual = Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::Visual, _Base));
        auto SlotText = "noPack";
        if (Get_IsRowPackFound() && Get_IsRowEnding(_RowPack) == false)
        { SlotText = f"{ck::IsValid(_RowPack.Get_CargoSlot(1).Get_Item())}"; }

        return f"rinds=[atCorpse {AtCorpse} world {World} visual {Visual} packSlot1Held {SlotText}] {Describe_CourtFrames()}";
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _HandMode = EMars_NetRatTest_Hand::FollowsRat;
        auto Spec = Make_RowSpec();
        Spec.Population.MaxActiveRats = 1;
        Begin_ServerRatCourt(Spec, n"OnServerRatOut");
    }

    UFUNCTION()
    private void OnServerRatOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Until = Make_RatUntil(EMars_NetRatTest_UntilKind::ReadsPhase, EMars_PantryRat_Phase::DeadHold);
        Until.MaxSeconds = TOptional<float32>(k_DeathSeconds);
        Wait_RowRatUntil(Until, n"OnServerDead");
    }

    UFUNCTION()
    private void OnServerDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerDropped");
    }

    UFUNCTION()
    private void OnServerDropped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Rinds()}");
            FinishFailure("the server's rat was gone before it asserted the drop");
            return;
        }

        const auto Tally = _Striker.Use.Get_StrikeTally();
        const auto Death = _RowRat.Get_Death();
        const auto Ledger = Get_RowRatLedger();
        const auto Dropped = Find_WorldItemOf(Make_CorpseQuery(EMars_WorldItem_Mode::World));
        Assert_Equals_Int(Tally.Applied, 1, "the server applied one claim");
        Assert_Equals_Int(Tally.Refused, 0, "the server refused no claim");
        Assert_True(_RowRat.Get_IsDead(), "the server's rat is dead");
        Assert_Equals_Int(Death.Sequence, 1, "the server's rat took one lethal hit");
        Assert_True(Get_IsImpulseNear(Ledger.HitImpulse, k_BlowImpulse),
            f"the server's ledger carries the blow's impulse (reads {Ledger.HitImpulse.ToString()})");
        Assert_True(Ledger.HitImpulse == Death.HitImpulse, "the server's ledger's impulse is its state's");
        Assert_Equals_Int(Death.ReleaseOperationId, 1, "the server's rat released once");
        Assert_True(Death.ReleaseReceipt, "the server's rat has its release receipt");
        Assert_Equals_Int(Get_RowPocketCount(), 0, "the server's pocket is empty");
        Assert_True(Get_IsRowCarryVisualGone(), "the server's rat has no carry visual");
        Assert_Equals_Int(Count_WorldItemsOf(Make_CorpseQuery(EMars_WorldItem_Mode::World)), 1,
            "one World-mode Rind lies within 300 of the server's corpse");
        Assert_True(ck::IsValid(Dropped) && Dropped.Get_HeldItem() == _RowCheeseItem, "the dropped world item holds the stolen Rind");
        Assert_True(_RowDen.Get_SlotState(0) == EMars_RatDen_SlotState::DeadCooldown, "the server's den slot 0 cools down");
        Assert_Equals_Int(_RatDiedSignals, 1, "the server's monster died once");
        Hold_LootServerRow(k_Row, Describe_Rinds());
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::RecordedPhase, EMars_PantryRat_Phase::FleeWithLoot), n"OnClientFled");
    }

    UFUNCTION()
    private void OnClientFled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Rinds()}");
            FinishFailure("the client's rat was gone before it claimed");
            return;
        }

        Claim_RowRat(mars_items::Cleaver());
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::RecordedPhase, EMars_PantryRat_Phase::DeadHold), n"OnClientDead");
    }

    UFUNCTION()
    private void OnClientDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Rinds()}");
            FinishFailure("the client's rat was gone before it asserted the drop");
            return;
        }

        auto ThroughDying = TArray<EMars_PantryRat_Phase>();
        ThroughDying.Add(EMars_PantryRat_Phase::Dying);
        ThroughDying.Add(EMars_PantryRat_Phase::DeadHold);
        auto ThroughRelease = TArray<EMars_PantryRat_Phase>();
        ThroughRelease.Add(EMars_PantryRat_Phase::LootReleasePending);
        ThroughRelease.Add(EMars_PantryRat_Phase::DeadHold);
        const auto Impulse = _RowRat.Get_Death().HitImpulse;
        Assert_True(_RowRat.Get_IsDead(), "the client's rat is dead");
        Assert_Equals_Int(_RatDiedSignals, 1, "the client's monster died once");
        Assert_False(_RowRat.Get_Monster().Get_BodyZone().Get_IsEnabled(), "the client's body zone is disabled");
        Assert_True(Get_IsRatRecordedInOrder(ThroughDying) || Get_IsRatRecordedInOrder(ThroughRelease),
            "the client recorded Dying or LootReleasePending, then DeadHold");
        Assert_True(Get_IsRatRecordChained(), "each of the client's changes starts where the one before ended");
        Assert_True(Get_IsImpulseNear(Impulse, k_BlowImpulse), f"the client's rat reads the blow's impulse (reads {Impulse.ToString()})");
        Assert_Equals_Int(Get_RowPocketCount(), 0, "the client's pocket is empty");
        Assert_True(Get_IsRowCarryVisualGone(), "the client's carry visual is gone");
        Assert_False(_RowRat.Get_IsLoaded(), "the client's rat reads unloaded");
        Assert_Equals_Int(Count_WorldItemsOf(Make_CorpseQuery(EMars_WorldItem_Mode::World)), 1,
            "one World-mode Rind lies within 300 of the client's corpse");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::Visual, _Base)), 0,
            "no Visual-mode Rind is left within 1000 of the client's base");
        Assert_True(Get_IsRowPackFound() && ck::IsValid(_RowPack.Get_CargoSlot(1).Get_Item()) == false,
            "the client's pack copy's cargo slot 1 is empty");
        Finish_LootRow(k_Row, Describe_Rinds());
    }
}
