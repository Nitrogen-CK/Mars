// Docking a platter held in the hands is ONE mount change (Held -> Carried, the dock's Carry): the HeldItem's re-carry on
// deselect finds the item already headed for the dock and leaves it alone, so no illegal move fires. The overflow empties
// and the hands with it. Taking it back is ONE more (Carried -> Held, the hotbar arrival's Hold). Isolated Z band: -59000.
class UMars_AutoTest_PlatterDock_DockFromTheHandIsOneCarryAndTakeIsOneHold : UMars_AutoTestRig_PlatterDock
{
    private const FVector k_Origin = FVector(0.0, 0.0, -59000.0);

    private FCk_Handle_PlatterDock _Dock;

    private int32 _HeldToCarried = 0;
    private int32 _CarriedToHeld = 0;
    private int32 _CarriedToHeldBeforeTake = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();

        auto Root = Build_StationRoot(InHandle, k_Origin);
        _Dock = Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0, 70.0)), "input platter"));
        Spawn_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0)), nullptr);

        Add_Step_WaitUntil("the platter world item is constructed and its holder holds its item", n"Check_PlattersConstructed");
        Add_Step("stow the platter into the overflow and carry it", n"Step_Stow");
        Add_Step_WaitUntil("the platter is Held", n"Check_Held");
        Add_Step("holding a platter, an empty dock offers Place; dock it from the hand", n"Step_DockFromTheHand");
        Add_Step_WaitUntil("the dock reports the platter docked", n"Check_Docked");
        Add_Step_WaitUntil("the platter is Carried", n"Check_Carried");
        Add_Step_WaitSeconds("any stray re-carry would have drained", 0.5f);
        Add_Step("one Held -> Carried; the dock carries it; the overflow and the hands are empty", n"Step_AssertDocked");
        Add_Step("take the platter back into the overflow", n"Step_Take");
        Add_Step_WaitUntil("the platter is Held", n"Check_Held");
        Add_Step_WaitSeconds("any stray mount change would have drained", 0.5f);
        Add_Step("one more Carried -> Held; the carrier holds it", n"Step_AssertTaken");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WorldItems[0].BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged"));
        Stow_Platter(0);
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Held && _HeldItem.Get_CurrentItem() == _PlatterItems[0]);
    }

    UFUNCTION()
    private void Step_DockFromTheHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Parent = _PlatterItems[0].Get_ParentInventory();
        FCk_Handle Overflow = _Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex());
        Assert_True(Parent == Overflow, "the platter's item is in the overflow slot");
        Assert_Equals_Int(_HeldToCarried, 0, "no Held -> Carried before the dock");

        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Place, f"Get_ActionFor(carrier holding a platter) on an empty dock (got [{Action :n}])");

        Dock(_Dock, _PlatterItems[0]);
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_DockedCount(_Dock) == 1);
    }

    UFUNCTION()
    private void Check_Carried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Carried);
    }

    UFUNCTION()
    private void Step_AssertDocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HeldToCarried, 1, "exactly one Held -> Carried (the dock's Carry)");
        Assert_True(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Carried, "the platter is Carried");
        Assert_True(_WorldItems[0].Get_TargetMount() == EMars_WorldItem_Mount::Carried, "the platter is not headed anywhere else");

        FCk_Handle DockEntity = _Dock;
        Assert_True(_WorldItems[0].Get_Carrier() == DockEntity, "the dock is the platter's carrier");
        Assert_True(Get_MountParent(_WorldItems[0]) == _Dock.Get_Node(), "the platter root hangs off the dock's node");
        Assert_True(_Dock.Get_Item() == _PlatterItems[0], "the dock holds the platter's item");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(_Hotbar.Get_OverflowIndex())), "the overflow slot is empty");
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the carrier's hands are empty");

        _CarriedToHeldBeforeTake = _CarriedToHeld;
    }

    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Take, f"Get_ActionFor(empty-handed carrier) on an occupied dock (got [{Action :n}])");

        Undock(_Dock, _PlatterItems[0], _Hotbar.TryGet_StowTarget(_PlatterItems[0]));
    }

    UFUNCTION()
    private void Step_AssertTaken(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CarriedToHeld - _CarriedToHeldBeforeTake, 1, "exactly one more Carried -> Held (the take's Hold)");
        Assert_Equals_Int(_HeldToCarried, 1, "still exactly one Held -> Carried");
        Assert_Equals_Int(Get_UndockedCount(_Dock), 1, "the dock reported one undock");
        Assert_True(_WorldItems[0].Get_Carrier() == _Carrier, "the carrier is the platter's carrier");
        Assert_True(Get_MountParent(_WorldItems[0]) == _HandNode, "the platter hangs off the carrier's Hand node");
        Assert_True(_Hotbar.Get_ItemAt(_Hotbar.Get_OverflowIndex()) == _PlatterItems[0], "the overflow slot holds the platter");
        Assert_False(_Dock.Get_IsOccupied(), "the dock is empty");
    }

    UFUNCTION()
    private void OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        ck::Trace(f"[PlatterDock test] [{InWorldItem.ToString()}] mount {InPrev :n} -> {InNew :n}");

        if (InPrev == EMars_WorldItem_Mount::Held && InNew == EMars_WorldItem_Mount::Carried)
        { ++_HeldToCarried; }

        if (InPrev == EMars_WorldItem_Mount::Carried && InNew == EMars_WorldItem_Mount::Held)
        { ++_CarriedToHeld; }
    }
}
