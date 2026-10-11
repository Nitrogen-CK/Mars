// A take-out the tray refuses goes back to the fryer: the hand-off is acknowledged, never left lying ledger-less. A box
// sourced from the docked raw platter is fried and put on the basket floor, where it drains (OnPieceDrained). A small
// finished tray (four places) is docked; in one frame four other boxes are loaded onto it and the station's take-out onto
// that tray (at most one: a press whose room was read before the tray filled) hands the box back. The tray is full, so it
// refuses the box, and the fryer readopts it (Request_Readopt): it is in play again where it lies, under its own id, its
// body Dynamic, the take-out no longer counted; lying in the basket it drains again (OnPieceDrained once more) and is
// takeable again. It never reached the tray.
class UMars_AutoTest_FryStation_ATakeOutRefusedByTheTrayIsReadopted : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(45200.0, -12000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // The box's bottom starts this far above the basket floor, so it lands at once.
    private const float64 k_BasketClearanceCm = 1.0;
    // A poll budget, not a ceiling: platters construct, drop and settle, and a drain lasts seconds.
    private const int32 k_SlowPolls = 900;
    // The small tray's places.
    private const int32 k_FillerCount = 4;

    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private FCk_Handle_FoodPiece _Box;
    private TArray<FCk_Handle_FoodPiece> _Fillers;
    private FMars_CookingFeed_PieceId _BoxId;
    private TArray<FMars_CookingFeed_PieceId> _Drained;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Fry(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Raw = Spawn_Platter(InHandle, k_RawOffset, nullptr);
        _Tray = Spawn_EmptyPlatterOf(InHandle, k_TrayOffset, mars_items::Platter());
        _Box = Build_Box(FTransform(FRotator::ZeroRotator, _Origin + k_RawOffset + FVector(0.0, 0.0, 60.0)), GameplayTags::Food_Meat_Beef);
        Batter_Ledger(_Box);
        for (int32 Index = 0; Index < k_FillerCount; ++Index)
        {
            const auto FillerWorld = FTransform(FRotator::ZeroRotator, _Origin + k_TrayOffset + FVector(0.0, 0.0, 60.0 + 15.0 * float64(Index)));
            _Fillers.Add(Build_Box(FillerWorld, GameplayTags::Food_Meat_Beef));
        }

        Add_Step_WaitUntil("the station composed its Fry, feed and docks", n"Check_StationReady", 0, 0);
        Add_Step_WaitUntil("both platters are constructed and every box is Ready", n"Check_PlattersAndBoxesReady", k_SlowPolls, 0);
        Add_Step("load the box onto the raw platter", n"Step_LoadBox");
        Add_Step_WaitUntil("the box landed on the raw platter", n"Check_BoxLanded", k_SlowPolls, 0);
        Add_Step("dock the raw platter and the empty small tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", k_SlowPolls, 0);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 0);
        Add_Step("one add-food press", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the fryer admitted the box", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the box is in the oil", n"Check_InOil", 0, 0);
        Add_Step("put the box on the basket floor", n"Step_IntoTheBasket");
        Add_Step_WaitUntil("OnPieceDrained fired for the box", n"Check_DrainedOnce", k_SlowPolls, 0);
        Add_Step("the tray fills and a take-out press hands the box back in the same frame", n"Step_FillTheTrayAndTakeOut");
        Add_Step_WaitUntil("the tray refused the box and the fryer has it again", n"Check_Readopted", 0, 0);
        Add_Step_WaitUntil("the box drained again", n"Check_DrainedTwice", k_SlowPolls, 0);
        Add_Step("in play, drained, takeable again; never on the tray", n"Step_AssertReadopted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlattersAndBoxesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllReady = Get_IsPlatterReady(_Raw, 0) && Get_IsPlatterReady(_Tray, 0) && _Box.Get_Status() == EMars_FoodPiece_Status::Ready;
        for (const auto& Filler : _Fillers)
        { AllReady = AllReady && Filler.Get_Status() == EMars_FoodPiece_Status::Ready; }

        auto Res = OutResult;
        Res.Set(AllReady);
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
        _BoxId = Get_PieceIds()[0];
        Assert_True(Get_PieceHandle(_BoxId) == _Box, "the fryer holds the box from the raw platter");

        const auto Basket = _Fry.Get_BasketWorld();
        const auto HalfExtents = _Fry.Get_PieceHalfExtents(_BoxId);
        const auto CentreLocal = _Fry.Get_PieceState(_BoxId).CentreLocal;
        const auto Rotation = Basket.GetRotation();
        const auto Centre = Basket.TransformPosition(FVector(0.0, 0.0, HalfExtents.Z + k_BasketClearanceCm));
        auto Body = _Fry.Get_PieceBody(_BoxId);
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Centre - Rotation.RotateVector(CentreLocal), Rotation.Rotator()));
    }

    UFUNCTION()
    private void Check_DrainedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Drained.Num() == 1);
    }

    // The fillers queue ahead of the take-out's load on the tray's next drain, so the tray is full when the box arrives.
    UFUNCTION()
    private void Step_FillTheTrayAndTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Fry.Get_TakeableCount(), 1, "the drained box is takeable");

        auto Tray = _Tray.As_Platter();
        for (const auto& Filler : _Fillers)
        { Tray.Request_Load(FMars_Request_Platter_Load(Filler)); }

        FCk_Handle Station = _Fry;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(1, Tray));
    }

    UFUNCTION()
    private void Check_Readopted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakenOut.Num() == 1 && _Fry.Get_HasPiece(_BoxId));
    }

    UFUNCTION()
    private void Check_DrainedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Drained.Num() == 2);
    }

    UFUNCTION()
    private void Step_AssertReadopted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tray = _Tray.As_Platter();
        Assert_Equals_Int(Tray.Get_Capacity(), k_FillerCount, "the small tray takes four");
        Assert_Equals_Int(Tray.Get_Occupancy(), k_FillerCount, "the tray holds the four fillers");
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == _Box, "the take-out handed the box back once");
        Assert_True(ck::Is_NOT_Valid(_Box.TryGet_Platter()), "the box never reached the tray");

        Assert_Equals_Int(Get_PieceIds().Num(), 1, "the fryer holds one piece");
        Assert_True(Get_PieceHandle(_BoxId) == _Box, "the box, under its own id");
        Assert_True(_Drained.Num() == 2 && _Drained[1].Get_IsSame(_BoxId), "it drained again");
        Assert_True(_Fry.Get_PieceWhereabouts(_BoxId) == EMars_Fry_Whereabouts::DrainBasket, "it lies in the basket");
        Assert_True(_Fry.Get_PieceDrain(_BoxId) == EMars_Fry_Drain::Drained, "drained");
        Assert_Equals_Int(_Fry.Get_TakeableCount(), 1, "takeable again");
        Assert_Equals_Int(Get_TakenOutCount(), 0, "the refused take-out no longer counts");
        Assert_False(Get_IsKinematic(_Box), "its body is Dynamic again");
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
