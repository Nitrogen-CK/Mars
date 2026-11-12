// The server places the slab and cuts it through the station root along world X, then along world Y: four pieces fill the
// board. A third cut through the first piece answers with no budget and issues nothing. On the client the four pieces
// stand at the report, the count reads 4 and the occupancy the board's limit, and the three answers are raised there, the
// third with no budget.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_AFullBoardOnlyKnocksOnTheClient
class UCk_AutoTest_Net_FoodBoard_AFullBoardOnlyKnocksOnTheClient : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 203000.0;

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

    // The third answer knocks: something straddles, but the board has no room for a half.
    private bool Get_IsKnock(FMars_FoodBoard_CutIssue InIssue)
    {
        return InIssue.Budget == 0 && InIssue.Issued == 0 && InIssue.Straddling >= 1;
    }

    protected void On_ServerBoardReady() override
    {
        Place_SlabThen(n"OnServerHoldsOne");
    }

    UFUNCTION()
    private void OnServerHoldsOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(Make_PlaneThroughRoot(FVector::ForwardVector)));
        Await_ServerQuiet(1, 0, n"OnServerFirstQuiet");
    }

    UFUNCTION()
    private void OnServerFirstQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(Make_PlaneThroughRoot(FVector::RightVector)));
        Await_ServerQuiet(2, 0, n"OnServerSecondQuiet");
    }

    UFUNCTION()
    private void OnServerSecondQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Held = _Board.Get_Held();
        Assert_Equals_Int(Held.Num(), 4, "two cuts fill the server's board with four pieces");
        if (Held.Num() == 0)
        {
            End_ServerAfterReport();
            return;
        }

        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(Make_VerticalPlane(Get_WorldBoundsCenter(Held[0]), FVector::ForwardVector)));
        Await_ServerQuiet(3, 0, n"OnServerThirdQuiet");
    }

    UFUNCTION()
    private void OnServerThirdQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        Assert_True(_CutIssues.Num() == 3 && Get_IsKnock(_CutIssues[2]), f"the server's third answer is a knock (got [{Describe_Issues()}])");
        Assert_Equals_Int(_Board.Get_HeldCount(), 4, "the server's board still holds four");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"answers=[{Describe_Issues()}] held={_Board.Get_HeldCount()}");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Standing = Get_StandingNear(_FloorTop);
        const auto Check = Check_AtReport();
        Assert_Equals_Int(Standing.Num(), 4, "four pieces stand on the client");
        Assert_True(Get_IsAtReport(Check), f"the client's pieces stand at the report ({Describe_Check(Check)})");
        Assert_Equals_Int(_Board.Get_HeldCount(), 4, "the client reads four held pieces");
        Assert_True(_Board.Get_Occupancy() >= _Board.Get_Tuners().MaxHeldPieces, f"the client reads a full board (occupancy {_Board.Get_Occupancy()})");
        Assert_True(_CutIssues.Num() == 3 && Get_IsKnock(_CutIssues[2]), f"the client raised three answers, the third a knock (got [{Describe_Issues()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"standing={Standing.Num()} {Describe_Check(Check)} answers=[{Describe_Issues()}] held={_Board.Get_HeldCount()} occupancy={_Board.Get_Occupancy()}");
        End_Client();
    }
}
