// The same persistent book closes immediately on unequip and on launch. A launch interrupts a live page turn before
// the deferred inventory transfer; the abandoned turn never commits after the body is back in the world.
UCLASS(Abstract)
class UMars_AutoTestRig_Cookbook_Launch : UMars_AutoTestRig_Cookbook
{
    protected EMars_LaunchKind _LaunchKind = EMars_LaunchKind::Throw;
    private bool _SawLaunch = false;
    private bool _ClosedAtLaunch = false;
    private bool _ControlsReleasedAtLaunch = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Band = _LaunchKind == EMars_LaunchKind::Throw ? -43000.0 : -46000.0;
        Build_Cookbook(InHandle, FVector(131000.0, Band, -30000.0));
        Add_Steps_PickupAndOpen();
        Add_Step("deselect the open book", n"Step_DeselectBook");
        Add_Step_WaitUntil("the book is stowed, shut and no longer resolves as held", n"Check_StowedClosed", 0, 0);
        Add_Step("select the book again", n"Step_SelectZero");
        Add_Step_WaitUntil("the same book returns to the hands", n"Check_BookHeld", 0, 0);
        Add_Step("open again", n"Step_TapPrimary");
        Add_Step_WaitUntil("open again", n"Check_BookOpen", 0, 0);
        Add_Step("start a page turn and launch the held book", n"Step_TurnAndLaunch");
        Add_Step_WaitUntil("the same book returned to the world as a Dynamic body", n"Check_Released", 0, 0);
        Add_Step_WaitSeconds("the abandoned page turn has time to finish", 2.0f);
        Add_Step("launch closed it before transfer and cancelled the turn", n"Step_AssertLaunch");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DeselectBook(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Hotbar.Request_Deselect(FMars_Request_Hotbar_Deselect()); }

    UFUNCTION()
    private void Check_StowedClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_WorldBook.Get_Mount() == EMars_WorldItem_Mount::Carried
            && _BookPresentation.Get_IsOpen() == false
            && ck::Is_NOT_Valid(utils_cookbook::TryGet_HeldBook(_Carrier)));
    }

    UFUNCTION()
    private void Step_TurnAndLaunch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _BookPresentation.Request_Turn(1);
        Assert_True(_BookPresentation.Get_IsTransitioning(), "a live page turn is interrupted by the launch");
        _BookUse.BindTo_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnBookLaunched"));
        if (_LaunchKind == EMars_LaunchKind::Throw)
        { _BookUse.Request_Throw(FMars_Request_HeldItemUse_Throw()); }
        else
        { _BookUse.Request_Drop(FMars_Request_HeldItemUse_Drop()); }
    }

    UFUNCTION()
    private void OnBookLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    {
        _SawLaunch = InItem == _BookItem && InKind == _LaunchKind;
        _ClosedAtLaunch = _BookPresentation.Get_IsOpen() == false;
        _ControlsReleasedAtLaunch = ck::Is_NOT_Valid(utils_cookbook::TryGet_HeldBook(_Carrier))
            && InUse.Get_IsCurrentItemLaunched();
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_WorldBook.Get_Mount() == EMars_WorldItem_Mount::World
            && _WorldBook.Get_HeldItem() == _BookItem
            && ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem())
            && _WorldBook.Get_Holder().Get_NumItems() == 1
            && utils_jolt_body::Get_MotionType(_WorldBook.Get_Body()) == ECk_MotionType::Dynamic);
    }

    UFUNCTION()
    private void Step_AssertLaunch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawLaunch, "the launch signal identifies the original held item and requested launch kind");
        Assert_True(_ClosedAtLaunch, "the book is already closed inside the launch signal, before inventory transfer");
        Assert_True(_ControlsReleasedAtLaunch, "the launched item cannot resolve as a controllable held book");
        Assert_False(_BookPresentation.Get_IsOpen(), "the book remains shut in the world");
        Assert_Equals_Int(_BookPresentation.Get_PageSectionIndex(), 0, "the cancelled turn never commits a new section");
        Assert_True(_BookItem.Get_PersistentWorldItem() == _WorldBook, "drop or throw preserves the original physical book");
        _BookUse.UnbindFrom_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnBookLaunched"));
    }
}

class UMars_AutoTest_Cookbook_ThrowClosesDuringATurnAndStowResets : UMars_AutoTestRig_Cookbook_Launch
{
}

class UMars_AutoTest_Cookbook_DropClosesDuringATurnAndStowResets : UMars_AutoTestRig_Cookbook_Launch
{
    default _LaunchKind = EMars_LaunchKind::Drop;
}
