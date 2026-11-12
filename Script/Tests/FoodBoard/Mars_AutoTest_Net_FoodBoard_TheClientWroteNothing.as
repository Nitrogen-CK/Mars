// The server places the slab, reports, and watches 6 s. Once the report arrives the client asks its own copy of the board
// for a cut, a turn, a sweep and a place of its whole food: 1.5 s later its ledger is as it was, it raised only the
// count's one change, its whole food is not cutting, has no board and no holder of its own and has not moved, no piece
// script exists and it sliced nothing. The server's board still holds the whole, unmoved slab and answered nothing.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_TheClientWroteNothing
class UCk_AutoTest_Net_FoodBoard_TheClientWroteNothing : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 209000.0;
    private const float32 k_ServerWatchSeconds = 6.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    private FVector _PlacedAt;
    private FMars_Fragment_FoodBoard_Net _LedgerAtStep1;
    private int32 _SlicesAtStep1 = 0;
    private FCk_Handle_FoodPiece _Food;

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

    private TArray<int32> Get_OneCount() const
    {
        TArray<int32> Expected;
        Expected.Add(1);
        return Expected;
    }

    protected void On_ServerBoardReady() override
    {
        Place_SlabThen(n"OnServerHoldsOne");
    }

    UFUNCTION()
    private void OnServerHoldsOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PlacedAt = Get_RootLocation(_Rock);
        Publish_BoardReport(1);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Board.Get_Ledger();
        const auto Slab = _Rock.As_FoodPiece();
        const auto MovedCm = (Get_RootLocation(_Rock) - _PlacedAt).Size();
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the server's board still holds the slab");
        Assert_True(Ledger.CutSerial == 0 && Ledger.TurnSerial == 0 && Ledger.ReleaseRefusalSerial == 0,
            f"the server's ledger answered nothing ({Describe_Ledger(Ledger)})");
        Assert_True(Slab.Get_IsWhole() && Slab.Get_Status() == EMars_FoodPiece_Status::Ready, "the slab is whole and Ready");
        Assert_True(MovedCm <= constants_foodboard_net_autotest::k_ServerToleranceCm, f"the slab is where it was placed (moved {MovedCm} cm)");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::PieceCut), 0, "the server cut no piece");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::Turned), 0, "the server turned nothing");
        Assert_True(Get_AreHeldCounts(Get_OneCount()), f"the server raised OnHeldCountChanged [1] (got [{Describe_HeldCounts()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"ledger {Describe_Ledger(Ledger)} moved={MovedCm} counts=[{Describe_HeldCounts()}]");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LedgerAtStep1 = _Board.Get_Ledger();
        _SlicesAtStep1 = Get_Tally().Slices;
        _Food = Find_FoodPieceNear(_FloorTop);
        if (ck::Is_NOT_Valid(_Food))
        {
            FinishFailure("the client found no whole food at step 1");
            return;
        }

        _PlacedAt = Get_RootLocation(_Food);
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(Make_PlaneThroughRoot(FVector::ForwardVector)));
        _Board.Request_Turn(FMars_Request_FoodBoard_Turn(90.0f));
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>()));
        _Board.Request_Place(FMars_Request_FoodBoard_Place(_Food));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Board.Get_Ledger();
        const auto MovedCm = (Get_RootLocation(_Food) - _PlacedAt).Size();
        const auto Slices = Get_Tally().Slices;
        const auto PieceScripts = Get_PieceEntitiesNear(_FloorTop).Num();
        Assert_True(Get_IsLedgerEqual(Ledger, _LedgerAtStep1), f"the client's ledger is unchanged ({Describe_Ledger(_LedgerAtStep1)} -> {Describe_Ledger(Ledger)})");
        Assert_True(_Events.Num() == 1 && Get_AreHeldCounts(Get_OneCount()), f"the client raised only OnHeldCountChanged [1] (got [{Describe_Events()}])");
        Assert_Equals_Int(_Board.Get_Held().Num(), 0, "the client's held list is empty");
        Assert_False(_Food.Get_IsCutting(), "the client's whole food is not cutting");
        Assert_True(ck::Is_NOT_Valid(_Food.TryGet_FoodBoard()), "the client's whole food has no board");
        Assert_True(ck::Is_NOT_Valid(_Food.TryGet_Holder()), "the client's whole food has no local holder");
        Assert_True(MovedCm <= constants_foodboard_net_autotest::k_ServerToleranceCm, f"the client's whole food has not moved (moved {MovedCm} cm)");
        Assert_Equals_Int(PieceScripts, 0, "no piece script is near the test's X");
        Assert_Equals_Int(Slices, _SlicesAtStep1, "the client submitted no slice");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"ledger {Describe_Ledger(Ledger)} moved={MovedCm} slices={_SlicesAtStep1}->{Slices} pieceScripts={PieceScripts}");
        End_Client();
    }
}
