// The server's food court emerges one rat, whose first lease takes the Mushroom out of cargo slot 1: the food's own
// body rides the rat's mouth (Carried on the rat at AttachPoint.Mars.RatMouth, no carry visual). The client's copy
// shows the same from its replicated pocket: the Mushroom in its pocket, the food's copy Carried on the rat's copy at
// the mouth, settled on the mouth node, its pickup disabled, and no Visual Mushroom anywhere. The server then fells its
// rat with its own swing (its zone is its own, so no claim is sent): the food is released once, lies World with its
// pickup enabled, and on the client the pocket empties and the one World-mode Mushroom is the food, its pickup enabled.
// Surface: Ck.PantryRat.Net.AS_PantryRat_ACopyCarriesAStolenFoodOnItsMouthAndSeesItDropped
class UCk_AutoTest_Net_PantryRat_ACopyCarriesAStolenFoodOnItsMouthAndSeesItDropped : UMars_AutoTestRig_NetPantryRatLoot
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(687000.0, 0.0, 5000.0);
    private const FString k_Row = "ACopyCarriesAStolenFoodOnItsMouthAndSeesItDropped";
    private const float32 k_TheftSeconds = 20.0f;
    private const float32 k_DeathSeconds = 5.0f;
    private const float64 k_OnMouthCm = 1.0;

    // The client's reading of its carry as it asserted it.
    private FString _CarriedText;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_LootRow(k_Base, k_CourtHandFromBase);
        _RowLootDefinition = mars_items::Food_Mushroom();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerArmed(n"OnServerArmed");
    }

    private FString Describe_Mushrooms()
    {
        const auto World = Count_WorldItemsOf(Make_ItemQuery(mars_items::Food_Mushroom(), EMars_WorldItem_Mode::World, _Base));
        const auto Visual = Count_WorldItemsOf(Make_ItemQuery(mars_items::Food_Mushroom(), EMars_WorldItem_Mode::Visual, _Base));
        return f"mushrooms=[world {World} visual {Visual}] {Describe_CourtFrames()}";
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = Make_RowSpec();
        Spec.Population.MaxActiveRats = 1;
        Begin_ServerFoodCourt(Spec, n"OnServerRatOut");
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
        if (Get_IsRowRatGone() || _RowRat.Get_Phase() != EMars_PantryRat_Phase::FleeWithLoot)
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Mushrooms()}");
            FinishFailure("the server's rat never fled with its loot");
            return;
        }

        Assert_True(_RowRat.Get_HasCarryReceipt(), "the server's rat has its carry receipt");
        Assert_True(_RowRat.Get_Loot() == _RowFoodItem, "the server's rat's loot is the Mushroom");
        Assert_True(Get_IsRowFoodOnRat(), "the server's food is Carried on its rat at AttachPoint.Mars.RatMouth");
        Assert_False(ck::IsValid(_RowRat.Get_CarryVisual()), "the server's rat has no carry visual");
        Wait_RowSampling(k_ComposeSeconds, n"OnServerCarried");
    }

    UFUNCTION()
    private void OnServerCarried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _HandMode = EMars_NetRatTest_Hand::FollowsRat;
        WaitUntil(n"Is_RowRatSweepable", n"OnServerSweepable", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSweepable(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Swing_AtRowRat(EMars_NetRatTest_Swing::Claimed);
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
        if (Get_IsRowRatGone() || Get_IsRowFoodGone())
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Mushrooms()}");
            FinishFailure("the server's rat or food was gone before it asserted the drop");
            return;
        }

        const auto Death = _RowRat.Get_Death();
        Assert_True(_RowRat.Get_IsDead(), "the server's rat is dead");
        Assert_Equals_Int(Death.ReleaseOperationId, 1, "the server's rat released once");
        Assert_True(Death.ReleaseReceipt, "the server's rat has its release receipt");
        Assert_True(_RowFood.Get_Mount() == EMars_WorldItem_Mount::World, "the server's food lies World");
        Assert_True(_RowFood.Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Enable, "the server's food's pickup is enabled");
        Assert_True(_RowFood.Get_HeldItem() == _RowFoodItem, "the server's food holds the Mushroom");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::Food_Mushroom(), EMars_WorldItem_Mode::World, _Base)), 1,
            "one World-mode Mushroom lies within 1000 of the server's base");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::Food_Mushroom(), EMars_WorldItem_Mode::Visual, _Base)), 0,
            "no Visual-mode Mushroom is within 1000 of the server's base");
        Hold_LootServerRow(k_Row, Describe_Mushrooms());
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientFoodOnRat", n"OnClientCarried", k_SlowPolls);
    }

    // The client recorded its rat's flight and its food rides its rat's mouth.
    UFUNCTION()
    private void Is_ClientFoodOnRat(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Get_IsRatRecorded(EMars_PantryRat_Phase::FleeWithLoot) && Get_IsRowFoodOnRat());
    }

    UFUNCTION()
    private void OnClientCarried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientCarrySettled");
    }

    UFUNCTION()
    private void OnClientCarrySettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone() || Get_IsRowFoodGone())
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Mushrooms()}");
            FinishFailure("the client's rat or food was gone before it asserted the carry");
            return;
        }

        const auto Mouth = utils_transform::Get_EntityCurrentLocation(_RowRat.Get_MouthNode());
        const auto FromMouth = (Get_RowRootLocation(_RowFood) - Mouth).Size();
        const auto FledFrame = Get_RatRecordedFrame(EMars_PantryRat_Phase::FleeWithLoot);
        Assert_True(FledFrame >= 0, "the client recorded its rat's flight");
        Assert_True(_RowFoodFoundFrame >= 0 && _RowFoodFoundFrame < FledFrame, "the client found its food before the theft");
        Assert_True(Get_IsRowPocketHolding(mars_items::Food_Mushroom()), "the client's pocket holds one item, of the Mushroom's definition");
        Assert_True(Get_IsRowFoodOnRat(), "the client's food is Carried on its rat copy at AttachPoint.Mars.RatMouth");
        Assert_True(_RowFood.Get_IsSettled(), "the client's food is settled on the mouth");
        Assert_True(FromMouth <= k_OnMouthCm, f"the client's food's root is within 1 cm of its rat's mouth node (reads {FromMouth})");
        Assert_True(_RowFood.Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Disable, "the client's food's pickup is disabled");
        Assert_False(ck::IsValid(_RowRat.Get_CarryVisual()), "the client's rat has no carry visual");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::Food_Mushroom(), EMars_WorldItem_Mode::Visual, _Base)), 0,
            "no Visual-mode Mushroom is within 1000 of the client's base");
        _CarriedText = f"carried=[fromMouth {FromMouth} {Describe_Loot()} {Describe_Mushrooms()}]";
        WaitUntil(n"Is_ClientFoodDropped", n"OnClientDropped", k_SlowPolls);
    }

    // The client's rat reads a dead phase (or is gone) and its food lies World.
    UFUNCTION()
    private void Is_ClientFoodDropped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Row();
        const auto Dead = Get_IsRowRatGone() || _RowRat.Get_IsDead();
        const auto World = Get_IsRowFoodGone() == false && _RowFood.Get_Mount() == EMars_WorldItem_Mount::World;
        auto Result = OutResult;
        Result.Set(Dead && World);
    }

    UFUNCTION()
    private void OnClientDropped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientDropSettled");
    }

    UFUNCTION()
    private void OnClientDropSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone() || Get_IsRowFoodGone())
        {
            Log_RatRow(k_Row, f"{Describe_Loot()} {Describe_Mushrooms()} {_CarriedText}");
            FinishFailure("the client's rat or food was gone before it asserted the drop");
            return;
        }

        Assert_Equals_Int(Get_RowPocketCount(), 0, "the client's pocket is empty");
        Assert_True(_RowFood.Get_Mount() == EMars_WorldItem_Mount::World, "the client's food lies World");
        Assert_True(_RowFood.Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Enable, "the client's food's pickup is enabled");
        Assert_Equals_Int(Count_WorldItemsOf(Make_ItemQuery(mars_items::Food_Mushroom(), EMars_WorldItem_Mode::World, _Base)), 1,
            "one World-mode Mushroom lies within 1000 of the client's base");
        Finish_LootRow(k_Row, f"{Describe_Mushrooms()} {_CarriedText}");
    }
}
