// A chop cuts every piece it straddles, not the few a small budget allowed. Three whole tentacles (meat joints, the bench's
// own input: 29 cm long, 7.4 cm wide) lie on the station's board in a row along the board's depth (station X), the blade's
// face, 10 cm apart and laid as the feed lays them (their food's Layout yaw: the long axis along the cleaver's travel), all
// at one lateral position; the hand moves over their shared centroid and chops once. The board's answer names three
// straddling pieces and issues three cuts within a budget of the station's MaxCutsPerChop (8), and each tentacle is cut in
// two. Isolated origin (30000, -21000, -30000).
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
            // A whole joint of the bench's meat, as the feed builds it.
            const auto Joint = mars::Food_Tentacle_Mars.Build_Joint(ck::TransientEntity(), FTransform(FRotator::ZeroRotator, k_Origin + Get_PileOffset(Index)));
            Track_ForCleanup(Joint);
            _Boxes.Add(Joint);
        }

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 0);
        Add_Step_WaitUntil("every tentacle is Ready", n"Check_BoxesReady", k_SlowPolls, 0);
        Add_Step("place the three tentacles on the board", n"Step_PlaceOnBoard");
        Add_Step_WaitUntil("the board holds the three tentacles", n"Check_BoardFilled", 0, 0);
        Add_Step_WaitFrames("the placed poses have landed", 2);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 0);
        Add_Step("move the hand over the tentacles' shared centroid and chop", n"Step_AimAndChop");
        Add_Step_WaitUntil("the chop landed and every tentacle was cut", n"Check_AllCut", k_SlowPolls, 0);
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
        for (int32 Index = 0; Index < _Boxes.Num(); ++Index)
        {
            Watch(_Boxes[Index]);
            Pose_OnPile(_Boxes[Index], Get_PileOffset(Index), mars::Food_Tentacle_Mars.Layout.YawDegrees);
            _Board.Request_Place(FMars_Request_FoodBoard_Place(_Boxes[Index]));
        }
    }

    // In a row along the board's depth (the pile node's X), 10 cm apart.
    private FVector Get_PileOffset(int32 InIndex) const
    {
        return FVector(10.0 * (InIndex - 1), 0.0, 0.0);
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
            Assert_Equals_Int(_Issues[0].Straddling, k_BoxCount, "the blade straddled every tentacle");
            Assert_Equals_Int(_Issues[0].Budget, _Board.Get_Tuners().MaxCutsPerChop, "the budget is the station's MaxCutsPerChop");
            Assert_Equals_Int(_Issues[0].Issued, k_BoxCount, "a cut was issued for every tentacle");
        }

        Assert_Equals_Int(_PieceCuts, k_BoxCount, "every tentacle was cut");
        for (const auto& Box : _Boxes)
        { Assert_Equals_Int(Get_OutcomeCount(Box, EMars_FoodPiece_CutOutcome::Cut), 1, f"tentacle [{Box.ToString()}] was cut once"); }

        Assert_Equals_Int(_Board.Get_HeldCount(), k_BoxCount * 2, "the board holds the six halves");
    }
}
