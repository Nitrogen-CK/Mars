// The server places the slab, seats the subject and applies the seed; 10 frames later, in one frame, it enqueues a chop
// with an aim of 0 (what the chop cue enqueues on the authority) and applies a remote turn press. The board turns while the
// cleaver strikes, then the landing cuts: the server records the turn, then the landing, then one answer with one cut
// issued, and holds two halves. The client raises the turn, then the answer, and the two halves stand at the report.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_AChopAndATurnThatArriveTogether
class UCk_AutoTest_Net_FoodBoard_AChopAndATurnThatArriveTogether : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 212000.0;

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
        Seed_RemoteThen(n"OnServerSeeded");
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Cutting = Get_Cutting();
        Cutting.Request_Chop(FMars_Request_Cutting_Chop(0.0f));
        Press_RemoteTurn();
        Await_ServerQuiet(1, 1, n"OnServerQuiet");
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        TArray<EMars_TESTONLY_NetBoardEvent> Kinds;
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::Turned);
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::ChopLanded);
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::CutIssued);
        const auto Order = Get_EventsOf(Kinds);
        const auto IsOrdered = Order.Num() == 3 && Order[0] == EMars_TESTONLY_NetBoardEvent::Turned
            && Order[1] == EMars_TESTONLY_NetBoardEvent::ChopLanded && Order[2] == EMars_TESTONLY_NetBoardEvent::CutIssued;
        Assert_True(IsOrdered, f"the server turned, landed, then answered (got [{Describe_Events()}])");
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
        TArray<EMars_TESTONLY_NetBoardEvent> Kinds;
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::Turned);
        Kinds.Add(EMars_TESTONLY_NetBoardEvent::CutIssued);
        const auto Order = Get_EventsOf(Kinds);
        const auto IsOrdered = Order.Num() == 2 && Order[0] == EMars_TESTONLY_NetBoardEvent::Turned
            && Order[1] == EMars_TESTONLY_NetBoardEvent::CutIssued;
        Assert_True(IsOrdered, f"the client raised the turn, then the answer (got [{Describe_Events()}])");
        Assert_Equals_Int(Standing.Num(), 2, "two pieces stand on the client");
        Assert_True(Get_IsAtReport(Check), f"the client's pieces stand at the report ({Describe_Check(Check)})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"standing={Standing.Num()} {Describe_Check(Check)} held={_Board.Get_HeldCount()}");
        End_Client();
    }
}
