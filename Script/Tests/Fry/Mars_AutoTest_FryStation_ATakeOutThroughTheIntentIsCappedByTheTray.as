// A take-out pressed through the operator's key is capped by the tray. Two boxes on the raw platter and a small finished
// tray (four places) dock on the real fry station, and three fillers are loaded onto the docked tray (its dock takes only
// an empty one); the operator rig's carrier takes the station
// through its Use interaction and feeds both boxes with its add-food key, and both are put on the basket floor, where they
// drain. The carrier's Interact_Secondary key is pressed: the station's take-out reader asks the fryer for every drained
// piece, capped at the tray's one free place, so one box is handed back and lands on the tray. Pressed again, the tray has
// no room: the take-out is capped at none and the fryer refuses it (OnTakeOutRefused NoRoom); the other box stays in the
// basket, drained and takeable. Isolated origin (173000, -70000, -30000).
class UMars_AutoTest_FryStation_ATakeOutThroughTheIntentIsCappedByTheTray : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(173000.0, -70000.0, -30000.0);
    // Behind the stand, facing the counter.
    private const FVector k_CarrierLocal = FVector(-115.0, 0.0, 0.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // A poll budget, not a ceiling: platters construct and settle, a transfer carries and a drain lasts seconds.
    private const int32 k_SlowPolls = 900;
    // The small tray's places, all but one filled before the take-out.
    private const int32 k_TrayPlaces = 4;
    private const int32 k_FillerCount = 3;
    // Each box's bottom starts this far above the basket floor, so it lands at once; the two lie apart across the basket.
    private const float64 k_BasketClearanceCm = 1.0;
    private const float64 k_BasketSpreadCm = 7.0;

    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private TArray<FCk_Handle_FoodPiece> _Boxes;
    private TArray<FCk_Handle_FoodPiece> _Fillers;
    private TArray<FMars_CookingFeed_PieceId> _Drained;
    private TArray<EMars_CookingFeed_TakeOutRefusal> _TakeOutRefusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_HeatOperator(InHandle, EMars_AutoTest_HeatStation::Fry, k_Origin, k_CarrierLocal);
        _Raw = Spawn_EmptyPlatterOf(InHandle, k_RawOffset, mars_items::Platter_Large());
        _Tray = Spawn_EmptyPlatterOf(InHandle, k_TrayOffset, mars_items::Platter());
        for (int32 Index = 0; Index < 2; ++Index)
        {
            const auto BoxWorld = FTransform(FRotator::ZeroRotator, k_Origin + k_RawOffset + FVector(0.0, 0.0, 60.0 + 15.0 * float64(Index)));
            _Boxes.Add(Build_Box(BoxWorld, GameplayTags::Food_Meat_Beef));
            Batter_Ledger(_Boxes.Last());
        }

        for (int32 Index = 0; Index < k_FillerCount; ++Index)
        {
            const auto FillerWorld = FTransform(FRotator::ZeroRotator, k_Origin + k_TrayOffset + FVector(0.0, 0.0, 60.0 + 15.0 * float64(Index)));
            _Fillers.Add(Build_Box(FillerWorld, GameplayTags::Food_Meat_Beef));
        }

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Fry, feed and docks", n"Check_HeatStationReady", 0, 0);
        Add_Step_WaitUntil("both platters are constructed and every box is Ready", n"Check_PlattersAndBoxesReady", k_SlowPolls, 0);
        Add_Step("load the two boxes onto the raw platter", n"Step_Load");
        Add_Step_WaitUntil("the boxes landed", n"Check_Loaded", k_SlowPolls, 0);
        Add_Step("dock the raw platter and the empty small tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", k_SlowPolls, 0);
        Add_Step("load the three fillers onto the docked tray", n"Step_FillTheTray");
        Add_Step_WaitUntil("the fillers landed: the tray has one free place", n"Check_TrayFilled", k_SlowPolls, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws both boxes", n"Check_OperatedAndSourced", 0, 0);
        Add_Step("press the add-food key", n"Step_PressAddFood");
        Add_Step_WaitUntil("the fryer admitted the first box", n"Check_OneAdmitted", k_SlowPolls, 0);
        Add_Step("release the add-food key", n"Step_ReleaseAddFood");
        Add_Step_WaitUntil("the feed's hand is back at rest and the key is released", n"Check_FeedIdle", k_SlowPolls, 0);
        Add_Step_WaitUntil("the second box re-froze on the raw platter and the feed offers it", n"Check_SecondOffered", k_SlowPolls, 0);
        Add_Step("press the add-food key again", n"Step_PressAddFood");
        Add_Step_WaitUntil("the fryer admitted the second box", n"Check_TwoAdmitted", k_SlowPolls, 0);
        Add_Step("release the add-food key", n"Step_ReleaseAddFood");
        Add_Step_WaitUntil("both boxes landed in the fryer and the key is released", n"Check_BothLanded", k_SlowPolls, 0);
        Add_Step("put both boxes on the basket floor", n"Step_IntoTheBasket");
        Add_Step_WaitUntil("both boxes drained", n"Check_BothDrained", k_SlowPolls, 0);
        Add_Step("press the take-out key", n"Step_PressTakeOut");
        Add_Step_WaitUntil("one box was handed back and landed on the tray, filling it", n"Check_OneOnTheTray", k_SlowPolls, 0);
        Add_Step("release the take-out key", n"Step_ReleaseTakeOut");
        Add_Step_WaitUntil("the take-out key is released", n"Check_TakeOutReleased", 0, 0);
        Add_Step("press the take-out key again", n"Step_PressTakeOut");
        Add_Step_WaitUntil("the fryer refused the take-out: the tray has no room", n"Check_RefusedNoRoom", 0, 0);
        Add_Step("one box on the tray, the other still drained in the basket", n"Step_AssertCapped");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlattersAndBoxesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllReady = Get_IsPlatterReady(_Raw, 0) && Get_IsPlatterReady(_Tray, 0);
        for (const auto& Box : _Boxes)
        { AllReady = AllReady && Box.Get_Status() == EMars_FoodPiece_Status::Ready; }

        for (const auto& Filler : _Fillers)
        { AllReady = AllReady && Filler.Get_Status() == EMars_FoodPiece_Status::Ready; }

        auto Res = OutResult;
        Res.Set(AllReady);
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fry.BindTo_OnPieceDrained(FMars_Delegate_Fry_OnPieceDrained(this, n"OnBoxDrained"));
        _Fry.BindTo_OnTakeOutRefused(FMars_Delegate_Fry_OnTakeOutRefused(this, n"OnTakeOutRefused"));

        auto Raw = _Raw.As_Platter();
        for (const auto& Box : _Boxes)
        { Raw.Request_Load(FMars_Request_Platter_Load(Box)); }
    }

    UFUNCTION()
    private void Check_Loaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, _Boxes.Num()) && Get_IsPlatterReady(_Tray, 0));
    }

    UFUNCTION()
    private void Step_FillTheTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Tray = _Tray.As_Platter();
        for (const auto& Filler : _Fillers)
        { Tray.Request_Load(FMars_Request_Platter_Load(Filler)); }
    }

    UFUNCTION()
    private void Check_TrayFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tray.As_Platter().Get_HeldCount() == k_FillerCount && _Tray.As_Platter().Get_FreeCount() == 1);
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
        Res.Set(Get_IsStationOperated() && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == _Boxes.Num());
    }

    UFUNCTION()
    private void Step_PressAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_StationAddFood);
    }

    UFUNCTION()
    private void Step_ReleaseAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_StationAddFood);
    }

    UFUNCTION()
    private void Check_OneAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceIds().Num() == 1);
    }

    UFUNCTION()
    private void Check_FeedIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle && Get_IsRowHeld(GameplayTags::Mars_Intent_StationAddFood) == false);
    }

    // Taking the first box re-settles the one left on the raw platter, and the feed refuses a press (Busy) until it
    // re-freezes.
    UFUNCTION()
    private void Check_SecondOffered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Available() == 1 && _Feed.Get_IsSettling() == false && _Raw.As_Platter().Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Check_TwoAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceIds().Num() == 2 && _Raw.As_Platter().Get_Occupancy() == 0);
    }

    // In play and come down (the oil, the skimmer or the basket): neither still falling nor lost.
    UFUNCTION()
    private void Check_BothLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto PieceIds = Get_PieceIds();
        auto BothLanded = PieceIds.Num() == 2 && Get_IsRowHeld(GameplayTags::Mars_Intent_StationAddFood) == false;
        for (const auto& PieceId : PieceIds)
        {
            const auto Whereabouts = _Fry.Get_PieceWhereabouts(PieceId);
            BothLanded = BothLanded && Whereabouts != EMars_Fry_Whereabouts::Airborne && Whereabouts != EMars_Fry_Whereabouts::Lost;
        }

        auto Res = OutResult;
        Res.Set(BothLanded);
    }

    // Each box's middle over the basket floor, level with the basket, its bottom k_BasketClearanceCm above the floor; the two
    // k_BasketSpreadCm either side of the floor's centre across the basket.
    UFUNCTION()
    private void Step_IntoTheBasket(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceIds = Get_PieceIds();
        const auto Basket = _Fry.Get_BasketWorld();
        const auto Rotation = Basket.GetRotation();
        for (int32 Index = 0; Index < PieceIds.Num(); ++Index)
        {
            const auto PieceId = PieceIds[Index];
            const auto HalfExtents = _Fry.Get_PieceHalfExtents(PieceId);
            const auto CentreLocal = _Fry.Get_PieceState(PieceId).CentreLocal;
            const auto Side = Index == 0 ? -k_BasketSpreadCm : k_BasketSpreadCm;
            const auto Centre = Basket.TransformPosition(FVector(0.0, Side, HalfExtents.Z + k_BasketClearanceCm));
            auto Body = _Fry.Get_PieceBody(PieceId);
            utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Centre - Rotation.RotateVector(CentreLocal), Rotation.Rotator()));
        }
    }

    UFUNCTION()
    private void Check_BothDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_TakeableCount() == 2);
    }

    UFUNCTION()
    private void Step_PressTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    UFUNCTION()
    private void Check_OneOnTheTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakenOut.Num() == 1 && _TakenOut[0].TryGet_Platter() == _Tray.As_Platter()
            && _Tray.As_Platter().Get_Occupancy() == k_TrayPlaces);
    }

    UFUNCTION()
    private void Step_ReleaseTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    UFUNCTION()
    private void Check_TakeOutReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Secondary) == false);
    }

    UFUNCTION()
    private void Check_RefusedNoRoom(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakeOutRefusals.Contains(EMars_CookingFeed_TakeOutRefusal::NoRoom));
    }

    UFUNCTION()
    private void Step_AssertCapped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tray = _Tray.As_Platter();
        Assert_Equals_Int(Tray.Get_Capacity(), k_TrayPlaces, "the small tray takes four");
        Assert_Equals_Int(Tray.Get_Occupancy(), k_TrayPlaces, "the tray holds the three fillers and one box");
        Assert_True(_TakenOut.Num() == 1 && _Boxes.Contains(_TakenOut[0]), f"the first press handed back one box ({_TakenOut.Num()} handed back)");
        Assert_True(_TakeOutRefusals.Num() == 1 && _TakeOutRefusals[0] == EMars_CookingFeed_TakeOutRefusal::NoRoom,
            f"the second press was refused once, for no room ({_TakeOutRefusals.Num()} refusals)");

        const auto PieceIds = Get_PieceIds();
        Assert_Equals_Int(PieceIds.Num(), 1, "the fryer still holds one box");
        Assert_True(PieceIds.Num() == 1 && _Boxes.Contains(_Fry.Get_PieceHandle(PieceIds[0])) && _Fry.Get_PieceHandle(PieceIds[0]) != _TakenOut[0],
            "the fryer holds the other box");
        Assert_Equals_Int(_Fry.Get_TakeableCount(), 1, "the other box is drained and takeable");
        Assert_Equals_Int(_Fry.Get_Summary().TakenOut, 1, "the fryer counts one piece taken out");
    }

    UFUNCTION()
    private void OnBoxDrained(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId)
    {
        _Drained.Add(InPieceId);
    }

    UFUNCTION()
    private void OnTakeOutRefused(FCk_Handle_Fry InFry, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        _TakeOutRefusals.Add(InRefusal);
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
