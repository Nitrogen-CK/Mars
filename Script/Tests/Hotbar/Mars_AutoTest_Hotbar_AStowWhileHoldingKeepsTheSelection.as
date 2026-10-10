// A stow while an item is in the hands leaves the selection alone: the held item stays held. The first rock lands in slot 0
// and is selected (empty hands); the second lands in slot 1 and slot 0 stays selected, its rock still the selected item.
class UMars_AutoTest_Hotbar_AStowWhileHoldingKeepsTheSelection : UMars_AutoTestRig_Carrier
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 3);

        for (int32 Index = 0; Index < 2; ++Index)
        { _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock())); }

        Add_Step_WaitUntil("every holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the first rock", n"Step_StowFirst");
        Add_Step_WaitUntil("slot 0 holds it and is selected", n"Check_FirstSelected", 0, 2.0f);
        Add_Step("stow the second rock while holding the first", n"Step_StowSecond");
        Add_Step_WaitUntil("slot 1 holds it", n"Check_SecondStowed", 0, 2.0f);
        Add_Step_WaitFrames("the sync pass has seen the arrival", 3);
        Add_Step("slot 0 stays selected and its rock stays held", n"Step_AssertSelectionKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_FirstSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)) && _Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    private void Step_AssertSelectionKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(0), "slot 0 stays selected after a stow into slot 1");
        Assert_True(_Hotbar.Get_SelectedItem() == _Hotbar.Get_ItemAt(0), "the first rock is still the selected item");
        Assert_True(ck::IsValid(_Hotbar.Get_ItemAt(1)), "the second rock is in slot 1");
    }
}
