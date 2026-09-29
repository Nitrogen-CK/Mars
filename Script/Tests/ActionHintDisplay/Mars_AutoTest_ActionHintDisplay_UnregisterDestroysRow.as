// A row is a child entity of the display: unregistering it removes it from the legend and destroys the row entity.
class UMars_AutoTest_ActionHintDisplay_UnregisterDestroysRow : UCk_AutoTest_Base
{
    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_ActionHintRow _Row;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        _Display = utils_action_hint_display::Add(LocalHandle);

        Add_Step("register a row", n"Step_Register");
        Add_Step_WaitUntil("the row is visible", n"Check_Visible");
        Add_Step("unregister the row", n"Step_Unregister");
        Add_Step_WaitUntil("the row entity is destroyed", n"Check_RowDestroyed");
        Add_Step("the legend is empty", n"Step_AssertEmpty");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Register(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Row = _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Use, FText::FromString("row"), 0, n"Owner"));
        Assert_True(ck::IsValid(_Row), "Request_RegisterHint returns a valid row handle synchronously");
    }

    UFUNCTION()
    private void Check_Visible(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Visible = _Display.Get_VisibleHints();
        auto Res = OutResult;
        Res.Set(Visible.Num() == 1 && Visible[0] == _Row);
    }

    UFUNCTION()
    private void Step_Unregister(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(_Row));
    }

    UFUNCTION()
    private void Check_RowDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Row));
    }

    UFUNCTION()
    private void Step_AssertEmpty(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Display.Get_VisibleHints().Num(), 0, "visible rows after the unregister");
    }
}
