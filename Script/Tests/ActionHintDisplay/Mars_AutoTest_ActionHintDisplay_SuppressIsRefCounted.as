// Two suppresses need two releases: rows registered before the first suppress stay hidden until the last release,
// rows registered while suppressed stay visible throughout.
class UMars_AutoTest_ActionHintDisplay_SuppressIsRefCounted : UCk_AutoTest_Base
{
    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_ActionHintRow _RowX;
    private FCk_Handle_ActionHintRow _RowY;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        _Display = utils_action_hint_display::Add(LocalHandle);

        Add_Step("register X", n"Step_RegisterX");
        Add_Step_WaitUntil("X is visible", n"Check_OnlyXVisible");
        Add_Step("suppress twice", n"Step_SuppressTwice");
        Add_Step_WaitUntil("X is hidden at depth 2", n"Check_HiddenAtDepthTwo");
        Add_Step("register Y above the watermark", n"Step_RegisterY");
        Add_Step_WaitUntil("only Y is visible", n"Check_OnlyYVisible");
        Add_Step("release once", n"Step_Release");
        Add_Step_WaitUntil("depth drops to 1", n"Check_DepthOne");
        Add_Step("still only Y visible at depth 1", n"Step_AssertStillOnlyY");
        Add_Step("release again", n"Step_Release");
        Add_Step_WaitUntil("X and Y are both visible", n"Check_XAndYVisible");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_RegisterX(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RowX = _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Use, FText::FromString("x"), 0, n"OwnerX"));
    }

    UFUNCTION()
    private void Check_OnlyXVisible(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Visible = _Display.Get_VisibleHints();
        auto Res = OutResult;
        Res.Set(Visible.Num() == 1 && Visible[0] == _RowX);
    }

    UFUNCTION()
    private void Step_SuppressTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_Suppress();
        _Display.Request_Suppress();
    }

    UFUNCTION()
    private void Check_HiddenAtDepthTwo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_SuppressDepth() == 2 && _Display.Get_VisibleHints().Num() == 0);
    }

    UFUNCTION()
    private void Step_RegisterY(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RowY = _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Use, FText::FromString("y"), 1, n"OwnerY"));
    }

    UFUNCTION()
    private void Check_OnlyYVisible(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Visible = _Display.Get_VisibleHints();
        auto Res = OutResult;
        Res.Set(Visible.Num() == 1 && Visible[0] == _RowY);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_ReleaseSuppress();
    }

    UFUNCTION()
    private void Check_DepthOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_SuppressDepth() == 1);
    }

    UFUNCTION()
    private void Step_AssertStillOnlyY(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Visible = _Display.Get_VisibleHints();
        Assert_Equals_Int(Visible.Num(), 1, "visible rows after the first release");
        Assert_True(Visible.Num() == 1 && Visible[0] == _RowY, "the surviving visible row is Y");
        Assert_True(_Display.Get_IsHidden(_RowX), "X stays hidden while one suppress is outstanding");
    }

    UFUNCTION()
    private void Check_XAndYVisible(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Visible = _Display.Get_VisibleHints();
        auto Res = OutResult;
        Res.Set(Visible.Num() == 2 && Visible[0] == _RowX && Visible[1] == _RowY);
    }

    private int32 Get_SuppressDepth()
    {
        return _Display.Get_Fragment(FMars_Fragment_ActionHintDisplay).SuppressDepth;
    }
}
