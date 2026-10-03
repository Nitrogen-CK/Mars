// Select, Deselect and Cycle requests queued in one frame apply in the order they were requested. From empty hands, a
// Deselect then a Select of slot 0 ends with slot 0 selected (the Deselect changes nothing); a Select of slot 1 then a
// Deselect ends with empty hands.
class UMars_AutoTest_Hotbar_SelectionChangesApplyInArrivalOrder : UCk_AutoTest_Base
{
    private FCk_Handle_Hotbar _Hotbar;
    private int32 _SelectionChanges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        _Hotbar = utils_hotbar::Add(LocalHandle, Spec);

        _Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));

        Add_Step("queue Deselect then Select slot 0 in one frame", n"Step_DeselectThenSelectZero");
        Add_Step_WaitUntil("the selection changed", n"Check_OneChange");
        Add_Step("the later Select wins: slot 0 is selected", n"Step_AssertSelectedZero");
        Add_Step("queue Select slot 1 then Deselect in one frame", n"Step_SelectOneThenDeselect");
        Add_Step_WaitUntil("both changes drained", n"Check_ThreeChanges");
        Add_Step("the later Deselect wins: hands are empty", n"Step_AssertSelectedNone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnSelectionChanged(FCk_Handle_Hotbar InHotbar)
    {
        _SelectionChanges += 1;
    }

    UFUNCTION()
    private void Step_DeselectThenSelectZero(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Deselect();
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    private void Step_SelectOneThenDeselect(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
        _Hotbar.Request_Deselect();
    }

    UFUNCTION()
    private void Check_OneChange(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SelectionChanges >= 1);
    }

    UFUNCTION()
    private void Check_ThreeChanges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SelectionChanges >= 3);
    }

    UFUNCTION()
    private void Step_AssertSelectedZero(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(0), "Deselect then Select in one frame leaves slot 0 selected");
        Assert_Equals_Int(_SelectionChanges, 1, "the Deselect on empty hands changed nothing; the Select broadcast once");
    }

    UFUNCTION()
    private void Step_AssertSelectedNone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hotbar.Get_SelectedIndex().IsSet(), "Select then Deselect in one frame leaves nothing selected");
        Assert_Equals_Int(_SelectionChanges, 3, "the Select and the Deselect each broadcast once");
    }
}
