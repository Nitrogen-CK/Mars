// An emptied board takes the next joint on the next add food. The station's input dock takes whole food however much of it:
// an input platter carrying two bare boxes docks with a tray beside it, and add food lays the top box of the pile on the
// board (nobody operating: the feed's tasks run in Idle too). A sweep hands that box to the tray, emptying the board, and the
// next add food brings the other box off the input platter onto the board. The tray holds the first box taken, the board the
// second, and the input platter is empty.
class UMars_AutoTest_CuttingStation_SweepingTheBoardEmptyTakesTheNextJoint : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(20000.0, -9000.0, -30000.0);

    private FCk_Handle _InputPlatterSpawned;
    private TArray<FCk_Handle_FoodPiece> _Boxes;
    // The box the feed took first, and the one left on the input platter.
    private FCk_Handle_FoodPiece _First;
    private FCk_Handle_FoodPiece _Second;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_OutputPlatter(InHandle);

        _InputPlatterSpawned = Spawn_PlatterAt(InHandle, k_InputPlatterOffset,
            FMars_Platter_SpawnSpec(FTransform::Identity, mars_items::Platter_Large()));
        for (int32 Index = 0; Index < 2; ++Index)
        { _Boxes.Add(Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + k_InputPlatterOffset + FVector(100.0, 20.0 * Index, 0.0)))); }

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("both platters are constructed and both boxes are Ready", n"Check_PlattersAndBoxesReady", 0, 10.0f);
        Add_Step("load both boxes onto the input platter", n"Step_LoadBoxes");
        Add_Step_WaitUntil("both boxes landed", n"Check_BoxesLanded", 0, 8.0f);
        Add_Step("dock the input platter and the tray", n"Step_DockBoth");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_BothDocked", 0, 5.0f);
        Add_Step_WaitUntil("the feed draws from the input platter, its pile frozen", n"Check_FeedSourced", 0, 5.0f);
        Add_Step("add food", n"Step_AddFood");
        Add_Step_WaitUntil("the feed laid the first box on the board and the glove is back", n"Check_FirstOnBoard", 0, 5.0f);
        Add_Step("one box on the board, one on the input platter; sweep", n"Step_AssertFirstThenSweep");
        Add_Step_WaitUntil("the first box is on the tray and the board is empty", n"Check_FirstOnTray", 0, 8.0f);
        Add_Step_WaitUntil("the other box is frozen on the input platter", n"Check_FeedSourced", 0, 5.0f);
        Add_Step("add food again", n"Step_AddFood");
        Add_Step_WaitUntil("the second box is on the board and the glove is back", n"Check_SecondOnBoard", 0, 8.0f);
        Add_Step_WaitFrames("the second box's pile pose lands", 2);
        Add_Step("the tray holds the first box, the board the second; the input platter is empty", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlattersAndBoxesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = Get_IsPlatterConstructed(_InputPlatterSpawned) && _Boxes[0].Get_Status() == EMars_FoodPiece_Status::Ready
            && _Boxes[1].Get_Status() == EMars_FoodPiece_Status::Ready;
        if (IsReady && ck::Is_NOT_Valid(_InputPlatter))
        {
            _InputPlatter = _InputPlatterSpawned.As_Platter();
            _InputPlatterItem = _InputPlatterSpawned.As_WorldItem().Get_HeldItem();
        }

        Check_OutputPlatterReady(InHandle, OutResult, InPayload);
        auto Res = OutResult;
        Res.Set(IsReady && ck::IsValid(_OutputPlatter));
    }

    UFUNCTION()
    private void Step_LoadBoxes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Box : _Boxes)
        { _InputPlatter.Request_Load(FMars_Request_Platter_Load(Box)); }
    }

    UFUNCTION()
    private void Check_BoxesLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_InputPlatter.Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Step_DockBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock_Input();
        Dock_Output();
    }

    UFUNCTION()
    private void Check_BothDocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_InputDock.Get_Platter() == _InputPlatter && Get_HasArrived(_InputPlatter)
            && _OutputDock.Get_Platter() == _OutputPlatter && Get_HasArrived(_OutputPlatter));
    }

    UFUNCTION()
    private void Check_FirstOnBoard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == 1 && _InputPlatter.Get_HeldCount() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void Step_AssertFirstThenSweep(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Cutting_Idle,
            "nobody operates the station");
        _First = _Board.Get_Held()[0];
        _Second = _First == _Boxes[0] ? _Boxes[1] : _Boxes[0];
        Assert_True(_Boxes.Contains(_First), "the board holds one of the boxes");
        Assert_True(_InputPlatter.Get_Held()[0] == _Second, "the other box waits on the input platter");

        utils_cutting::Request_Sweep(_Station);
    }

    UFUNCTION()
    private void Check_FirstOnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() == 1 && _Board.Get_HeldCount() == 0);
    }

    UFUNCTION()
    private void Check_SecondOnBoard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() == 1 && _Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Second
            && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_First.TryGet_Platter() == _OutputPlatter, "the first box taken is on the tray");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Second, "the board holds the second box");
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 0, "the input platter is empty");
        Assert_Equals_Int(_InputPlatter.Get_PendingCount(), 0, "nothing waits to land on the input platter");
        Assert_Equals_Int(_Released.Num(), 1, "the sweep handed off one box");
        Assert_Equals_Int(_Placed.Num(), 2, "the feed placed each box once");
        Assert_Equals_Int(_Feed.Get_Admitted(), 2, "the feed counted two admissions");
        Assert_True(ck::Is_NOT_Valid(_Second.TryGet_Platter()), "the second box names no platter");

        const auto Pile = (utils_cutting::Get_PileLocal() * Get_StationWorld()).GetLocation();
        const auto Offset = Get_World(_Second).GetLocation() - Pile;
        Assert_True(Math::Abs(Offset.X) <= 0.5 && Math::Abs(Offset.Y) <= 0.5, f"the second box lies at the pile ({Offset} off)");
    }
}
