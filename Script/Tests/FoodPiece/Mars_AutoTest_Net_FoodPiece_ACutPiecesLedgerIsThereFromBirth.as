// The server sets a cook state on its resting whole meat slab and cuts it in the same drain. Inside its OnCutResolved, each
// half's replicated ledger carries the half's Id, ParentId and Lineage, recorded check numbers with triangles, the source's
// cook state and a cook serial of 1; the server reports the halves' ids and check numbers. On the client, each of the two
// piece scripts (not FoodPieces yet) has a ledger with the ids of its spawn data, that cook state and serial, and the
// server's check numbers for its side.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ACutPiecesLedgerIsThereFromBirth
class UCk_AutoTest_Net_FoodPiece_ACutPiecesLedgerIsThereFromBirth : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 165000.0;
    private const float32 k_ServerWatchSeconds = 4.0f;

    private FCk_Handle_FoodPiece _Source;
    private FGuid _SourceId;

    private FMars_FoodPiece_CookState Get_Cooked()
    {
        return Make_CookState(0.8f, 0.5f);
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientLedgersThere", n"OnClientLedgersThere", k_SlowPolls);
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
        _Source = _Rock.As_FoodPiece();
        _SourceId = _Source.Get_Id();
        _Source.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Get_Cooked()));
        Cut(_Source, Make_CentrePlane());
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
    }

    protected void On_CutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult) override
    {
        Assert_True(InResult.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the cut resolved Cut (got {InResult.Outcome :n})");
        if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        Assert_HalfLedger(InResult.Positive, "positive");
        Assert_HalfLedger(InResult.Negative, "negative");

        auto Report = Make_CutReport(InSource, InResult);
        const auto Positive = utils_foodpiece::TryGet_Ledger(InResult.Positive);
        const auto Negative = utils_foodpiece::TryGet_Ledger(InResult.Negative);
        if (Positive.IsSet())
        {
            Report.PositiveCheckVolumeCm3 = Positive.GetValue().CheckVolumeCm3;
            Report.PositiveCheckTriangles = Positive.GetValue().CheckTriangles;
        }

        if (Negative.IsSet())
        {
            Report.NegativeCheckVolumeCm3 = Negative.GetValue().CheckVolumeCm3;
            Report.NegativeCheckTriangles = Negative.GetValue().CheckTriangles;
        }

        Publish_PieceReport(Report);
    }

    private void Assert_HalfLedger(FCk_Handle_FoodPiece InHalf, FString InName)
    {
        const auto Ledger = utils_foodpiece::TryGet_Ledger(InHalf);
        Assert_True(Ledger.IsSet(), f"the {InName} half has a replicated ledger");
        if (Ledger.IsSet() == false)
        { return; }

        const auto Net = Ledger.GetValue();
        Assert_True(Net.Id == InHalf.Get_Id() && Net.Id.IsValid(), f"the {InName} half's ledger has its Id");
        Assert_True(Net.ParentId == _SourceId, f"the {InName} half's ledger names the source as parent");
        Assert_True(Net.Lineage == InHalf.Get_Lineage() && Net.Lineage.IsValid(), f"the {InName} half's ledger has its Lineage");
        Assert_True(Net.Check == EMars_FoodPiece_Check::Recorded, f"the {InName} half's check numbers are recorded");
        Assert_True(Net.CheckTriangles > 0, f"the {InName} half's ledger has triangles [{Net.CheckTriangles}]");
        Assert_True(Get_IsCookStateEqual(Net.CookState, Get_Cooked()), f"the {InName} half's ledger carries the source's cook state");
        Assert_Equals_Int(Net.CookSerial, 1, f"the {InName} half's cook serial is 1");
    }

    UFUNCTION()
    private void Is_ServerCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void OnServerCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        Assert_Equals_Int(_Cuts.Num(), 1, "one OnCutResolved");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"cuts={_Cuts.Num()} triangles={Report.PositiveCheckTriangles},{Report.NegativeCheckTriangles} volumes={Report.PositiveCheckVolumeCm3},{Report.NegativeCheckVolumeCm3}");
        WaitSeconds(2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    // Two piece scripts whose ledgers carry an identity and recorded check numbers, and the server's report.
    UFUNCTION()
    private void Is_ClientLedgersThere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Pieces = Get_PieceEntitiesNear(_FloorTop);
        if (Pieces.Num() != 2 || Get_PieceReport().Serial < 1)
        {
            Result.Set(false);
            return;
        }

        for (const auto& Piece : Pieces)
        {
            const auto Ledger = utils_foodpiece::TryGet_Ledger(Piece);
            if (Ledger.IsSet() == false || Ledger.GetValue().Id.IsValid() == false || Ledger.GetValue().Check != EMars_FoodPiece_Check::Recorded)
            {
                Result.Set(false);
                return;
            }
        }

        Result.Set(true);
    }

    UFUNCTION()
    private void OnClientLedgersThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Pieces = Get_PieceEntitiesNear(_FloorTop);
        const auto Report = Get_PieceReport();
        const auto Positive = Find_ByKept(Pieces, EMars_FoodPiece_CutSide::Positive);
        const auto Negative = Find_ByKept(Pieces, EMars_FoodPiece_CutSide::Negative);
        Assert_True(ck::IsValid(Positive) && ck::IsValid(Negative), "one piece script per side");
        if (ck::IsValid(Positive))
        { Assert_ClientLedger(Positive, Report.PositiveCheckVolumeCm3, Report.PositiveCheckTriangles, "positive"); }

        if (ck::IsValid(Negative))
        { Assert_ClientLedger(Negative, Report.NegativeCheckVolumeCm3, Report.NegativeCheckTriangles, "negative"); }

        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Pieces.Num()} serial={Report.Serial}");
        End_Client();
    }

    private void Assert_ClientLedger(FCk_Handle InPiece, float InVolumeCm3, int32 InTriangles, FString InName)
    {
        const auto Net = utils_foodpiece::TryGet_Ledger(InPiece).GetValue();
        const auto Replay = utils_foodpiece::TryGet_Replay(InPiece);
        Assert_True(Replay.IsSet(), f"the client's {InName} piece kept its spawn data");
        if (Replay.IsSet())
        {
            const auto Data = Replay.GetValue().Piece.Data;
            Assert_True(Net.Id == Data.Id, f"the client's {InName} ledger has the Id of its spawn data");
            Assert_True(Net.ParentId == Data.ParentId, f"the client's {InName} ledger has the ParentId of its spawn data");
            Assert_True(Net.Lineage == Data.Lineage, f"the client's {InName} ledger has the Lineage of its spawn data");
        }

        Assert_True(Get_IsCookStateEqual(Net.CookState, Get_Cooked()), f"the client's {InName} ledger carries the cook state");
        Assert_Equals_Int(Net.CookSerial, 1, f"the client's {InName} cook serial is 1");
        Assert_True(Net.CheckVolumeCm3 == InVolumeCm3, f"the client's {InName} check volume [{Net.CheckVolumeCm3}] is the server's [{InVolumeCm3}]");
        Assert_Equals_Int(Net.CheckTriangles, InTriangles, f"the client's {InName} check triangles are the server's");
        Log(f"[FoodPieceNetCheck] {GetClass().GetName()} client {InName}: volume={Net.CheckVolumeCm3} server={InVolumeCm3} triangles={Net.CheckTriangles} server={InTriangles} boundsMin={Net.CheckBoundsMinCm} boundsMax={Net.CheckBoundsMaxCm}");
    }
}
