// The server cuts a whole meat slab through its centre (normal +X), then the negative half at x = -9 (normal +X), then
// the negative half of that at z = 6 (normal +Z), and reports the id of the piece the third cut was made on. On the client
// the two deepest piece scripts each hold three cuts, those planes in that order, the first two kept negative and the
// third one positive and one negative, and their parent is the reported piece.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheRecipeGrowsOneCutAGeneration
class UCk_AutoTest_Net_FoodPiece_TheRecipeGrowsOneCutAGeneration : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 152000.0;

    private int32 _CutsIssued = 0;
    // The piece the last cut was made on.
    private FGuid _LastSourceId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientDeepestThere", n"OnClientDeepestThere", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private FCk_RuntimeMesh_PlaneLocal Get_Plane(int32 InGeneration)
    {
        if (InGeneration == 0)
        { return Make_CentrePlane(); }

        if (InGeneration == 1)
        { return Make_Plane(FVector(-9.0, 0.0, 0.0), FVector::ForwardVector, FVector::RightVector); }

        return Make_Plane(FVector(0.0, 0.0, 6.0), FVector::UpVector, FVector::ForwardVector);
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
        Issue_Cut(_Rock.As_FoodPiece());
    }

    private void Issue_Cut(FCk_Handle_FoodPiece InPiece)
    {
        _LastSourceId = InPiece.Get_Id();
        Cut(InPiece, Get_Plane(_CutsIssued));
        ++_CutsIssued;
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() >= _CutsIssued);
    }

    UFUNCTION()
    private void OnServerCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Last = _Cuts.Last();
        Assert_True(Last.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"cut {_CutsIssued} resolved Cut (got {Last.Outcome :n})");
        if (Last.Outcome != EMars_FoodPiece_CutOutcome::Cut || _CutsIssued == 3)
        {
            auto Report = Get_PieceReport();
            Report.DeepParentId = _LastSourceId;
            Publish_PieceReport(Report);
            Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
            Log_Result(f"cuts={_Cuts.Num()} lastOutcome={Last.Outcome :n}");
            WaitSeconds(3.0f, n"OnServerHeld");
            return;
        }

        Issue_Cut(Last.Negative);
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    private TArray<FCk_Handle> Get_Deepest()
    {
        TArray<FCk_Handle> Deepest;
        for (const auto& Piece : Get_PieceEntitiesNear(_FloorTop))
        {
            const auto Replay = utils_foodpiece::TryGet_Replay(Piece);
            if (Replay.IsSet() && Replay.GetValue().Piece.Data.Recipe.Cuts.Num() == 3)
            { Deepest.Add(Piece); }
        }

        return Deepest;
    }

    UFUNCTION()
    private void Is_ClientDeepestThere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Deepest().Num() == 2 && Get_PieceReport().Serial >= 1);
    }

    UFUNCTION()
    private void OnClientDeepestThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        const auto Deepest = Get_Deepest();
        auto LastPositive = 0;
        auto Ordered = 0;
        for (const auto& Piece : Deepest)
        {
            const auto Data = utils_foodpiece::TryGet_Replay(Piece).GetValue().Piece.Data;
            auto InOrder = true;
            for (int32 Index = 0; Index < 3; ++Index)
            { InOrder = InOrder && Get_IsPlaneEqual(Data.Recipe.Cuts[Index].Plane, Get_Plane(Index)); }

            Assert_True(InOrder, "the three planes are the server's, in order");
            Assert_True(Data.Recipe.Cuts[0].Kept == EMars_FoodPiece_CutSide::Negative, "the first cut kept the negative side");
            Assert_True(Data.Recipe.Cuts[1].Kept == EMars_FoodPiece_CutSide::Negative, "the second cut kept the negative side");
            Assert_True(Data.ParentId == Report.DeepParentId, "the deepest piece's parent is the piece the third cut was made on");
            LastPositive += Data.Recipe.Cuts[2].Kept == EMars_FoodPiece_CutSide::Positive ? 1 : 0;
            Ordered += InOrder ? 1 : 0;
        }

        Assert_Equals_Int(LastPositive, 1, "one deepest piece kept the third cut's positive side, the other its negative");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"deepest={Deepest.Num()} ordered={Ordered} lastPositive={LastPositive}");
        End_Client();
    }
}
