// A chop cuts every piece it straddles, not the few a small budget allowed. Three whole mushroom slices lie on the station's
// board in a row along the board's depth (station X), the blade's face, all at one lateral position; the hand moves over
// their shared centre and chops once. The board's answer names three straddling pieces and issues three cuts within a
// budget of the station's MaxCutsPerChop (8), and each slice is cut in two. Isolated origin (30000, -21000, -30000).
class UMars_AutoTest_CuttingStation_AChopCutsEveryPieceItStraddles : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(30000.0, -21000.0, -30000.0);
    private const int32 k_BoxCount = 3;

    private TArray<FCk_Handle_FoodPiece> _Boxes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);

        for (int32 Index = 0; Index < k_BoxCount; ++Index)
        {
            // A slice dressed from its food, as the station dresses the halves it cuts.
            const auto PileLocal = FTransform(FRotator::ZeroRotator, FVector(10.0 * (Index - 1), 0.0, 0.0)) * utils_cutting::Get_PileLocal();
            const auto Slice = mars::Food_MushroomSlice_Mars.Build_Joint(ck::TransientEntity(), PileLocal * FTransform(FRotator::ZeroRotator, k_Origin));
            Track_ForCleanup(Slice);
            _Boxes.Add(Slice);
        }

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("every slice is Ready", n"Check_BoxesReady", 0, 10.0f);
        Add_Step("place the three slices on the board", n"Step_PlaceOnBoard");
        Add_Step_WaitUntil("the board holds the three slices", n"Check_BoardFilled", 0, 5.0f);
        Add_Step_WaitFrames("the placed poses have landed", 2);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step("move the hand over the slices' shared centre and chop", n"Step_AimAndChop");
        Add_Step_WaitUntil("the chop landed and every slice was cut", n"Check_AllCut", 0, 5.0f);
        Add_Step("three straddled, three cut", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_BoxesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllReady = true;
        for (const auto& Box : _Boxes)
        { AllReady = AllReady && Box.Get_Status() == EMars_FoodPiece_Status::Ready; }

        auto Res = OutResult;
        Res.Set(AllReady);
    }

    UFUNCTION()
    private void Step_PlaceOnBoard(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Box : _Boxes)
        {
            Watch(Box);
            _Board.Request_Place(FMars_Request_FoodBoard_Place(Box));
        }
    }

    UFUNCTION()
    private void Check_BoardFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == k_BoxCount);
    }

    UFUNCTION()
    private void Step_AimAndChop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto StationWorld = Get_StationWorld();
        auto Lateral = 0.0;
        for (const auto& Box : _Boxes)
        { Lateral += StationWorld.InverseTransformPosition(Get_WorldCentroid(Box)).Y; }

        MoveHandTo(float32(Lateral / k_BoxCount));
        Chop();
    }

    UFUNCTION()
    private void Check_AllCut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_Issues.Num() > 0 && _Issues[0].Issued < k_BoxCount) || _PieceCuts >= k_BoxCount);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChopsLanded, 1, "one chop landed");
        Assert_Equals_Int(_Issues.Num(), 1, "the board answered the chop once");
        if (_Issues.Num() == 1)
        {
            Assert_Equals_Int(_Issues[0].Straddling, k_BoxCount, "the blade straddled every slice");
            Assert_Equals_Int(_Issues[0].Budget, utils_foodboard::k_MaxCutsPerChop, "the budget is the station's MaxCutsPerChop");
            Assert_Equals_Int(_Issues[0].Issued, k_BoxCount, "a cut was issued for every slice");
        }

        Assert_Equals_Int(_PieceCuts, k_BoxCount, "every slice was cut");
        for (const auto& Box : _Boxes)
        { Assert_Equals_Int(Get_OutcomeCount(Box, EMars_FoodPiece_CutOutcome::Cut), 1, f"slice [{Box.ToString()}] was cut once"); }

        Assert_Equals_Int(_Board.Get_HeldCount(), k_BoxCount * 2, "the board holds the six halves");
    }
}
