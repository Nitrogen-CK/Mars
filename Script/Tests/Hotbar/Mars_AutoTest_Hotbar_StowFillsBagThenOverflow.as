// Stowing fills the bag slots in order, then the overflow slot. The first stow into empty hands is auto-held; the
// overflow arrival always selects the overflow slot.
class UMars_AutoTest_Hotbar_StowFillsBagThenOverflow : UMars_AutoTestRig_Carrier
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 2);

        for (int32 Index = 0; Index < 3; ++Index)
        { _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock())); }

        Add_Step_WaitUntil("every holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the first rock", n"Step_StowFirst");
        Add_Step_WaitUntil("slot 0 holds it and is auto-held", n"Check_FirstStowed");
        Add_Step("stow the second rock", n"Step_StowSecond");
        Add_Step_WaitUntil("slot 1 holds it", n"Check_SecondStowed");
        Add_Step("stow the third rock", n"Step_StowThird");
        Add_Step_WaitUntil("every slot holds one and the overflow is selected", n"Check_OverflowSelected");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_FirstStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)) && _Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    private void Check_OverflowSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_Slot(0).Get_NumItems() == 1
            && _Hotbar.Get_Slot(1).Get_NumItems() == 1
            && _Hotbar.Get_Slot(2).Get_NumItems() == 1
            && _Hotbar.Get_SelectedIndex() == TOptional<int32>(2));
    }
}
