// A sweep the tray cannot take whole strands nothing: what the tray refuses goes back on the board. The empty small tray
// docks (four places) and three bare boxes are loaded onto it through the kernel, leaving room for one. Three bare boxes
// are placed on the station's board, and the station's take-out onto the tray hands all three off at once (capped at three:
// a sweep whose room was read before the tray filled). The board loads each onto the tray in board order: the first lands
// there (the tray's OnLoaded names it) and the tray, full, refuses the other two, which the board places back: members
// again, bodiless, where they lay.
class UMars_AutoTest_CuttingStation_ASweepRefusedByAFullTrayReplacesThePieces : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(25600.0, -9000.0, -30000.0);
    private const int32 k_TrayBoxCount = 3;
    private const int32 k_BoardBoxCount = 3;

    private TArray<FCk_Handle_FoodPiece> _TrayBoxes;
    private TArray<FCk_Handle_FoodPiece> _BoardBoxes;
    private TArray<FCk_Handle_FoodPiece> _LandedOnTray;
    private int32 _PlacedBeforeSweep = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_OutputPlatterOf(InHandle, mars_items::Platter());

        for (int32 Index = 0; Index < k_TrayBoxCount; ++Index)
        { _TrayBoxes.Add(Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + k_OutputPlatterOffset + FVector(0.0, 0.0, 20.0 * (Index + 1))))); }

        for (int32 Index = 0; Index < k_BoardBoxCount; ++Index)
        {
            _BoardBoxes.Add(Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + Get_PileOffset(Index))));
        }

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 0);
        Add_Step_WaitUntil("the empty tray is constructed", n"Check_OutputPlatterReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("every box is Ready", n"Check_BoxesReady", k_SlowPolls, 0);
        Add_Step("dock the empty tray", n"Step_DockOutput");
        Add_Step_WaitUntil("the tray is docked", n"Check_OutputDocked", k_SlowPolls, 0);
        Add_Step("load three boxes onto the tray", n"Step_FillTray");
        Add_Step_WaitUntil("the three boxes landed", n"Check_TrayFilled", k_SlowPolls, 0);
        Add_Step("place three boxes on the board", n"Step_PlaceOnBoard");
        Add_Step_WaitUntil("the board holds the three boxes", n"Check_BoardFilled", 0, 0);
        Add_Step("the board hands all three off at once", n"Step_HandOffAll");
        Add_Step_WaitUntil("one landed on the tray and two are back on the board", n"Check_OneLandedTwoBack", k_SlowPolls, 0);
        Add_Step_WaitFrames("a stray load or place would have drained by now", 10);
        Add_Step("the first box rides the tray; the other two are the board's again", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_BoxesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllReady = true;
        for (const auto& Box : _TrayBoxes)
        { AllReady = AllReady && Box.Get_Status() == EMars_FoodPiece_Status::Ready; }

        for (const auto& Box : _BoardBoxes)
        { AllReady = AllReady && Box.Get_Status() == EMars_FoodPiece_Status::Ready; }

        auto Res = OutResult;
        Res.Set(AllReady);
    }

    UFUNCTION()
    private void Step_FillTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _OutputPlatter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnTrayLoaded"));
        for (const auto& Box : _TrayBoxes)
        { _OutputPlatter.Request_Load(FMars_Request_Platter_Load(Box)); }
    }

    UFUNCTION()
    private void Check_TrayFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() == k_TrayBoxCount);
    }

    UFUNCTION()
    private void Step_PlaceOnBoard(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < _BoardBoxes.Num(); ++Index)
        {
            Pose_OnPile(_BoardBoxes[Index], Get_PileOffset(Index));
            _Board.Request_Place(FMars_Request_FoodBoard_Place(_BoardBoxes[Index]));
        }
    }

    // In a row along the board (the pile node's Y), 15 cm apart.
    private FVector Get_PileOffset(int32 InIndex) const
    {
        return FVector(0.0, 15.0 * (InIndex - 1), 0.0);
    }

    UFUNCTION()
    private void Check_BoardFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == k_BoardBoxCount);
    }

    UFUNCTION()
    private void Step_HandOffAll(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_OutputPlatter.Get_FreeCount(), 1, "the tray has room for one");
        _PlacedBeforeSweep = _Placed.Num();
        FCk_Handle Station = _Station;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(k_BoardBoxCount, _OutputPlatter));
    }

    UFUNCTION()
    private void Check_OneLandedTwoBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_LandedOnTray.Contains(_BoardBoxes[0]) && _Board.Get_HeldCount() == 2 && _Placed.Num() - _PlacedBeforeSweep == 2);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_OutputPlatter.Get_Capacity(), 4, "the small tray takes four");
        Assert_Equals_Int(_Released.Num(), 3, "the board handed all three off");
        Assert_Equals_Int(_OutputPlatter.Get_HeldCount(), 4, "the tray is full");
        Assert_Equals_Int(_OutputPlatter.Get_PendingCount(), 0, "nothing waits to land on the tray");
        Assert_True(_BoardBoxes[0].TryGet_Platter() == _OutputPlatter, "the first box in board order went to the tray");
        Assert_True(_LandedOnTray.Contains(_BoardBoxes[0]), "and landed there");
        Assert_Equals_Int(_Placed.Num() - _PlacedBeforeSweep, 2, "two were placed back on the board");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the board holds two");

        for (int32 Index = 1; Index < k_BoardBoxCount; ++Index)
        {
            const auto Box = _BoardBoxes[Index];
            Assert_True(_Board.Get_Held().Contains(Box), f"board box {Index} is on the board again");
            Assert_True(Box.TryGet_FoodBoard() == _Board, f"board box {Index} is the board's member");
            Assert_True(ck::Is_NOT_Valid(Box.TryGet_Platter()), f"board box {Index} names no platter");
            Assert_False(Get_HasBody(Box), f"board box {Index} has no body");
        }
    }

    UFUNCTION()
    private void OnTrayLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        _LandedOnTray.Add(InPiece);
    }
}
