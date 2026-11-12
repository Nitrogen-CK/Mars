// The server places the slab, seats the subject and enqueues two chops with an aim of 0 in one frame, as two chop cues
// reaching it together would: only the first chop of a drain starts, so the cleaver starts and lands once, the board
// answers once and holds two halves. The client raises one start, one landing and one answer, and the two halves stand at
// the report.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_TwoChopsThatArriveTogetherChopOnce
class UCk_AutoTest_Net_FoodBoard_TwoChopsThatArriveTogetherChopOnce : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 213000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BoardRig(InHandle, k_X);
        Begin_OperatorRig();
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
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Cutting = Get_Cutting();
        Cutting.Request_Chop(FMars_Request_Cutting_Chop(0.0f));
        Cutting.Request_Chop(FMars_Request_Cutting_Chop(0.0f));
        WaitSeconds(constants_foodboard_net_autotest::k_StepSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        Assert_True(Get_IsOneChop(), f"the server's cleaver started and landed once (got [{Describe_Events()}])");
        Assert_True(Get_IsOneAnswer(1), f"the server answered once, with one cut issued (got [{Describe_Issues()}])");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the server's board holds the two halves");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"issues=[{Describe_Issues()}] held={_Board.Get_HeldCount()}");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Standing = Get_StandingNear(_FloorTop);
        const auto Check = Check_AtReport();
        Assert_True(Get_IsOneChop(), f"the client's cleaver raised one start then one landing (got [{Describe_Events()}])");
        Assert_Equals_Int(_CutIssues.Num(), 1, "the client raised one answer");
        Assert_Equals_Int(Standing.Num(), 2, "two pieces stand on the client");
        Assert_True(Get_IsAtReport(Check), f"the client's pieces stand at the report ({Describe_Check(Check)})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"standing={Standing.Num()} {Describe_Check(Check)} issues=[{Describe_Issues()}]");
        End_Client();
    }
}
