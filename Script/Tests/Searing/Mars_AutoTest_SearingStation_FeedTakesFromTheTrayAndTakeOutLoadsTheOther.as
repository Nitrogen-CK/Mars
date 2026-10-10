// The searing station's whole round on real pieces. The meat platter docks on the raw platter dock and an empty platter on
// the finished tray's; an operator takes the station (the pan heats) and one add-food press carries the slab: the bridge
// unloads it from the raw platter and the kernel admits it, so the raw platter is empty and the pan holds the slab. After a
// second on the hot pan the test takes that piece out by name, as a take-out press would: the station's take-out task loads
// it onto the docked tray, where it rides as a scene-node child of the tray's root with its body Kinematic, carrying the
// sear the kernel gave it; the pan holds nothing and the kernel counts one piece taken out.
class UMars_AutoTest_SearingStation_FeedTakesFromTheTrayAndTakeOutLoadsTheOther : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(12800.0, -12000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // A frame of searing between the snapshot and the take-out's drain moves a face far less than this.
    private const float32 k_SearTolerance = 0.05f;

    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private FCk_Handle_FoodPiece _Slab;
    // The kernel's face sears as the take-out was asked for.
    private TArray<float32> _SearAtTakeOut;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Searing(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Raw = Spawn_Platter(InHandle, k_RawOffset, mars_items::Food_MeatSlab());
        _Tray = Spawn_Platter(InHandle, k_TrayOffset, nullptr);

        Add_Step_WaitUntil("the station composed its Searing, feed and docks, and the pan body exists", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("both platters are constructed and the slab landed on the raw one", n"Check_PlattersReady", 0, 10.0f);
        Add_Step("dock the meat platter as raw and the empty one as the tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 3.0f);
        Add_Step("one add-food press", n"Step_Press");
        Add_Step_WaitUntil("the kernel admitted the slab and the raw platter is empty", n"Check_Admitted", 0, 5.0f);
        Add_Step("the pan holds the slab", n"Step_AssertAdmitted");
        Add_Step_WaitSeconds("a second on the hot pan", 1.0f);
        Add_Step("take the slab out by name", n"Step_TakeOut");
        Add_Step_WaitUntil("the slab landed on the tray", n"Check_OnTray", 0, 5.0f);
        Add_Step_WaitSeconds("its arrival on the tray finishes", 0.5f);
        Add_Step("the slab rides the tray with its sear; the pan holds nothing", n"Step_AssertOnTray");
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
    private void Step_Press(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceIds().Num() == 1 && _Raw.As_Platter().Get_HeldCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_PieceHandle(Get_PieceIds()[0]) == _Slab, "the pan holds the slab from the raw platter");
        Assert_True(ck::Is_NOT_Valid(_Slab.TryGet_Platter()), "the slab is on no platter");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 1, "the transfer settled Admitted");
        Assert_True(_Searing.Get_IsHot(), "the operator heated the pan");
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceId = Get_PieceIds()[0];
        _SearAtTakeOut.Empty();
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        { _SearAtTakeOut.Add(_Searing.Get_FaceSear(PieceId, EMars_Searing_Face(Face))); }

        Request_TakeOut(_Slab);
    }

    UFUNCTION()
    private void Check_OnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tray.As_Platter().Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_AssertOnTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tray = _Tray.As_Platter();
        Assert_Equals_Int(_TakenOut.Num(), 1, "the kernel handed one piece back");
        Assert_True(_Slab.TryGet_Platter() == Tray, "the slab is on the tray");
        Assert_True(Get_Parent(_Slab) == _Tray.As_Transform(), "the slab is a scene-node child of the tray's root");
        Assert_True(Get_IsKinematic(_Slab), "the slab's body is Kinematic");
        Assert_Equals_Int(Get_PieceIds().Num(), 0, "the pan holds nothing");
        Assert_Equals_Int(Get_TakenOutCount(), 1, "the kernel counts one piece taken out");

        const auto CookState = _Slab.Get_CookState();
        Assert_Equals_Int(CookState.FaceSear.Num(), utils_searing::k_FaceCount, "the cook state has every face");
        if (CookState.FaceSear.Num() != utils_searing::k_FaceCount || _SearAtTakeOut.Num() != utils_searing::k_FaceCount)
        { return; }

        auto MaxSear = 0.0f;
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        {
            const auto Written = CookState.FaceSear[Face];
            const auto Asked = _SearAtTakeOut[Face];
            Assert_True(Written >= Asked - 0.0001f && Written <= Asked + k_SearTolerance,
                f"face {Face}'s sear [{Written}] is the kernel's at the take-out [{Asked}]");
            MaxSear = Math::Max(MaxSear, Written);
        }

        Assert_True(MaxSear > 0.05f, f"the slab carries a sear (its most seared face {MaxSear})");
    }
}

class AMars_AutoTest_SearingStation_FeedTakesFromTheTrayAndTakeOutLoadsTheOther_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_FeedTakesFromTheTrayAndTakeOutLoadsTheOther;
}
