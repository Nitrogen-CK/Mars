// A stow while nothing is in the hands selects the bag slot it lands in, so the player sees the item taken. Nothing in the
// hands is no selection at all, or a selected slot that holds nothing (a slot stays selected after its item was thrown,
// dropped or used): the first rock lands in slot 0 with no selection and is selected; then, with empty slot 2 selected,
// the second rock lands in slot 1 (the first empty bag slot) and slot 1 is selected.
class UMars_AutoTest_Hotbar_AStowWithNoSelectionSelectsTheSlot : UMars_AutoTestRig_Carrier
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 3);

        for (int32 Index = 0; Index < 2; ++Index)
        { _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock())); }

        Add_Step_WaitUntil("every holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("nothing is selected; stow the first rock", n"Step_AssertNoSelectionAndStowFirst");
        Add_Step_WaitUntil("slot 0 holds it and is selected", n"Check_FirstSelected", 0, 2.0f);
        Add_Step("select empty slot 2 (nothing in the hands)", n"Step_SelectEmptySlotTwo");
        Add_Step_WaitUntil("slot 2 is selected", n"Check_EmptySlotSelected", 0, 2.0f);
        Add_Step("stow the second rock", n"Step_StowSecond");
        Add_Step_WaitUntil("slot 1 holds it", n"Check_SecondStowed", 0, 2.0f);
        Add_Step_WaitFrames("the sync pass has seen the arrival", 3);
        Add_Step("slot 1 is selected", n"Step_AssertSecondSelected");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertNoSelectionAndStowFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hotbar.Get_SelectedIndex().IsSet(), "nothing is selected before the first stow");
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_FirstSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)) && _Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    private void Step_SelectEmptySlotTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(2));
    }

    UFUNCTION()
    private void Check_EmptySlotSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex() == TOptional<int32>(2) && ck::Is_NOT_Valid(_Hotbar.Get_SelectedItem()));
    }

    UFUNCTION()
    private void Step_AssertSecondSelected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Selected = _Hotbar.Get_SelectedIndex();
        auto SelectedText = FString("none");
        if (Selected.IsSet())
        { SelectedText = f"{Selected.GetValue()}"; }

        Assert_True(Selected == TOptional<int32>(1),
            f"the stow into slot 1 with an empty slot selected selects slot 1 (selected: {SelectedText})");
        Assert_True(_Hotbar.Get_SelectedItem() == _Hotbar.Get_ItemAt(1), "the stowed rock is the selected item");
    }
}
