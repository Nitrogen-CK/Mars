// The server places the slab and asks its board, in one frame, for a cut through the station root along world X and then
// a 90 degree turn: the board answers the cut, cuts the slab, then turns the halves. On the client the two halves stand at
// the report, the answer is raised before the turn, and the count reads 2.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_ACutAndATurnInOneFrame
class UCk_AutoTest_Net_FoodBoard_ACutAndATurnInOneFrame : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 206000.0;

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

    protected void On_ServerBoardReady() override
    {
        Place_SlabThen(n"OnServerHoldsOne");
    }

    UFUNCTION()
    private void OnServerHoldsOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(Make_PlaneThroughRoot(FVector::ForwardVector)));
        _Board.Request_Turn(FMars_Request_FoodBoard_Turn(90.0f));
        Await_ServerQuiet(1, 1, n"OnServerQuiet");
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        TArray<EMars_TESTONLY_NetBoardEvent> Kinds;
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::CutIssued);
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::PieceCut);
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::Turned);
        const auto Order = Get_EventsOf(Kinds);
        const auto IsOrdered = Order.Num() == 3 && Order[0] == EMars_TESTONLY_NetBoardEvent::CutIssued
            && Order[1] == EMars_TESTONLY_NetBoardEvent::PieceCut && Order[2] == EMars_TESTONLY_NetBoardEvent::Turned;
        Assert_True(IsOrdered, f"the server answered, cut one piece, then turned (got [{Describe_Events()}])");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the server's board holds the two halves");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"held={_Board.Get_HeldCount()}");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Standing = Get_StandingNear(_FloorTop);
        const auto Check = Check_AtReport();
        TArray<EMars_TESTONLY_NetBoardEvent> Kinds;
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::CutIssued);
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::Turned);
        const auto Order = Get_EventsOf(Kinds);
        const auto IsOrdered = Order.Num() == 2 && Order[0] == EMars_TESTONLY_NetBoardEvent::CutIssued
            && Order[1] == EMars_TESTONLY_NetBoardEvent::Turned;
        Assert_Equals_Int(Standing.Num(), 2, "two pieces stand on the client");
        Assert_True(Get_IsAtReport(Check), f"the client's pieces stand at the report ({Describe_Check(Check)})");
        Assert_True(IsOrdered, f"the client raised the answer, then the turn (got [{Describe_Events()}])");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the client reads two held pieces");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"standing={Standing.Num()} {Describe_Check(Check)} held={_Board.Get_HeldCount()}");
        End_Client();
    }
}
