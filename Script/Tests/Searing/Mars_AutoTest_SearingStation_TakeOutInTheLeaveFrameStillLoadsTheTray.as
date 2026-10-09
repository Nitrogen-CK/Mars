// A take-out pressed in the frame the operator leaves still lands on the tray: the take-out's landing is a bridge that runs
// in every state of the station, so the kernel's hand-back is heard whether it drains before or after the state machine
// leaves Operated. The meat platter docks as raw and an empty one as the tray; an operator takes the station and one
// add-food press puts the slab on the pan. Then, in one step, the slab is taken out by name and the operator leaves: the
// station goes Idle, the slab rides the tray (a scene-node child of its root, Kinematic) and the pan holds nothing.
class UMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(15200.0, -12000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);

    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private FCk_Handle_FoodPiece _Slab;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Searing(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Raw = Spawn_Platter(InHandle, k_RawOffset, mars::Food_MeatSlab_Mars);
        _Tray = Spawn_Platter(InHandle, k_TrayOffset, nullptr);

        Add_Step_WaitUntil("the station composed its Searing, feed and docks, and the pan body exists", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("both platters are constructed and the slab landed on the raw one", n"Check_PlattersReady", 0, 10.0f);
        Add_Step("dock the meat platter as raw and the empty one as the tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 3.0f);
        Add_Step("one add-food press", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the kernel admitted the slab", n"Check_Admitted", 0, 5.0f);
        Add_Step_WaitSeconds("the slab settles on the pan", 0.5f);
        Add_Step("take the slab out and leave in the same frame", n"Step_TakeOutAndLeave");
        Add_Step_WaitUntil("the station is Idle and the slab landed on the tray", n"Check_IdleAndOnTray", 0, 5.0f);
        Add_Step_WaitSeconds("its arrival on the tray finishes", 0.5f);
        Add_Step("the slab rides the tray; the pan holds nothing", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlattersReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 1) && Get_IsPlatterReady(_Tray, 0));
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Track_Held(_Raw);
        _Slab = _Raw.As_Platter().Get_Held()[0];
        Dock(_InputDock, _Raw);
        Dock(_OutputDock, _Tray);
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_InputDock, _Raw) && Get_IsDocked(_OutputDock, _Tray));
    }

    UFUNCTION()
    private void Check_OperatedAndSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOperated() && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == 1);
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceIds().Num() == 1 && Get_PieceHandle(Get_PieceIds()[0]) == _Slab);
    }

    UFUNCTION()
    private void Step_TakeOutAndLeave(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsOperated(), "the station is still Operated when the take-out is pressed");
        Request_TakeOut(_Slab);
        Leave();
    }

    UFUNCTION()
    private void Check_IdleAndOnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsIdle() && _Tray.As_Platter().Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tray = _Tray.As_Platter();
        Assert_Equals_Int(_TakenOut.Num(), 1, "the kernel handed one piece back");
        Assert_True(_Slab.TryGet_Platter() == Tray, "the slab is on the tray");
        Assert_True(Get_Parent(_Slab) == _Tray.As_Transform(), "the slab is a scene-node child of the tray's root");
        Assert_True(Get_IsKinematic(_Slab), "the slab's body is Kinematic");
        Assert_Equals_Int(Get_PieceIds().Num(), 0, "the pan holds nothing");
        Assert_True(Get_IsIdle(), "the station is Idle");
    }
}

class AMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray;
}
