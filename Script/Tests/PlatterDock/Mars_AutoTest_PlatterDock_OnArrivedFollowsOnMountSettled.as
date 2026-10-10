// A dock reports a platter twice: OnDocked when its inventory takes the item (the platter still on its way, the dock
// not yet arrived), and OnArrived when the platter's world item settles on the dock (its own OnMountSettled: Carried by
// this dock). The platter settles on the dock once and OnArrived fires once, in the frame of that settle; in the
// handler the world item reads settled, Carried by the dock, with no arrival in flight, and the frame after its root
// rests on the dock's node. An undock clears Get_HasArrived and fires no arrival. Isolated Z band: -61500.
class UMars_AutoTest_PlatterDock_OnArrivedFollowsOnMountSettled : UMars_AutoTestRig_PlatterDock
{
    private const FVector k_Origin = FVector(0.0, 0.0, -61500.0);

    private FCk_Handle_Transform _Root;
    private FCk_Handle_PlatterDock _Dock;
    // Polls of the arrival wait, one a frame: the clock both signals are stamped on.
    private int32 _Poll = 0;
    // What the dock showed in the frame OnDocked fired.
    private bool _HadArrivedAtDock = true;
    // The platter's settles on this dock, and the poll of the first.
    private int32 _SettlesOnDock = 0;
    private TOptional<int32> _SettledOnDockPoll;
    // What the platter showed in the frame OnArrived fired.
    private TOptional<int32> _ArrivedPoll;
    private bool _SettledAtArrival = false;
    private bool _ArrivalInFlightAtArrival = true;
    private TOptional<EMars_WorldItem_Mount> _MountAtArrival;
    private FCk_Handle _CarrierAtArrival;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);

        _Root = Build_StationRoot(InHandle, k_Origin);
        _Dock = Build_Dock(_Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0, 70.0)), "input platter"));
        _Dock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDockedHere"));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0))));

        Add_Step_WaitUntil("the platter world item is constructed and its holder holds its item", n"Check_PlattersConstructed");
        Add_Step("watch the platter's settles; dock the lying platter", n"Step_Dock");
        Add_Step_WaitUntil("the dock reports the platter arrived", n"Check_Arrived", 0, 0);
        Add_Step_WaitSeconds("a second arrival would fire in this window", 0.5f);
        Add_Step("OnArrived fired once, in the frame the platter settled on the dock", n"Step_AssertArrived");
        Add_Step("undock into the overflow", n"Step_Undock");
        Add_Step_WaitUntil("the dock reports the platter undocked", n"Check_Undocked", 0, 0);
        Add_Step("an undocked dock has not arrived", n"Step_AssertUndocked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDockedHere(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        _HadArrivedAtDock = InDock.Get_HasArrived();
    }

    UFUNCTION()
    private void OnPlatterSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier)
    {
        FCk_Handle DockEntity = _Dock;
        if (InMount != EMars_WorldItem_Mount::Carried || InCarrier != DockEntity)
        { return; }

        ++_SettlesOnDock;
        if (_SettledOnDockPoll.IsSet() == false)
        { _SettledOnDockPoll = TOptional<int32>(_Poll); }
    }

    protected void On_Arrived(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter) override
    {
        if (_ArrivedPoll.IsSet())
        { return; }

        const auto WorldItem = _WorldItems[0];
        _ArrivedPoll = TOptional<int32>(_Poll);
        _SettledAtArrival = WorldItem.Get_IsSettled();
        _ArrivalInFlightAtArrival = WorldItem.Has_Fragment(FMars_Fragment_WorldItem_Arrival);
        _MountAtArrival = TOptional<EMars_WorldItem_Mount>(WorldItem.Get_Mount());
        _CarrierAtArrival = WorldItem.Get_Carrier();
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Dock.Get_HasArrived(), "an empty dock has not arrived");

        auto WorldItem = _WorldItems[0];
        WorldItem.BindTo_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnPlatterSettled"));
        Dock(_Dock, _PlatterItems[0]);
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_Poll;
        auto Res = OutResult;
        Res.Set(Get_ArrivedCount(_Dock) >= 1);
    }

    UFUNCTION()
    private void Step_AssertArrived(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle DockEntity = _Dock;
        Assert_Equals_Int(Get_DockedCount(_Dock), 1, "OnDocked fired once");
        Assert_False(_HadArrivedAtDock, "at OnDocked the platter had not arrived");
        Assert_Equals_Int(_SettlesOnDock, 1, "the platter settled on the dock once");
        Assert_Equals_Int(Get_ArrivedCount(_Dock), 1, "OnArrived fired once");
        Assert_True(_Arrived[0].Platter == _Platters[0], "OnArrived names the platter");
        Assert_True(_SettledOnDockPoll.IsSet() && _ArrivedPoll.IsSet() && _SettledOnDockPoll.GetValue() == _ArrivedPoll.GetValue(),
            "OnArrived fired in the frame the platter settled on the dock");
        Assert_True(_SettledAtArrival, "at OnArrived the platter reads settled");
        Assert_True(_MountAtArrival == EMars_WorldItem_Mount::Carried && _CarrierAtArrival == DockEntity, "at OnArrived the dock carries the platter");
        Assert_False(_ArrivalInFlightAtArrival, "at OnArrived no arrival is in flight");

        const auto Gap = Get_World(_WorldItems[0]).GetLocation().Distance(Get_World(_Dock.Get_Node()).GetLocation());
        Assert_True(Gap <= 0.5, f"the platter root rests on the dock's node (gap {Gap} cm)");
        Assert_True(_Dock.Get_HasArrived(), "the dock reads arrived");
    }

    UFUNCTION()
    private void Step_Undock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
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
