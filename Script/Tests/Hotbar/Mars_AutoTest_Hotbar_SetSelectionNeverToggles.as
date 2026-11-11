// SetSelection is absolute: setting slot 1 twice leaves slot 1 selected and broadcasts once; setting empty hands twice
// leaves them empty and broadcasts once. Against slot 1 selected, a relative change resolves to the target the drain
// would apply: Select 1 deselects, Select 0 targets 0, Cycle Next wraps to 0, Deselect empties.
class UMars_AutoTest_Hotbar_SetSelectionNeverToggles : UCk_AutoTest_Base
{
    private FCk_Handle_Hotbar _Hotbar;
    private int32 _SelectionChanges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Carrier = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        _Hotbar = utils_hotbar::Add(Carrier, Spec);
        _Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));

        Add_Step_WaitUntil("the hotbar is ready", n"Check_Ready");
        Add_Step("set slot 1 twice in one frame", n"Step_SetOneTwice");
        Add_Step_WaitUntil("the selection changed", n"Check_OneChange");
        Add_Step_WaitFrames("let any further change drain", 3);
        Add_Step("slot 1 stays selected; relative changes resolve against it", n"Step_AssertOneAndResolve");
        Add_Step("set empty hands twice in one frame", n"Step_SetNoneTwice");
        Add_Step_WaitUntil("the selection changed again", n"Check_TwoChanges");
        Add_Step_WaitFrames("let any further change drain", 3);
        Add_Step("hands stay empty", n"Step_AssertNone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnSelectionChanged(FCk_Handle_Hotbar InHotbar)
    {
        _SelectionChanges += 1;
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_IsReady());
    }

    UFUNCTION()
    private void Step_SetOneTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>(1)));
        _Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>(1)));
    }

    UFUNCTION()
    private void Check_OneChange(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SelectionChanges >= 1);
    }

    UFUNCTION()
    private void Check_TwoChanges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SelectionChanges >= 2);
    }

    UFUNCTION()
    private void Step_AssertOneAndResolve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(1), "setting slot 1 twice leaves slot 1 selected");
        Assert_Equals_Int(_SelectionChanges, 1, "the second set of the selected slot changed nothing");

        const auto SelectOne = utils_hotbar::Resolve_SelectionChange(_Hotbar, FMars_Hotbar_SelectionChangeRequest(FMars_Request_Hotbar_Select(1)));
        Assert_False(SelectOne.IsSet(), "Select of the selected slot resolves to empty hands");

        const auto SelectZero = utils_hotbar::Resolve_SelectionChange(_Hotbar, FMars_Hotbar_SelectionChangeRequest(FMars_Request_Hotbar_Select(0)));
        Assert_True(SelectZero == TOptional<int32>(0), "Select of another slot resolves to that slot");

        const auto CycleNext = utils_hotbar::Resolve_SelectionChange(_Hotbar,
            FMars_Hotbar_SelectionChangeRequest(FMars_Request_Hotbar_Cycle(EMars_Hotbar_CycleDirection::Next)));
        Assert_True(CycleNext == TOptional<int32>(0), "Cycle Next from the last bag slot wraps to slot 0");

        const auto Deselect = utils_hotbar::Resolve_SelectionChange(_Hotbar, FMars_Hotbar_SelectionChangeRequest(FMars_Request_Hotbar_Deselect()));
        Assert_False(Deselect.IsSet(), "Deselect resolves to empty hands");
    }

    UFUNCTION()
    private void Step_SetNoneTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>()));
        _Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>()));
    }

    UFUNCTION()
    private void Step_AssertNone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hotbar.Get_SelectedIndex().IsSet(), "setting empty hands twice leaves them empty");
        Assert_Equals_Int(_SelectionChanges, 2, "the second set of empty hands changed nothing");
    }
}
