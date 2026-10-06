// A taken item lands in the selected bag slot when it is empty (into the hands); otherwise it goes wherever a stow would
// put it: the first empty bag slot for an ordinary item, the backpack slot for a backpack. Slot 1 is selected while slot 0
// is empty too, so the selected empty slot and the first empty bag slot are different slots.
class UMars_AutoTest_Hotbar_TakeTargetPrefersSelectedEmptyBagSlot : UMars_AutoTestRig_Carrier
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 2);

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Cog()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Backpack()));

        Add_Step_WaitUntil("every holder holds its item", n"Check_HoldersSeeded");
        Add_Step("select empty slot 1 while slot 0 is empty too", n"Step_SelectOne");
        Add_Step_WaitUntil("slot 1 is selected with empty hands", n"Check_SelectedOne");
        Add_Step("the rock's take target is the selected slot 1, its stow target the first empty slot 0", n"Step_AssertTakeTargetIsSelected");
        Add_Step("take the rock", n"Step_TakeRock");
        Add_Step_WaitUntil("slot 1 holds the rock and stays selected", n"Check_RockInSelectedSlot");
        Add_Step("with the selected slot occupied, take targets follow the stow target", n"Step_AssertTakeTargetsFollowStow");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SelectOne(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    private void Check_SelectedOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex() == TOptional<int32>(1) && ck::Is_NOT_Valid(_Hotbar.Get_SelectedItem()));
    }

    UFUNCTION()
    private void Step_AssertTakeTargetIsSelected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Invalid(_Hotbar.Get_ItemAt(0), "slot 0 is empty, so it is the first empty bag slot");
        Assert_True(_Hotbar.TryGet_StowTarget(_Items[0]) == _Hotbar.Get_Slot(0), "the rock's stow target is the first empty bag slot 0");
        Assert_True(_Hotbar.TryGet_TakeTarget(_Items[0]) == _Hotbar.Get_Slot(1),
            "the rock's take target is the selected empty slot 1, not the first empty slot 0");
    }

    UFUNCTION()
    private void Step_TakeRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TakeFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_RockInSelectedSlot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(1) == _Items[0] && _Hotbar.Get_SelectedIndex() == TOptional<int32>(1));
    }

    UFUNCTION()
    private void Step_AssertTakeTargetsFollowStow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Invalid(_Hotbar.Get_ItemAt(0), "the take left slot 0 empty");
        Assert_True(_Hotbar.TryGet_TakeTarget(_Items[1]) == _Hotbar.Get_Slot(0),
            "the cog's take target is the first empty slot 0 while the selected slot 1 is occupied");
        Assert_True(_Hotbar.TryGet_TakeTarget(_Items[2]) == _Hotbar.Get_BackpackSlot(), "the backpack's take target is the backpack slot");
    }
}
