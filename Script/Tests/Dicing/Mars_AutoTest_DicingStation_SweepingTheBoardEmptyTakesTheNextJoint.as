// An emptied board takes the next joint. The station is spawned with an input dock that takes two whole pieces (a test
// subclass of the station); an input platter carrying two bare boxes docks, and with nobody operating, the intake lays the
// first box on the board. A tray docks and a sweep hands that box to it: the board's release empties it, and the intake
// takes the second box off the input platter onto the board. The tray holds the first box, the board the second, and the
// input platter is empty.
class UMars_AutoTest_DicingStation_SweepingTheBoardEmptyTakesTheNextJoint : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(20000.0, -9000.0, -30000.0);

    private FCk_Handle _InputPlatterSpawned;
    private TArray<FCk_Handle_FoodPiece> _Boxes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_StationOfClass(InHandle, k_Origin, UMars_AutoTestStation_TwoJointDicing_EntityScript);
        Spawn_OutputPlatter(InHandle);

        auto Owner = InHandle;
        _InputPlatterSpawned = utils_platter::Request_SpawnWorld(Owner,
            FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + k_InputPlatterOffset)));
        for (int32 Index = 0; Index < 2; ++Index)
        { _Boxes.Add(Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + k_InputPlatterOffset + FVector(100.0, 20.0 * Index, 0.0)))); }

        Add_Step_WaitUntil("the station composed its Dicing, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("both platters are constructed and both boxes are Ready", n"Check_PlattersAndBoxesReady", 0, 10.0f);
        Add_Step("load both boxes onto the input platter", n"Step_LoadBoxes");
        Add_Step_WaitUntil("both boxes landed", n"Check_BoxesLanded", 0, 5.0f);
        Add_Step("dock the input platter and the tray", n"Step_DockBoth");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_BothDocked", 0, 5.0f);
        Add_Step_WaitUntil("the intake laid the first box on the board", n"Check_FirstOnBoard", 0, 5.0f);
        Add_Step("one box on the board, one on the input platter; sweep", n"Step_AssertFirstThenSweep");
        Add_Step_WaitUntil("the first box is on the tray and the second on the board", n"Check_SecondOnBoard", 0, 5.0f);
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
        Assert_True(_InputDock.Get_Spec().Policy.MaxPieces == 2, "the test station's input dock takes two pieces");
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
        Res.Set(_Board.Get_HeldCount() == 1 && _InputPlatter.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_AssertFirstThenSweep(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Dicing_Idle,
            "nobody operates the station");
        Assert_True(_Board.Get_Held()[0] == _Boxes[0], "the board holds the first box");
        Assert_True(_InputPlatter.Get_Held()[0] == _Boxes[1], "the second box waits on the input platter");

        utils_dicing::Request_Sweep(_Station);
    }

    UFUNCTION()
    private void Check_SecondOnBoard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() == 1 && _Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Boxes[1]);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Boxes[0].TryGet_Platter() == _OutputPlatter, "the first box is on the tray");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Boxes[1], "the board holds the second box");
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 0, "the input platter is empty");
        Assert_Equals_Int(_InputPlatter.Get_PendingCount(), 0, "nothing waits to land on the input platter");
        Assert_Equals_Int(_Released.Num(), 1, "the sweep handed off one box");
        Assert_Equals_Int(_Placed.Num(), 2, "the intake placed each box once");
        Assert_True(ck::Is_NOT_Valid(_Boxes[1].TryGet_Platter()), "the second box names no platter");
        Assert_False(Get_HasBody(_Boxes[1]), "the second box has no body");

        const auto Pile = (utils_dicing::Get_PileLocal() * Get_StationWorld()).GetLocation();
        const auto Offset = Get_World(_Boxes[1]).GetLocation() - Pile;
        Assert_True(Math::Abs(Offset.X) <= 0.5 && Math::Abs(Offset.Y) <= 0.5, f"the second box lies at the pile ({Offset} off)");
    }
}

// The dicing station with an input dock that takes two whole pieces, so a platter can bring a second joint.
class UMars_AutoTestStation_TwoJointDicing_EntityScript : UMars_DicingStation_EntityScript
{
    default Docks.Input.MaxPieces = TOptional<int32>(2);
}
