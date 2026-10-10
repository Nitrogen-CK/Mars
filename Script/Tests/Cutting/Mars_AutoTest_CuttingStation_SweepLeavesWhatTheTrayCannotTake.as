// The sweep never strands a piece: it hands off only what the tray has room for. The empty small tray docks (its dock takes
// only an empty platter), then three bare boxes are loaded onto it through the kernel, leaving room for one of its four.
// Three bare boxes are placed on the station's board and swept: exactly one is handed off and lands on the tray, two stay
// on the board, bodiless; every piece on the tray has its own Kinematic body.
class UMars_AutoTest_CuttingStation_SweepLeavesWhatTheTrayCannotTake : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(18400.0, -9000.0, -30000.0);
    private const int32 k_TrayBoxCount = 3;
    private const int32 k_BoardBoxCount = 3;

    private TArray<FCk_Handle_FoodPiece> _TrayBoxes;
    private TArray<FCk_Handle_FoodPiece> _BoardBoxes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_OutputPlatterOf(InHandle, mars_items::Platter());

        for (int32 Index = 0; Index < k_TrayBoxCount; ++Index)
        { _TrayBoxes.Add(Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + k_OutputPlatterOffset + FVector(0.0, 0.0, 20.0 * (Index + 1))))); }

        for (int32 Index = 0; Index < k_BoardBoxCount; ++Index)
        {
            const auto PileLocal = FTransform(FRotator::ZeroRotator, FVector(0.0, 15.0 * (Index - 1), 0.0)) * utils_cutting::Get_PileLocal();
            _BoardBoxes.Add(Build_Box(PileLocal * FTransform(FRotator::ZeroRotator, k_Origin)));
        }

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the empty tray is constructed", n"Check_OutputPlatterReady", 0, 10.0f);
        Add_Step_WaitUntil("every box is Ready", n"Check_BoxesReady", 0, 10.0f);
        Add_Step("dock the empty tray", n"Step_DockOutput");
        Add_Step_WaitUntil("the tray is docked", n"Check_OutputDocked", 0, 5.0f);
        Add_Step("load three boxes onto the tray", n"Step_FillTray");
        Add_Step_WaitUntil("the three boxes landed", n"Check_TrayFilled", 0, 8.0f);
        Add_Step("place three boxes on the board", n"Step_PlaceOnBoard");
        Add_Step_WaitUntil("the board holds the three boxes", n"Check_BoardFilled", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step("sweep", n"Step_Sweep");
        Add_Step_WaitUntil("the tray is full", n"Check_TrayFull", 0, 8.0f);
        Add_Step_WaitFrames("a second hand-off would have landed by now", 10);
        Add_Step("one box went to the tray; two stay on the board, bodiless", n"Step_Assert");
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
        for (const auto& Box : _BoardBoxes)
        { _Board.Request_Place(FMars_Request_FoodBoard_Place(Box)); }
    }

    UFUNCTION()
    private void Check_BoardFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == k_BoardBoxCount);
    }

    UFUNCTION()
    private void Check_TrayFull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() >= _OutputPlatter.Get_Capacity());
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_OutputPlatter.Get_Capacity(), 4, "the small tray takes four");
        Assert_Equals_Int(_Released.Num(), 1, "the board handed off exactly one box");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "two boxes stay on the board");
        Assert_Equals_Int(_OutputPlatter.Get_HeldCount(), 4, "the tray is full");
        Assert_Equals_Int(_OutputPlatter.Get_PendingCount(), 0, "nothing waits to land on the tray");
        Assert_True(_Released.Num() == 1 && _Released[0] == _BoardBoxes[0], "the first box in board order went");

        for (const auto& Box : _OutputPlatter.Get_Held())
        {
            FCk_Handle Entity = Box;
            Assert_True(Get_HasBody(Box) && utils_jolt_body::Get_MotionType(Entity.As_JoltBody()) == ECk_MotionType::Kinematic,
                f"tray box [{Box.ToString()}] froze on its own Kinematic body");
        }

        for (const auto& Box : _Board.Get_Held())
        { Assert_False(Get_HasBody(Box), f"board box [{Box.ToString()}] has no body"); }
    }
}
