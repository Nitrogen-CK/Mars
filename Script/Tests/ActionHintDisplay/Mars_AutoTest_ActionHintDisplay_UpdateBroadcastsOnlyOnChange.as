// An update carrying the row's current text is dropped without a signal; a real change applies and signals once.
class UMars_AutoTest_ActionHintDisplay_UpdateBroadcastsOnlyOnChange : UCk_AutoTest_Base
{
    private FCk_Handle_ActionHintDisplay _Display;
    private FMars_ActionHint_ID _Id;
    private int32 _UpdatedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        _Display = utils_action_hint_display::Add(LocalHandle);
        _Display.BindTo_OnHintUpdated(FMars_Delegate_ActionHintDisplay_OnHintUpdated(this, n"OnHintUpdated"));

        Add_Step("register a row", n"Step_Register");
        Add_Step_WaitUntil("the row is visible", n"Check_Registered");
        Add_Step("update with the same text", n"Step_UpdateSame");
        Add_Step_WaitFrames("settle after a no-op update", 3);
        Add_Step("no update signal for unchanged text", n"Step_AssertNoUpdate");
        Add_Step("update with new text", n"Step_UpdateNew");
        Add_Step_WaitUntil("one update signal fired", n"Check_UpdatedOnce");
        Add_Step("row carries the new text", n"Step_AssertNewText");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnHintUpdated(FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec)
    {
        _UpdatedCount += 1;
    }

    UFUNCTION()
    private void Step_Register(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Id = _Display.Request_RegisterHint(FMars_Request_ActionHintDisplay_Register(
            FMars_ActionHint_Spec(mars::Mars_IA_Interact_Use, FText::FromString("old"), 0, n"Owner")));
    }

    UFUNCTION()
    private void Check_Registered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Display.Get_VisibleHints().Num() == 1);
    }

    UFUNCTION()
    private void Step_UpdateSame(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_Id, FText::FromString("old")));
    }

    UFUNCTION()
    private void Step_AssertNoUpdate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_UpdatedCount, 0, "OnHintUpdated count after an unchanged update");
    }

    UFUNCTION()
    private void Step_UpdateNew(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_Id, FText::FromString("new")));
    }

    UFUNCTION()
    private void Check_UpdatedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UpdatedCount >= 1);
    }

    UFUNCTION()
    private void Step_AssertNewText(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_UpdatedCount, 1, "OnHintUpdated count after a changed update");

        auto Visible = _Display.Get_VisibleHints();
        Assert_Equals_Int(Visible.Num(), 1, "visible rows after the update");
        if (Visible.Num() == 1)
        { Assert_Equals_String(Visible[0].Spec.Text.ToString(), "new", "row text after the update"); }
    }
}
