// A piece sourced from a docked platter drains in the basket, and the operator's take-out press puts it on the tray. A box
// loaded onto the raw platter the kernel's way gets its body from the platter's drop (utils_foodpiece::Add_Body) and keeps
// it into the fryer: one add-food press releases it into the oil. Put on the basket floor, it rests there, so OnPieceDrained
// fires once its support has lasted Receiver.DrainSeconds; then the station's take-out onto the docked tray, at most one
// (the press's shape), hands it back and the fryer loads it onto that tray.
class UMars_AutoTest_FryStation_APlatterSourcedPieceDrainsAndIsTakenOut : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(40000.0, -12000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // The box's bottom starts this far above the basket floor, so it lands at once.
    private const float64 k_BasketClearanceCm = 1.0;
    // A poll budget, not a ceiling: platters construct, drop and settle, and a drain lasts seconds.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private FCk_Handle_FoodPiece _Box;
    private TArray<FMars_CookingFeed_PieceId> _Drained;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Fry(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Raw = Spawn_Platter(InHandle, k_RawOffset, nullptr);
        _Tray = Spawn_Platter(InHandle, k_TrayOffset, nullptr);
        _Box = Build_Box(FTransform(FRotator::ZeroRotator, _Origin + k_RawOffset + FVector(0.0, 0.0, 60.0)), GameplayTags::Food_Meat_Beef);
        Batter_Ledger(_Box);

        Add_Step_WaitUntil("the station composed its Fry, feed and docks", n"Check_StationReady", 0, 0);
        Add_Step_WaitUntil("both platters are constructed and the box is Ready", n"Check_PlattersAndBoxReady", k_SlowPolls, 0);
        Add_Step("load the box onto the raw platter", n"Step_LoadBox");
        Add_Step_WaitUntil("the box landed on the raw platter", n"Check_BoxLanded", k_SlowPolls, 0);
        Add_Step("dock the raw platter and the empty tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", k_SlowPolls, 0);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 0);
        Add_Step("one add-food press", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the fryer admitted the box", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the box is in the oil", n"Check_InOil", 0, 0);
        Add_Step("put the box on the basket floor", n"Step_IntoTheBasket");
        Add_Step_WaitUntil("OnPieceDrained fired for the box", n"Check_Drained", k_SlowPolls, 0);
        Add_Step("a take-out press: no piece named, at most one", n"Step_TakeOutOne");
        Add_Step_WaitUntil("the box landed on the tray", n"Check_OnTray", k_SlowPolls, 0);
        Add_Step("the box rides the tray and the fryer holds nothing", n"Step_AssertOnTray");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlattersAndBoxReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 0) && Get_IsPlatterReady(_Tray, 0) && _Box.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Step_LoadBox(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fry.BindTo_OnPieceDrained(FMars_Delegate_Fry_OnPieceDrained(this, n"OnBoxDrained"));

        auto Raw = _Raw.As_Platter();
        Raw.Request_Load(FMars_Request_Platter_Load(_Box));
    }

    UFUNCTION()
    private void Check_BoxLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 1));
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle BoxEntity = _Box;
        Assert_True(BoxEntity.Is_JoltBody(), "the platter's drop gave the box its body");
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
        Res.Set(Get_PieceIds().Num() == 1 && _Raw.As_Platter().Get_Occupancy() == 0);
    }

    UFUNCTION()
    private void Check_InOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto PieceIds = Get_PieceIds();
        auto Res = OutResult;
        Res.Set(PieceIds.Num() == 1 && _Fry.Get_PieceWhereabouts(PieceIds[0]) == EMars_Fry_Whereabouts::Oil);
    }

    // The box's middle over the basket floor's centre, level with the basket, its bottom k_BasketClearanceCm above the floor.
    UFUNCTION()
    private void Step_IntoTheBasket(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceId = Get_PieceIds()[0];
        Assert_True(Get_PieceHandle(PieceId) == _Box, "the fryer holds the box from the raw platter");

        const auto Basket = _Fry.Get_BasketWorld();
        const auto HalfExtents = _Fry.Get_PieceHalfExtents(PieceId);
        const auto CentreLocal = _Fry.Get_PieceState(PieceId).CentreLocal;
        const auto Rotation = Basket.GetRotation();
        const auto Centre = Basket.TransformPosition(FVector(0.0, 0.0, HalfExtents.Z + k_BasketClearanceCm));
        auto Body = _Fry.Get_PieceBody(PieceId);
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Centre - Rotation.RotateVector(CentreLocal), Rotation.Rotator()));
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Drained.Num() > 0);
    }

    UFUNCTION()
    private void Step_TakeOutOne(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Station = _Fry;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(1, _Tray.As_Platter()));
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
        Assert_Equals_Int(_Drained.Num(), 1, "the box drained once");
        Assert_Equals_Int(_TakenOut.Num(), 1, "the take-out handed one piece back");
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == _Box, "it is the box");
        Assert_True(_Box.TryGet_Platter() == Tray, "the box is on the tray");
        Assert_True(Get_Parent(_Box) == _Tray.As_Transform(), "the box is a scene-node child of the tray's root");
        Assert_True(Get_IsKinematic(_Box), "the box's body is Kinematic");
        Assert_Equals_Int(Get_PieceIds().Num(), 0, "the fryer holds nothing");
    }

    UFUNCTION()
    private void OnBoxDrained(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId)
    {
        _Drained.Add(InPieceId);
    }

    // The fryer admits only battered pieces: the box arrives as the batter station's take-out hands one back.
    private void Batter_Ledger(FCk_Handle_FoodPiece InBox)
    {
        auto Box = InBox;
        auto CookState = Box.Get_CookState();
        CookState.Battered = 1.0f;
        Box.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
    }
}
