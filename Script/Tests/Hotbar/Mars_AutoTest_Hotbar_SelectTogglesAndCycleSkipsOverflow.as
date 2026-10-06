// Selecting the selected slot deselects it; cycling steps through the bag slots only, wrapping past the overflow slot,
// and from empty hands starts at the first (next) or last (previous) bag slot.
class UMars_AutoTest_Hotbar_SelectTogglesAndCycleSkipsOverflow : UMars_AutoTestRig_Carrier
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 2);

        Add_Step("select slot 0", n"Step_SelectZero");
        Add_Step_WaitUntil("slot 0 is selected", n"Check_SelectedZero");
        Add_Step("select slot 0 again", n"Step_SelectZero");
        Add_Step_WaitUntil("hands are empty", n"Check_SelectedNone");
        Add_Step("cycle next from empty hands", n"Step_CycleNext");
        Add_Step_WaitUntil("slot 0 is selected", n"Check_SelectedZero");
        Add_Step("cycle next", n"Step_CycleNext");
        Add_Step_WaitUntil("slot 1 is selected", n"Check_SelectedOne");
        Add_Step("cycle next past the last bag slot", n"Step_CycleNext");
        Add_Step_WaitUntil("wraps to slot 0, skipping the overflow slot", n"Check_SelectedZero");
        Add_Step("deselect", n"Step_Deselect");
        Add_Step_WaitUntil("hands are empty", n"Check_SelectedNone");
        Add_Step("cycle previous from empty hands", n"Step_CyclePrevious");
        Add_Step_WaitUntil("the last bag slot is selected", n"Check_SelectedOne");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_CycleNext(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_CycleNext();
    }

    UFUNCTION()
    private void Step_CyclePrevious(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_CyclePrevious();
    }

    UFUNCTION()
    private void Step_Deselect(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Deselect();
    }

    UFUNCTION()
    private void Check_SelectedNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex().IsSet() == false);
    }

    UFUNCTION()
    private void Check_SelectedOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex() == TOptional<int32>(1));
    }
}
