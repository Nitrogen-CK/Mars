// The server places the slab and seats the subject. The client, once it reads the subject operating, chops through
// utils_cutting::Request_ChopFor with an aim of 0: on the server the cleaver starts and lands once and the landing cuts the
// slab through the station root, the board answering with one cut issued. On the client the cleaver raises one start and
// one landing, the board raises that one answer, and the two halves stand at the server's report.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_AClientsChopCutsTheFoodOnTheBoard
class UCk_AutoTest_Net_FoodBoard_AClientsChopCutsTheFoodOnTheBoard : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 210000.0;

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
        Publish_BoardReport(1);
        Await_ServerQuiet(1, 0, n"OnServerQuiet");
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(2);
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
        WaitUntil(n"Is_BoardRigSubjectOperating", n"OnClientSeesOperator", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSeesOperator(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Cutting = Get_Cutting();
        utils_cutting::Request_ChopFor(Cutting, Get_SubjectEntity(), 0.0f);
        Await_ClientStep(2, n"OnClientStep2");
    }

    UFUNCTION()
    private void OnClientStep2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Standing = Get_StandingNear(_FloorTop);
        const auto Check = Check_AtReport();
        Assert_True(Get_IsOneChop(), f"the client's cleaver raised one start then one landing (got [{Describe_Events()}])");
        Assert_True(Get_IsOneAnswer(1), f"the client raised one answer, with one cut issued (got [{Describe_Issues()}])");
        Assert_Equals_Int(Standing.Num(), 2, "two pieces stand on the client");
        Assert_True(Get_IsAtReport(Check), f"the client's pieces stand at the report ({Describe_Check(Check)})");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the client's count is 2");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"standing={Standing.Num()} {Describe_Check(Check)} issues=[{Describe_Issues()}] held={_Board.Get_HeldCount()}");
        End_Client();
    }
}
