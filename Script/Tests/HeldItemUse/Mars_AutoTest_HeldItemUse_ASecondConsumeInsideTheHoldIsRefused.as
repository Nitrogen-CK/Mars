// Two consumes of one player are at least half the held item's hold apart: a ration in each of two bag slots; the held
// one is eaten; with the second selected and held at once, a consume is refused as TooSoon and the ration stays held;
// 0.6 s later on the authority's clock (the ration's hold is 1.0 s), the same consume is applied and both slots are
// empty. A bare carrier (Hand node, a hotbar of two bag slots, HeldItem, HeldItemUse). Isolated origin
// (54800, -18000, -30000).
class UMars_AutoTest_HeldItemUse_ASecondConsumeInsideTheHoldIsRefused : UMars_AutoTestRig_Carrier
{
    private const FVector k_Origin = FVector(54800.0, -18000.0, -30000.0);
    private const float64 k_LaterSeconds = 0.6;

    private FCk_Handle_HeldItemUse _Use;
    private float64 _TooSoonAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Use = utils_held_item_use::Add(_Carrier);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Ration()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Ration()));

        Add_Step_WaitUntil("the holders hold their rations", n"Check_HoldersSeeded");
        Add_Step("stow the first ration", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold the first", n"Check_HoldingFirst", 0, 0);
        Add_Step("stow the second ration", n"Step_StowSecond");
        Add_Step_WaitUntil("the second sits in slot 1", n"Check_SecondStowed", 0, 0);
        Add_Step("consume the held one", n"Step_Consume");
        Add_Step_WaitUntil("one consume applied and slot 0 empty", n"Check_FirstEaten", 0, 0);
        Add_Step("select slot 1", n"Step_SelectOne");
        Add_Step_WaitUntil("the hands hold the second", n"Check_HoldingSecond", 0, 0);
        Add_Step("consume inside the hold", n"Step_ConsumeTooSoon");
        Add_Step_WaitUntil("the consume was judged", n"Check_Judged", 0, 0);
        Add_Step("refused as TooSoon, the second still held", n"Step_AssertTooSoon");
        Add_Step_WaitUntil("0.6 s later on the authority's clock", n"Check_Later", 0, 0);
        Add_Step("consume again", n"Step_Consume");
        Add_Step_WaitUntil("two consumes applied and both slots empty", n"Check_BothEaten", 0, 0);
        Add_Step("the tally", n"Step_AssertBothEaten");
        Run_Steps(InHandle);
    }

    private float64 Get_Clock()
    {
        return utils_mars_net::Get_ServerWorldSeconds(_Carrier);
    }

    UFUNCTION()
    private void Check_HoldingFirst(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_Consume(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Use.Request_Consume(FMars_Request_HeldItemUse_Consume(utils_held_item::Make_DefinitionSoft(mars_items::Ration())));
    }

    UFUNCTION()
    private void Check_FirstEaten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Use.Get_ConsumeTally().Applied == 1 && _Hotbar.Get_Slot(0).Get_NumItems() == 0);
    }

    UFUNCTION()
    private void Step_SelectOne(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    private void Check_HoldingSecond(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[1]);
    }

    UFUNCTION()
    private void Step_ConsumeTooSoon(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _TooSoonAt = Get_Clock();
        _Use.Request_Consume(FMars_Request_HeldItemUse_Consume(utils_held_item::Make_DefinitionSoft(mars_items::Ration())));
    }

    UFUNCTION()
    private void Check_Judged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Use.Has_Fragment(FMars_Fragment_HeldItemUse_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertTooSoon(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tally = _Use.Get_ConsumeTally();
        const auto Refusal = Tally.LastRefusal.IsSet() ? f"{Tally.LastRefusal.GetValue() :n}" : FString("none");
        const auto LastAt = Tally.LastAppliedAt.IsSet() ? Tally.LastAppliedAt.GetValue() : -1.0;
        const auto Line = f"[ConsumeTest] ASecondConsumeInsideTheHoldIsRefused tooSoon applied={Tally.Applied} refused={Tally.Refused} last={Refusal} lastAppliedAt={LastAt} askedAt={_TooSoonAt}";
        Log(Line);
        Assert_Equals_Int(Tally.Applied, 1, "still one consume applied");
        Assert_Equals_Int(Tally.Refused, 1, "one consume refused");
        Assert_True(Tally.LastRefusal.IsSet() && Tally.LastRefusal.GetValue() == EMars_HeldItemUse_ConsumeRefusal::TooSoon,
            f"the consume was refused as TooSoon (got {Refusal})");
        Assert_True(_HeldItem.Get_CurrentItem() == _Items[1], "the second ration is still held");
    }

    UFUNCTION()
    private void Check_Later(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Tally = _Use.Get_ConsumeTally();
        auto Res = OutResult;
        Res.Set(Tally.LastAppliedAt.IsSet() && Get_Clock() >= Tally.LastAppliedAt.GetValue() + k_LaterSeconds);
    }

    UFUNCTION()
    private void Check_BothEaten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Use.Get_ConsumeTally().Applied == 2 && _Hotbar.Get_Slot(0).Get_NumItems() == 0
            && _Hotbar.Get_Slot(1).Get_NumItems() == 0);
    }

    UFUNCTION()
    private void Step_AssertBothEaten(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tally = _Use.Get_ConsumeTally();
        const auto Line = f"[ConsumeTest] ASecondConsumeInsideTheHoldIsRefused later applied={Tally.Applied} refused={Tally.Refused}";
        Log(Line);
        Assert_Equals_Int(Tally.Applied, 2, "two consumes applied");
        Assert_Equals_Int(Tally.Refused, 1, "still one consume refused");
    }
}
