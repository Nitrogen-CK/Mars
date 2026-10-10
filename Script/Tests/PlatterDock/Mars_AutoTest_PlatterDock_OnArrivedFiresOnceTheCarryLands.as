// A dock reports a platter twice: OnDocked when its inventory takes the item (the platter still on its way), OnArrived once
// the platter's world item has landed on the dock. At OnDocked the dock has not arrived; at OnArrived the world item is
// Carried by the dock with no arrival in flight and its root rests on the dock's node. OnArrived fires once however long
// the platter stays, and an undock clears Get_HasArrived. Isolated Z band: -61500.
class UMars_AutoTest_PlatterDock_OnArrivedFiresOnceTheCarryLands : UMars_AutoTestRig_PlatterDock
{
    private const FVector k_Origin = FVector(0.0, 0.0, -61500.0);

    private FCk_Handle_Transform _Root;
    private FCk_Handle_PlatterDock _Dock;
    // What the dock showed in the frame OnDocked fired.
    private bool _HadArrivedAtDock = true;
    // What the platter showed in the frame OnArrived fired.
    private TOptional<EMars_WorldItem_Mount> _MountAtArrival;
    private bool _ArrivalInFlightAtArrival = true;
    private float64 _GapAtArrival = -1.0;

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
        _Dock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDockedHere"));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0))));

        Add_Step_WaitUntil("the platter world item is constructed and its holder holds its item", n"Check_PlattersConstructed");
        Add_Step("dock the lying platter", n"Step_Dock");
        Add_Step_WaitUntil("the dock reports the platter arrived", n"Check_Arrived");
        Add_Step_WaitSeconds("a second arrival would fire in this window", 0.5f);
        Add_Step("OnArrived fired once, after the carry landed; undock into the overflow", n"Step_AssertArrivedAndUndock");
        Add_Step_WaitUntil("the dock reports the platter undocked", n"Check_Undocked");
        Add_Step("an undocked dock has not arrived", n"Step_AssertUndocked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDockedHere(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        _HadArrivedAtDock = InDock.Get_HasArrived();
    }

    protected void On_Arrived(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter) override
    {
        auto WorldItem = _WorldItems[0];
        FCk_Handle WorldItemEntity = WorldItem;
        _MountAtArrival = TOptional<EMars_WorldItem_Mount>(WorldItem.Get_Mount());
        _ArrivalInFlightAtArrival = WorldItemEntity.Has_Fragment(FMars_Fragment_WorldItem_Arrival);
        _GapAtArrival = Get_World(WorldItemEntity).GetLocation().Distance(Get_World(_Dock.Get_Node()).GetLocation());
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Dock.Get_HasArrived(), "an empty dock has not arrived");
        Dock(_Dock, _PlatterItems[0]);
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ArrivedCount(_Dock) >= 1);
    }

    UFUNCTION()
    private void Step_AssertArrivedAndUndock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_DockedCount(_Dock), 1, "OnDocked fired once");
        Assert_False(_HadArrivedAtDock, "at OnDocked the platter had not arrived");
        Assert_Equals_Int(Get_ArrivedCount(_Dock), 1, "OnArrived fired once");
        Assert_True(_Arrived[0].Platter == _Platters[0], "OnArrived names the platter");
        Assert_True(_MountAtArrival == EMars_WorldItem_Mount::Carried, "at OnArrived the platter is Carried");
        Assert_False(_ArrivalInFlightAtArrival, "at OnArrived no arrival is in flight");
        Assert_True(_GapAtArrival >= 0.0 && _GapAtArrival <= 0.5, f"at OnArrived the platter root rests on the dock's node (gap {_GapAtArrival} cm)");
        Assert_True(_Dock.Get_HasArrived(), "the dock reads arrived");

        auto Target = _Hotbar.TryGet_StowTarget(_PlatterItems[0]);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("undock precondition: the platter has a stow target");
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
    private void Step_AssertUndocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Dock.Get_HasArrived(), "the undocked dock has not arrived");
        Assert_Equals_Int(Get_ArrivedCount(_Dock), 1, "the undock fired no arrival");
    }
}
