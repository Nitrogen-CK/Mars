// Selecting away from an occupied overflow slot parks the selection and asks once for the overflow item to be
// dropped; the parked selection applies only after the overflow slot empties.
class UMars_AutoTest_Hotbar_LeavingOverflowParksSelection : UMars_AutoTestRig_Carrier
{
    private int32 _EjectCount = 0;
    private FCk_Handle_Item _EjectItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 2);

        for (int32 Index = 0; Index < 3; ++Index)
        { _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock())); }

        _Hotbar.BindTo_OnOverflowEjectRequested(FMars_Delegate_Hotbar_OnOverflowEjectRequested(this, n"OnOverflowEjectRequested"));

        Add_Step_WaitUntil("every holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the first rock", n"Step_StowFirst");
        Add_Step_WaitUntil("slot 0 holds it", n"Check_FirstStowed");
        Add_Step("stow the second rock", n"Step_StowSecond");
        Add_Step_WaitUntil("slot 1 holds it", n"Check_SecondStowed");
        Add_Step("stow the third rock", n"Step_StowThird");
        Add_Step_WaitUntil("the overflow slot holds it and is selected", n"Check_OverflowFilled");
        Add_Step("select bag slot 0", n"Step_SelectZero");
        Add_Step_WaitUntil("the eject request fired for pending index 0", n"Check_EjectRequested");
        Add_Step("the selection is still parked on the overflow slot", n"Step_AssertStillOnOverflow");
        Add_Step("select bag slot 0 again while parked", n"Step_SelectZero");
        Add_Step_WaitFrames("settle the re-press", 3);
        Add_Step("a re-press only re-parks", n"Step_AssertSingleEject");
        Add_Step("remove the overflow item", n"Step_RemoveOverflowItem");
        Add_Step_WaitUntil("the parked selection applies", n"Check_SelectedZero");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnOverflowEjectRequested(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem)
    {
        _EjectCount += 1;
        _EjectItem = InItem;
    }

    UFUNCTION()
    private void Check_FirstStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)));
    }

    UFUNCTION()
    private void Check_EjectRequested(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Parked = _Hotbar.TryGet_ParkedSelection();
        Res.Set(_EjectCount == 1 && Parked.IsSet() && Parked.GetValue().Index == TOptional<int32>(0));
    }

    UFUNCTION()
    private void Step_AssertStillOnOverflow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(2), "the selection stays parked on the overflow slot while its item is held");
        Assert_True(_EjectItem == _Hotbar.Get_ItemAt(2), "the eject request names the overflow item");
    }

    UFUNCTION()
    private void Step_AssertSingleEject(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_EjectCount, 1, "a re-press while parked does not ask for another eject");
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(2), "a re-press while parked keeps the overflow slot selected");
    }

    UFUNCTION()
    private void Step_RemoveOverflowItem(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Overflow = _Hotbar.Get_Slot(2);
        auto Request = FCk_Request_Inventory_RemoveItem(_Hotbar.Get_ItemAt(2));
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Overflow.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }
}
