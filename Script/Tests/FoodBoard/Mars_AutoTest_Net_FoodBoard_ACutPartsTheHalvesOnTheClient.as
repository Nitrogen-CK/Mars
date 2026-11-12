// The server places the slab and cuts it through the station root along world X; once the board is quiet it reports the
// two held pieces, parted 10 cm along world X. On the client both halves stand at the reported poses, 10 cm apart, each
// held by its board; the count and the occupancy read 2; the board's one answer is raised there (straddling 1, budget 2,
// issued 1) and the count changes 1 then 2.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_ACutPartsTheHalvesOnTheClient
class UCk_AutoTest_Net_FoodBoard_ACutPartsTheHalvesOnTheClient : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 201000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BoardRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            Await_ClientStep(1, n"OnClientStep1");
            return;
        }

        Begin_ServerBoardWithSlab(InHandle);
    }

    // How far apart along world X two pieces' roots are.
    private float64 Get_SpreadX(TArray<FCk_Handle_FoodPiece> InPieces)
    {
        if (InPieces.Num() != 2)
        { return 0.0; }

        return Math::Abs(Get_RootLocation(InPieces[0]).X - Get_RootLocation(InPieces[1]).X);
    }

    protected void On_ServerBoardReady() override
    {
        Place_Slab();
        WaitUntil(n"Is_ServerHoldsOne", n"OnServerHoldsOne", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHoldsOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Board.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void OnServerHoldsOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(Make_PlaneThroughRoot(FVector::ForwardVector)));
        Await_ServerQuiet(1, 0, n"OnServerQuiet");
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        const auto Held = _Board.Get_Held();
        const auto SpreadX = Get_SpreadX(Held);
        Assert_Equals_Int(Held.Num(), 2, "the server's board holds the two halves");
        Assert_True(Math::Abs(SpreadX - float64(constants_foodboard_net_autotest::k_SeparationCm)) <= constants_foodboard_net_autotest::k_ServerToleranceCm,
            f"the server's halves are 10 cm apart along world X (got {SpreadX})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"held={Held.Num()} spreadX={SpreadX}");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Standing = Get_StandingNear(_FloorTop);
        const auto Check = Check_AtReport();
        const auto SpreadX = Get_SpreadX(Standing);
        TArray<int32> Expected;
        Expected.Add(1);
        Expected.Add(2);
        Assert_Equals_Int(Standing.Num(), 2, "two pieces stand on the client");
        Assert_True(Get_IsAtReport(Check), f"the client's pieces stand at the report ({Describe_Check(Check)})");
        Assert_True(Math::Abs(SpreadX - float64(constants_foodboard_net_autotest::k_SeparationCm)) <= constants_foodboard_net_autotest::k_ReportToleranceCm,
            f"the client's pieces are 10 cm apart along world X (got {SpreadX})");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the client reads two held pieces");
        Assert_Equals_Int(_Board.Get_Occupancy(), 2, "the client reads an occupancy of two");
        Assert_True(_CutIssues.Num() == 1 && Get_IsIssue(_CutIssues[0], 1, 2, 1),
            f"the client raised one answer, S1/B2/I1 (got [{Describe_Issues()}])");
        Assert_True(Get_AreStandingHeldByBoard(), "each standing piece is held by the client's board");
        Assert_True(Get_AreHeldCounts(Expected), f"the client raised OnHeldCountChanged [1 2] (got [{Describe_HeldCounts()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"standing={Standing.Num()} {Describe_Check(Check)} spreadX={SpreadX} counts=[{Describe_HeldCounts()}] held={_Board.Get_HeldCount()} occupancy={_Board.Get_Occupancy()}");
        End_Client();
    }
}
