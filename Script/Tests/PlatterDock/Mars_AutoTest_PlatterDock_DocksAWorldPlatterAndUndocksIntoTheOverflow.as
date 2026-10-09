// A platter lying in the world docks onto an Input dock (any policy): the dock holds its item, its world item is Carried by
// the dock and its root rests on the dock's node. Undocked into the carrier's overflow, it is Held in the carrier's hand,
// the overflow selected. The dock is a lifetime child of the station root (the scene-node Create owns it there). Isolated Z
// band: -57000.
class UMars_AutoTest_PlatterDock_DocksAWorldPlatterAndUndocksIntoTheOverflow : UMars_AutoTestRig_PlatterDock
{
    private const FVector k_Origin = FVector(0.0, 0.0, -57000.0);

    private FCk_Handle_Transform _Root;
    private FCk_Handle_PlatterDock _Dock;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();

        _Root = Build_StationRoot(InHandle, k_Origin);
        _Dock = Build_Dock(_Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0, 70.0)), "input platter"));
        Spawn_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0)), nullptr);

        Add_Step_WaitUntil("the platter world item is constructed and its holder holds its item", n"Check_PlattersConstructed");
        Add_Step("the dock is the station's; dock the lying platter", n"Step_Dock");
        Add_Step_WaitUntil("the dock reports the platter docked", n"Check_Docked");
        Add_Step_WaitUntil("the platter is Carried", n"Check_Carried");
        Add_Step_WaitSeconds("the carry's arrival settles", 1.0f);
        Add_Step("the platter rests on the dock's node, carried by the dock", n"Step_AssertDocked");
        Add_Step("undock the platter into the carrier's overflow", n"Step_Undock");
        Add_Step_WaitUntil("the dock reports the platter undocked", n"Check_Undocked");
        Add_Step_WaitUntil("the platter is Held", n"Check_Held");
        Add_Step("the platter is in the overflow, selected, in the carrier's hand", n"Step_AssertHeld");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Dock, "the dock");
        FCk_Handle RootEntity = _Root;
        Assert_True(utils_entity_lifetime::Get_LifetimeOwner(_Dock) == RootEntity, "the dock is a lifetime child of the station root");
        Assert_True(utils_scene_node::Get_Parent(_Dock.Get_Node().As_SceneNode()) == _Root, "the dock's node hangs off the station root");
        Assert_False(_Dock.Get_IsOccupied(), "the dock is empty before the dock");

        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Blocked_NothingHeld, f"Get_ActionFor(empty-handed carrier) on an empty dock (got [{Action :n}])");

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
        Assert_True(_Docked[0].Platter == _Platters[0], "OnDocked names the platter");
        Assert_True(_Dock.Get_IsOccupied(), "the dock is occupied");
        Assert_True(_Dock.Get_Item() == _PlatterItems[0], "the dock holds the platter's item");
        Assert_True(_Dock.Get_Platter() == _Platters[0], "the dock records the platter");
        Assert_True(_Dock.Get_WorldItem() == _WorldItems[0], "the dock records the platter's world item");

        Assert_True(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Carried, "the platter is Carried");
        FCk_Handle DockEntity = _Dock;
        Assert_True(_WorldItems[0].Get_Carrier() == DockEntity, "the dock is the platter's carrier");
        Assert_True(Get_MountParent(_WorldItems[0]) == _Dock.Get_Node(), "the platter root hangs off the dock's node");

        const auto Actual = Get_World(_WorldItems[0]).GetLocation();
        const auto Expected = Get_World(_Dock.Get_Node()).GetLocation();
        Assert_True(Actual.Equals(Expected, 0.5), f"the platter root rests on the dock's node ({Actual} vs {Expected})");

        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Take, f"Get_ActionFor(carrier with a free overflow) on an occupied dock (got [{Action :n}])");
    }

    UFUNCTION()
    private void Step_Undock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = _Hotbar.TryGet_StowTarget(_PlatterItems[0]);
        if (ck::Is_NOT_Valid(Target) || Target != _Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex()))
        {
            FinishFailure("undock precondition: the platter's stow target is the overflow slot");
            return;
        }

        Undock(_Dock, _PlatterItems[0], Target);
    }

    UFUNCTION()
    private void Check_Undocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_UndockedCount(_Dock) == 1);
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Held);
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto OverflowIndex = _Hotbar.Get_OverflowIndex();
        Assert_True(_Undocked[0].Platter == _Platters[0], "OnUndocked names the platter");
        Assert_True(_Hotbar.Get_ItemAt(OverflowIndex) == _PlatterItems[0], "the overflow slot holds the platter");
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(OverflowIndex), "the overflow slot is selected");
        Assert_True(_HeldItem.Get_CurrentItem() == _PlatterItems[0], "the carrier holds the platter");
        Assert_True(_WorldItems[0].Get_Carrier() == _Carrier, "the carrier is the platter's carrier");
        Assert_True(Get_MountParent(_WorldItems[0]) == _HandNode, "the platter hangs off the carrier's Hand node");
        Assert_False(_Dock.Get_IsOccupied(), "the dock is empty");
        Assert_True(ck::Is_NOT_Valid(_Dock.Get_Platter()), "the dock records no platter");
    }
}
