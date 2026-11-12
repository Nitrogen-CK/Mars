// The server spawns a whole meat slab and reports its piece's Id and Lineage once it is Ready. On the client, every frame
// from its copy becoming a FoodPiece, that copy's Id is invalid or the server's; within 3 s of becoming a FoodPiece its Id
// and Lineage are the server's, its ParentId is invalid and it is whole.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_AWholeFoodsIdentityReachesTheClient
class UCk_AutoTest_Net_FoodPiece_AWholeFoodsIdentityReachesTheClient : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 160000.0;
    private const float64 k_ConvergeSeconds = 3.0;
    private const float32 k_ServerWatchSeconds = 6.0f;

    private FCk_Handle_FoodPiece _Piece;
    private TOptional<float64> _ComposedAt;
    private TArray<FGuid> _SeenIds;
    private float64 _Elapsed = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientIdentityThere", n"OnClientIdentityThere", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSlab();
        WaitUntil(n"Is_ServerSlabReady", n"OnServerSlabReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_Rock));
    }

    UFUNCTION()
    private void OnServerSlabReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = _Rock.As_FoodPiece();
        auto Report = Get_PieceReport();
        Report.SourceId = _Piece.Get_Id();
        Report.Lineage = _Piece.Get_Lineage();
        Publish_PieceReport(Report);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = utils_foodpiece::TryGet_Ledger(_Piece);
        Assert_True(Ledger.IsSet(), "the server's piece has a replicated ledger");
        if (Ledger.IsSet())
        { Assert_True(Ledger.GetValue().Id == _Piece.Get_Id() && Ledger.GetValue().Lineage == _Piece.Get_Lineage(), "the ledger carries the piece's identity"); }

        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"id={_Piece.Get_Id().ToString(EGuidFormats::Short)} ledger={Ledger.IsSet()}");
        WaitSeconds(2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    // Every frame from the copy becoming a FoodPiece: the Ids it read; done once it reads the server's identity, or once
    // the convergence time has passed.
    UFUNCTION()
    private void Is_ClientIdentityThere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _Piece = Find_FoodPieceNear(_FloorTop);
        if (ck::Is_NOT_Valid(_Piece))
        {
            Result.Set(false);
            return;
        }

        if (_ComposedAt.IsSet() == false)
        { _ComposedAt = TOptional<float64>(Get_Now()); }

        _Elapsed = Get_Now() - _ComposedAt.GetValue();
        const auto Id = _Piece.Get_Id();
        if (Id.IsValid() && _SeenIds.Contains(Id) == false)
        { _SeenIds.Add(Id); }

        const auto Report = Get_PieceReport();
        const auto Converged = Report.Serial >= 1 && Id == Report.SourceId && _Piece.Get_Lineage() == Report.Lineage;
        Result.Set(Converged || _Elapsed > k_ConvergeSeconds);
    }

    UFUNCTION()
    private void OnClientIdentityThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        Assert_True(Report.Serial >= 1, "the server's report arrived");
        Assert_True(_Piece.Get_Id() == Report.SourceId, f"the client's Id [{_Piece.Get_Id().ToString(EGuidFormats::Short)}] is the server's [{Report.SourceId.ToString(EGuidFormats::Short)}] within {k_ConvergeSeconds} s");
        Assert_True(_Piece.Get_Lineage() == Report.Lineage, "the client's Lineage is the server's");
        Assert_Equals_Int(_SeenIds.Num(), 1, "the client's copy never read a valid Id other than the server's");
        Assert_False(_Piece.Get_ParentId().IsValid(), "the client's copy has no parent");
        Assert_True(_Piece.Get_IsWhole(), "the client's copy is whole");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"id={_Piece.Get_Id().ToString(EGuidFormats::Short)} server={Report.SourceId.ToString(EGuidFormats::Short)} seen={_SeenIds.Num()} elapsed={_Elapsed}");
        End_Client();
    }
}
