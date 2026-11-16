// A drop and a consume of one held item take it once. In one drain the drop acts (it drains first) and the consume is
// refused as Leaving: one launch, nothing eaten, the launched ration still there 30 frames later. Across two drains the
// first acts: a consume, then a drop the next step, eats the ration and launches nothing. A bare carrier (Hand node, a
// hotbar of two bag slots, HeldItem, HeldItemUse); two rations. Isolated origin (54800, -17000, -30000).
class UMars_AutoTest_HeldItemUse_ADropAndAConsumeOfOneItemTakeItOnce : UMars_AutoTestRig_Carrier
{
    private const FVector k_Origin = FVector(54800.0, -17000.0, -30000.0);

    private FCk_Handle_HeldItemUse _Use;
    private TArray<FCk_Handle_Item> _LaunchedItems;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Use = utils_held_item_use::Add(_Carrier);
        _Use.BindTo_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnItemLaunched"));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Ration()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Ration()));

        Add_Step_WaitUntil("the holders hold their rations", n"Check_HoldersSeeded");
        Add_Step("stow the first ration into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold the first", n"Check_HoldingFirst", 0, 0);
        Add_Step("drop and consume it in the same frame", n"Step_DropAndConsume");
        Add_Step_WaitUntil("it launched and the hands are empty", n"Check_LaunchedAndEmpty", 0, 0);
        Add_Step("one launch, nothing eaten, the consume refused as Leaving", n"Step_AssertDropWon");
        Add_Step_WaitFrames("30 frames", 30);
        Add_Step("the launched ration is still there", n"Step_AssertLaunchedStillValid");
        Add_Step("stow the second ration into the hands", n"Step_StowSecond");
        Add_Step_WaitUntil("the hands hold the second", n"Check_HoldingSecond", 0, 0);
        Add_Step("consume it", n"Step_Consume");
        Add_Step("drop it a step later", n"Step_Drop");
        Add_Step_WaitUntil("the second ration is gone", n"Check_SecondGone", 0, 0);
        Add_Step("one consume applied, still one launch", n"Step_AssertConsumeWon");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnItemLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    {
        _LaunchedItems.Add(InItem);
    }

    private FMars_Request_HeldItemUse_Consume Make_RationConsume()
    {
        return FMars_Request_HeldItemUse_Consume(utils_held_item::Make_DefinitionSoft(mars_items::Ration()));
    }

    UFUNCTION()
    private void Check_HoldingFirst(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_DropAndConsume(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Use.Request_Drop(FMars_Request_HeldItemUse_Drop());
        _Use.Request_Consume(Make_RationConsume());
    }

    UFUNCTION()
    private void Check_LaunchedAndEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_LaunchedItems.Num() >= 1 && _Use.Has_Fragment(FMars_Fragment_HeldItemUse_Requests) == false
            && ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()));
    }

    UFUNCTION()
    private void Step_AssertDropWon(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tally = _Use.Get_ConsumeTally();
        const auto Refusal = Tally.LastRefusal.IsSet() ? f"{Tally.LastRefusal.GetValue() :n}" : FString("none");
        const auto Line = f"[ConsumeTest] ADropAndAConsumeOfOneItemTakeItOnce oneDrain launched={_LaunchedItems.Num()} applied={Tally.Applied} refused={Tally.Refused} last={Refusal}";
        Log(Line);
        Assert_Equals_Int(_LaunchedItems.Num(), 1, "OnItemLaunched fired once");
        Assert_Equals_Int(Tally.Applied, 0, "no consume applied");
        Assert_Equals_Int(Tally.Refused, 1, "one consume refused");
        Assert_True(Tally.LastRefusal.IsSet() && Tally.LastRefusal.GetValue() == EMars_HeldItemUse_ConsumeRefusal::Leaving,
            f"the consume was refused as Leaving (got {Refusal})");
    }

    UFUNCTION()
    private void Step_AssertLaunchedStillValid(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Items[0]), "the launched ration is still valid 30 frames later");
    }

    UFUNCTION()
    private void Check_HoldingSecond(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[1]);
    }

    UFUNCTION()
    private void Step_Consume(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Use.Request_Consume(Make_RationConsume());
    }

    UFUNCTION()
    private void Step_Drop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Use.Request_Drop(FMars_Request_HeldItemUse_Drop());
    }

    UFUNCTION()
    private void Check_SecondGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Items[1]) && _Use.Has_Fragment(FMars_Fragment_HeldItemUse_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertConsumeWon(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tally = _Use.Get_ConsumeTally();
        const auto Line = f"[ConsumeTest] ADropAndAConsumeOfOneItemTakeItOnce twoDrains launched={_LaunchedItems.Num()} applied={Tally.Applied} refused={Tally.Refused} secondValid={ck::IsValid(_Items[1])}";
        Log(Line);
        Assert_Equals_Int(Tally.Applied, 1, "one consume applied");
        Assert_Equals_Int(_LaunchedItems.Num(), 1, "OnItemLaunched still fired once");
        Assert_False(ck::IsValid(_Items[1]), "the second ration's handle is invalid");
    }
}
