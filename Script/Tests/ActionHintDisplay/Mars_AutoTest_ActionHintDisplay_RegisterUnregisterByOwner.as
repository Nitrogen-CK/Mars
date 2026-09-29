// UnregisterByOwner removes every row of that owner in one request, leaves other owners' rows, and signals each removal.
class UMars_AutoTest_ActionHintDisplay_RegisterUnregisterByOwner : UCk_AutoTest_Base
{
    private FCk_Handle_ActionHintDisplay _Display;
    private int32 _UnregisteredCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        _Display = utils_action_hint_display::Add(LocalHandle);
        _Display.BindTo_OnHintUnregistered(FMars_Delegate_ActionHintDisplay_OnHintUnregistered(this, n"OnHintUnregistered"));

        Add_Step("register two rows for owner A and one for owner B", n"Step_RegisterThree");
        Add_Step_WaitUntil("all three rows are visible", n"Check_ThreeVisible");
        Add_Step("unregister owner A", n"Step_UnregisterOwnerA");
        Add_Step_WaitUntil("only owner B's row survives", n"Check_OnlyOwnerBVisible");
        Add_Step("OnHintUnregistered fired once per removed row", n"Step_AssertUnregisteredTwice");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnHintUnregistered(FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow)
    {
        _UnregisteredCount += 1;
    }

    UFUNCTION()
    private void Step_RegisterThree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Use, FText::FromString("a1"), 0, n"OwnerA"));
        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Use, FText::FromString("a2"), 1, n"OwnerA"));
        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Use, FText::FromString("b1"), 2, n"OwnerB"));
    }

    UFUNCTION()
    private void Check_ThreeVisible(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Display.Get_VisibleHints().Num() == 3);
    }

    UFUNCTION()
    private void Step_UnregisterOwnerA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(n"OwnerA"));
    }

    UFUNCTION()
    private void Check_OnlyOwnerBVisible(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Visible = _Display.Get_VisibleHints();
        auto Res = OutResult;
        Res.Set(Visible.Num() == 1 && Visible[0].Get_OwnerKey() == n"OwnerB");
    }

    UFUNCTION()
    private void Step_AssertUnregisteredTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_UnregisteredCount, 2, "OnHintUnregistered count after UnregisterByOwner(OwnerA)");
    }
}
