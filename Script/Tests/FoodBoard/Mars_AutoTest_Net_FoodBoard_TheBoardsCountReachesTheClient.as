// The server places the Kinematic slab on its board, reports, and 1.5 s later sweeps it off with no cap and no tray. The
// client reads the count and the occupancy from the ledger (1, then 0), reads its whole food held by its board and then
// free, reads no held list, and raises OnHeldCountChanged 1 then 0, as the server does.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_TheBoardsCountReachesTheClient
class UCk_AutoTest_Net_FoodBoard_TheBoardsCountReachesTheClient : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 200000.0;

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
        Publish_BoardReport(1);
        WaitSeconds(constants_foodboard_net_autotest::k_StepSeconds, n"OnServerRelease");
    }

    UFUNCTION()
    private void OnServerRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>()));
        WaitUntil(n"Is_ServerHoldsNone", n"OnServerHoldsNone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHoldsNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Board.Get_HeldCount() == 0);
    }

    UFUNCTION()
    private void OnServerHoldsNone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(2);
        TArray<int32> Expected;
        Expected.Add(1);
        Expected.Add(0);
        Assert_True(Get_AreHeldCounts(Expected), f"the server raised OnHeldCountChanged [1 0] (got [{Describe_HeldCounts()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"counts=[{Describe_HeldCounts()}] motion={Get_SlabMotionType() :n}");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle BoardEntity = _Board;
        const auto Food = Find_FoodPieceNear(_FloorTop);
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "step 1: the client reads one held piece");
        Assert_Equals_Int(_Board.Get_Occupancy(), 1, "step 1: the client reads an occupancy of one");
        Assert_True(ck::IsValid(Food) && Food.TryGet_ReplicatedHolder() == BoardEntity, "step 1: the client's whole food is held by its board");
        Assert_Equals_Int(_Board.Get_Held().Num(), 0, "step 1: the client's held list is empty");
        Await_ClientStep(2, n"OnClientStep2");
    }

    UFUNCTION()
    private void OnClientStep2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Food = Find_FoodPieceNear(_FloorTop);
        TArray<int32> Expected;
        Expected.Add(1);
        Expected.Add(0);
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "step 2: the client reads no held piece");
        Assert_True(ck::IsValid(Food) && ck::Is_NOT_Valid(Food.TryGet_ReplicatedHolder()), "step 2: the client's whole food has no holder");
        Assert_True(Get_AreHeldCounts(Expected), f"the client raised OnHeldCountChanged [1 0] (got [{Describe_HeldCounts()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"counts=[{Describe_HeldCounts()}] held={_Board.Get_HeldCount()} occupancy={_Board.Get_Occupancy()}");
        End_Client();
    }
}
