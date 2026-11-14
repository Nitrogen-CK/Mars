// The server's court emerges one rat, which steals the Monk's Rind and flees with it: its pocket holds the Rind and its
// carry visual (a Visual world item of the Rind) rides its mouth. The client's copy shows the same from its replicated
// pocket: one Rind in the pocket, read as its loot, and a carry visual of its own, a lifetime child of the copy, on the
// copy's mouth; the pack copy's slot is empty and no World-mode Rind lies about. The server then ends the raid: the rat
// goes with it on both machines, and with it its pocket and the Rind, so no Rind is left on either.
// Surface: Ck.PantryRat.Net.AS_PantryRat_ACopyCarriesTheStolenRindUntilItsRaidEnds
class UCk_AutoTest_Net_PantryRat_ACopyCarriesTheStolenRindUntilItsRaidEnds : UMars_AutoTestRig_NetPantryRatLoot
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(686000.0, 0.0, 5000.0);
    private const FString k_Row = "ACopyCarriesTheStolenRindUntilItsRaidEnds";
    private const float32 k_TheftSeconds = 20.0f;
    private const float32 k_RatGoneSeconds = 5.0f;

    private int32 _RaidEndedFrame = -1;
    // The client's reading of its carry as it asserted it (the rat is gone by its row's line).
    private FString _CarriedText;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_LootRow(k_Base, k_CourtHandFromBase);
        _RowLootDefinition = mars_items::MonksRind();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        auto Spec = Make_RowSpec();
        Spec.Population.MaxActiveRats = 1;
        Begin_ServerRatCourt(Spec, n"OnServerRatOut");
    }

    private FString Describe_Rinds()
    {
        const auto World = Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::World, _Base));
        const auto Visual = Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::Visual, _Base));
        auto SlotText = "noPack";
        if (Get_IsRowPackFound() && Get_IsRowEnding(_RowPack) == false)
        { SlotText = f"{ck::IsValid(_RowPack.Get_CargoSlot(1).Get_Item())}"; }

        return f"rinds=[world {World} visual {Visual} packSlot1Held {SlotText}] raidEnded@{_RaidEndedFrame} {Describe_CourtFrames()}";
    }

    UFUNCTION()
    private void OnServerRatOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Until = Make_RatUntil(EMars_NetRatTest_UntilKind::ReadsPhase, EMars_PantryRat_Phase::FleeWithLoot);
        Until.MaxSeconds = TOptional<float32>(k_TheftSeconds);
        Wait_RowRatUntil(Until, n"OnServerFled");
    }

    UFUNCTION()
    private void OnServerFled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerCarried");
    }

    UFUNCTION()
    private void OnServerCarried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone() || _RowRat.Get_IsLoaded() == false)
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Rinds()}");
            FinishFailure("the server's rat was gone or unloaded before it asserted its carry");
            return;
        }

        Assert_True(Get_IsRowPocketHolding(mars_items::MonksRind()) && Get_RowPocketItem() == _RowCheeseItem,
            "the server's pocket holds the Rind");
        Assert_True(Get_IsRowCarryVisual(EMars_WorldItem_Mode::Visual, mars_items::MonksRind()),
            "the server's carry visual is a Visual world item of the Rind");
        Assert_True(_CarryWorstCm.IsSet() && _CarryWorstCm.GetValue() < 1.0, "the server's carry visual rides the mouth within 1 cm");

        FCk_Handle RaidEntity = _RowRaid;
        utils_entity_lifetime::Request_DestroyEntity(RaidEntity);
        _RaidEndedFrame = int32(utils_time::Get_FrameCounter());
        auto Until = Make_RatUntil(EMars_NetRatTest_UntilKind::Gone, EMars_PantryRat_Phase::Emerge);
        Until.MaxSeconds = TOptional<float32>(k_RatGoneSeconds);
        Wait_RowRatUntil(Until, n"OnServerRatGone");
    }

    UFUNCTION()
    private void OnServerRatGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerEnded");
    }

    UFUNCTION()
    private void OnServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Slot = _RowPackEntity.As_Backpack().Get_CargoSlot(1);
        Assert_True(Get_IsRowRatGone(), "the server's rat went with its raid");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::World, _Base)), 0,
            "no World-mode Rind is left within 1000 of the server's base");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::Visual, _Base)), 0,
            "no Visual-mode Rind is left within 1000 of the server's base");
        Assert_False(ck::IsValid(Slot.Get_Item()), "the server's cargo slot 1 is empty");
        Hold_LootServerRow(k_Row, Describe_Rinds());
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::RecordedPhase, EMars_PantryRat_Phase::FleeWithLoot), n"OnClientFled");
    }

    UFUNCTION()
    private void OnClientFled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientCarried");
    }

    UFUNCTION()
    private void OnClientCarried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Rinds()}");
            FinishFailure("the client's rat was gone before it asserted its carry");
            return;
        }

        const auto PocketItem = Get_RowPocketItem();
        FCk_Handle RatEntity = _RowRat;
        const auto Visual = _RowRat.Get_CarryVisual();
        Assert_True(Get_IsRowPocketHolding(mars_items::MonksRind()), "the client's pocket holds one item, of the Rind's definition");
        Assert_True(ck::IsValid(PocketItem) && _RowRat.Get_Loot() == PocketItem, "the client's rat reads the pocket's item as its loot");
        Assert_True(_RowRat.Get_IsLoaded(), "the client's rat reads loaded");
        Assert_True(Get_IsRowCarryVisual(EMars_WorldItem_Mode::Visual, mars_items::MonksRind()),
            "the client's carry visual is a Visual world item of the Rind");
        Assert_True(ck::IsValid(Visual) && utils_entity_lifetime::Get_LifetimeOwner(Visual) == RatEntity,
            "the client's carry visual is a lifetime child of its rat");
        Assert_True(_CarryWorstCm.IsSet() && _CarryWorstCm.GetValue() < 1.0, "the client's carry visual rides the mouth within 1 cm");
        Assert_True(Get_IsRowPackFound() && ck::IsValid(_RowPack.Get_CargoSlot(1).Get_Item()) == false,
            "the client's pack copy's cargo slot 1 is empty");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::World, _Base)), 0,
            "no World-mode Rind lies within 1000 of the client's base");
        _CarriedText = f"carried=[{Describe_Loot()} {Describe_Rinds()}]";
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::Gone, EMars_PantryRat_Phase::Emerge), n"OnClientRatGone");
    }

    UFUNCTION()
    private void OnClientRatGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientEnded");
    }

    UFUNCTION()
    private void OnClientEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::World, _Base)), 0,
            "no World-mode Rind is left within 1000 of the client's base");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::MonksRind(), EMars_WorldItem_Mode::Visual, _Base)), 0,
            "no Visual-mode Rind is left within 1000 of the client's base");
        Assert_Equals_Int(Count_RatsHere(), 0, "no rat is left on the client");
        Finish_LootRow(k_Row, f"{Describe_Rinds()} {_CarriedText}");
    }
}
