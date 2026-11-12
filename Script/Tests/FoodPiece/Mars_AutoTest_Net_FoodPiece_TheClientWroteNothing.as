// The client asks its Ready copy of a whole meat slab for a cut and a cook state with every sear at 1. Its OnCutResolved
// fires once, RefusedNoAuthority; its piece stays Ready and uncut with a raw cook state and no slice in flight, and no piece
// script appears near the test's X on either machine. The server's slab is still one whole Ready piece, raw.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheClientWroteNothing
class UCk_AutoTest_Net_FoodPiece_TheClientWroteNothing : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 156000.0;
    private const float32 k_ClientSettleSeconds = 1.5f;
    // Long enough for the client's requests to have reached the server, had anything crossed.
    private const float32 k_ServerWatchSeconds = 4.0f;

    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientFoodReady", n"OnClientFoodReady", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSlab();
        WaitUntil(n"Is_ServerSlabStill", n"OnServerSlabStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Tick_SlabReadyAndStill());
    }

    UFUNCTION()
    private void OnServerSlabStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = _Rock.As_FoodPiece();
        Publish_PieceReport(Get_PieceReport());
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsWhole = Get_IsFoodReady(_Rock) && _Piece.Get_IsWhole() && _Piece.Get_IsCutting() == false;
        Assert_True(IsWhole, "the server's slab is still one whole Ready piece");
        if (IsWhole)
        { Assert_True(Get_IsCookStateZero(_Piece.Get_CookState()), "the server's slab is still raw"); }

        Assert_Equals_Int(Get_PieceEntitiesNear(_FloorTop).Num(), 0, "no piece script near the test's X on the server");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"whole={IsWhole} pieces={Get_PieceEntitiesNear(_FloorTop).Num()}");
        WaitSeconds(2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientFoodReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto WorldItem = Find_WorldItemNear(_FloorTop);
        FCk_Handle Entity = WorldItem;
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(Entity) && Get_PieceReport().Serial >= 1);
    }

    UFUNCTION()
    private void OnClientFoodReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Entity = Find_WorldItemNear(_FloorTop);
        _Piece = Entity.As_FoodPiece();

        auto Seared = FMars_FoodPiece_CookState();
        for (int32 Index = 0; Index < Seared.Sear.Num(); ++Index)
        { Seared.Sear[Index] = 1.0f; }

        _Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Seared));
        Cut(_Piece, Make_CentrePlane());
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Cuts.Num(), 1, "the client's OnCutResolved fired once");
        if (_Cuts.Num() > 0)
        { Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::RefusedNoAuthority, f"the client's cut is RefusedNoAuthority (got {_Cuts[0].Outcome :n})"); }

        Assert_True(_Piece.Get_Status() == EMars_FoodPiece_Status::Ready, "the client's piece is Ready");
        Assert_False(_Piece.Get_IsCutting(), "the client's piece is not cutting");
        Assert_True(Get_IsCookStateZero(_Piece.Get_CookState()), "the client's piece is still raw");
        Assert_False(utils_foodpiece::Get_HasPendingCut(ck::TransientEntity(), _Piece), "no slice of the client's piece is in flight");
        Assert_Equals_Int(Get_PieceEntitiesNear(_FloorTop).Num(), 0, "no piece script near the test's X on the client");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        const auto Outcome = _Cuts.Num() > 0 ? _Cuts[0].Outcome : EMars_FoodPiece_CutOutcome::Failed;
        Log_Result(f"resolutions={_Cuts.Num()} outcome={Outcome :n} raw={Get_IsCookStateZero(_Piece.Get_CookState())}");
        End_Client();
    }
}
