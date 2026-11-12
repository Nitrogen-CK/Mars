// The server cuts the meat slab, then every frame cuts every Ready, uncut piece of its lineage that has fewer than four
// cuts at the middle of its local X bounds (normal +X), until sixteen leaves of four cuts exist. The client ends with
// sixteen Ready pieces with four-cut recipes, all matching the authority's geometry, rebuilt with at most fifteen slices
// (one per cut of the lineage) and no failure. The client logs its frames from the first piece entity to the sixteenth leaf.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ALineageIsRebuiltOnceThroughTheMemo
class UCk_AutoTest_Net_FoodPiece_ALineageIsRebuiltOnceThroughTheMemo : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 173000.0;
    private const int32 k_Generations = 4;
    private const int32 k_Leaves = 16;
    private const float32 k_ServerWatchSeconds = 6.0f;

    private int32 _ServerCutsIssued = 0;
    // Every piece the server asked to cut: a request waits for the next drain, so a piece is asked once.
    private TArray<FGuid> _Asked;
    private int32 _ClientFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientLeavesBuilt", n"OnClientLeavesBuilt", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    protected void On_ServerSlabStill() override
    {
        auto Slab = _Rock.As_FoodPiece();
        Cut(Slab, Make_MiddlePlane(Slab, 0));
        ++_ServerCutsIssued;
        WaitUntil(n"Is_ServerLeavesCut", n"OnServerLeavesCut", k_SlowPolls);
    }

    // Once per frame: cuts every piece that still owes a cut; true once the leaves exist, or a cut did not commit.
    UFUNCTION()
    private void Is_ServerLeavesCut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (_Cuts.Num() > Get_CutCount(EMars_FoodPiece_CutOutcome::Cut))
        {
            Result.Set(true);
            return;
        }

        auto Leaves = 0;
        for (auto Piece : Get_ReadyPiecesNear(_FloorTop))
        {
            const auto Cuts = Piece.Get_Recipe().Cuts.Num();
            if (Cuts >= k_Generations)
            {
                ++Leaves;
                continue;
            }

            if (Piece.Get_IsCutting() == false && _Asked.Contains(Piece.Get_Id()) == false)
            {
                _Asked.Add(Piece.Get_Id());
                Cut(Piece, Make_MiddlePlane(Piece, 0));
                ++_ServerCutsIssued;
            }
        }

        Result.Set(Leaves == k_Leaves);
    }

    UFUNCTION()
    private void OnServerLeavesCut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Report = Get_PieceReport();
        Report.LeafCount = Get_ReadyPieceCountNear(_FloorTop);
        Publish_PieceReport(Report);

        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut), k_Leaves - 1, "fifteen cuts committed");
        Assert_Equals_Int(_Cuts.Num(), k_Leaves - 1, "every cut committed");
        Assert_Equals_Int(Report.LeafCount, k_Leaves, "sixteen leaves on the server");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"issued={_ServerCutsIssued} resolved={_Cuts.Num()} committed={Get_CutCount(EMars_FoodPiece_CutOutcome::Cut)} leaves={Report.LeafCount} {Describe_Tally()}");
        WaitSeconds(k_ServerWatchSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    // Once per frame: counts the frames since the first piece entity arrived.
    UFUNCTION()
    private void Is_ClientLeavesBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_ClientFrames > 0 || Get_PieceEntitiesNear(_FloorTop).Num() > 0)
        { ++_ClientFrames; }

        auto Leaves = 0;
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        for (const auto& Piece : Pieces)
        {
            if (Piece.Get_Recipe().Cuts.Num() == k_Generations)
            { ++Leaves; }
        }

        auto Result = OutResult;
        Result.Set(Leaves == k_Leaves && Get_AreChecked(Pieces));
    }

    UFUNCTION()
    private void OnClientLeavesBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        auto FourCuts = 0;
        for (const auto& Piece : Pieces)
        {
            if (Piece.Get_Recipe().Cuts.Num() == k_Generations)
            { ++FourCuts; }
        }

        const auto Matches = Get_CheckCount(Pieces, EMars_FoodPiece_CheckResult::Matches);
        Assert_Equals_Int(FourCuts, k_Leaves, "sixteen Ready pieces with four-cut recipes");
        Assert_Equals_Int(Matches, Pieces.Num(), "every Ready piece matches the authority");

        const auto Tally = Get_Tally();
        Assert_True(Tally.Slices <= k_Leaves - 1, f"at most fifteen replay slices (got {Tally.Slices})");
        Assert_Equals_Int(Tally.Failed, 0, "no replay failed");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"leaves={FourCuts} ready={Pieces.Num()} matches={Matches} frames={_ClientFrames} {Describe_Tally()}");
        End_Client();
    }
}
