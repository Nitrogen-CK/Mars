// The fry station's whole round on real pieces. A platter with a mushroom slice docks on the raw platter dock (the fryer
// takes any food) and an empty platter on the finished tray's; an operator takes the station and one add-food press
// carries the slice: the bridge unloads it from the raw platter and the kernel admits it into the oil. After a second of
// frying the test takes that piece out by name, as a take-out press would: the station's take-out task loads it onto the
// docked tray, where it rides as a scene-node child of the tray's root with its body Kinematic, carrying the heat the
// kernel gave its faces; the fryer holds nothing and the kernel counts one piece taken out.
class UMars_AutoTest_FryStation_TakeOutLoadsTheTray : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(14400.0, -12000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // A frame of frying between the snapshot and the take-out's drain moves a face far less than this.
    private const float32 k_HeatTolerance = 0.05f;

    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private FCk_Handle_FoodPiece _Slice;
    // The kernel's face heats as the take-out was asked for.
    private TArray<float32> _HeatAtTakeOut;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Fry(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Raw = Spawn_Platter(InHandle, k_RawOffset, mars::Food_MushroomSlice_Mars);
        _Tray = Spawn_Platter(InHandle, k_TrayOffset, nullptr);

        Add_Step_WaitUntil("the station composed its Fry, feed and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("both platters are constructed and the slice landed on the raw one", n"Check_PlattersReady", 0, 10.0f);
        Add_Step("dock the mushroom platter as raw and the empty one as the tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 3.0f);
        Add_Step("one add-food press", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the kernel admitted the slice and the raw platter is empty", n"Check_Admitted", 0, 5.0f);
        Add_Step("the fryer holds the slice", n"Step_AssertAdmitted");
        Add_Step_WaitSeconds("a second in the oil", 1.0f);
        Add_Step("take the slice out by name", n"Step_TakeOut");
        Add_Step_WaitUntil("the slice landed on the tray", n"Check_OnTray", 0, 5.0f);
        Add_Step_WaitSeconds("its arrival on the tray finishes", 0.5f);
        Add_Step("the slice rides the tray with its heat; the fryer holds nothing", n"Step_AssertOnTray");
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
        _Slice = _Raw.As_Platter().Get_Held()[0];
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
        Res.Set(Get_PieceIds().Num() == 1 && _Raw.As_Platter().Get_HeldCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_PieceHandle(Get_PieceIds()[0]) == _Slice, "the fryer holds the slice from the raw platter");
        Assert_True(ck::Is_NOT_Valid(_Slice.TryGet_Platter()), "the slice is on no platter");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 1, "the transfer settled Admitted");
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceId = Get_PieceIds()[0];
        _HeatAtTakeOut.Empty();
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        { _HeatAtTakeOut.Add(_Fry.Get_FaceHeat(PieceId, EMars_Searing_Face(Face))); }

        Request_TakeOut(_Slice);
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
        Assert_True(_Slice.TryGet_Platter() == Tray, "the slice is on the tray");
        Assert_True(Get_Parent(_Slice) == _Tray.As_Transform(), "the slice is a scene-node child of the tray's root");
        Assert_True(Get_IsKinematic(_Slice), "the slice's body is Kinematic");
        Assert_Equals_Int(Get_PieceIds().Num(), 0, "the fryer holds nothing");
        Assert_Equals_Int(Get_TakenOutCount(), 1, "the kernel counts one piece taken out");

        const auto CookState = _Slice.Get_CookState();
        Assert_Equals_Int(CookState.FaceSear.Num(), utils_searing::k_FaceCount, "the cook state has every face");
        if (CookState.FaceSear.Num() != utils_searing::k_FaceCount || _HeatAtTakeOut.Num() != utils_searing::k_FaceCount)
        { return; }

        auto MaxHeat = 0.0f;
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        {
            const auto Written = CookState.FaceSear[Face];
            const auto Asked = _HeatAtTakeOut[Face];
            Assert_True(Written >= Asked - 0.0001f && Written <= Asked + k_HeatTolerance,
                f"face {Face}'s heat [{Written}] is the kernel's at the take-out [{Asked}]");
            MaxHeat = Math::Max(MaxHeat, Written);
        }

        Assert_True(MaxHeat > 0.0f, f"the slice carries the oil's heat (its hottest face {MaxHeat})");
    }
}
