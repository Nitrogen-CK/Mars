// The server cuts a whole meat slab and reports the halves' ids and masses. On the client each of the two piece scripts
// keeps a replay spec whose recipe names the slab's definition id and holds one cut, its plane exactly the cut's (position,
// normal, tangent), one half keeping the positive side and the other the negative; its id, parent and lineage are the
// report's and its mass is the report's for its side, exactly.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheRecipeArrivesExact
class UCk_AutoTest_Net_FoodPiece_TheRecipeArrivesExact : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 151000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientRecipesThere", n"OnClientRecipesThere", k_SlowPolls);
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
        Cut(_Rock.As_FoodPiece(), Make_CentrePlane());
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
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
        Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the cut resolved Cut (got {_Cuts[0].Outcome :n})");
        if (_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut)
        { Publish_PieceReport(Make_CutReport(_CutSources[0], _Cuts[0])); }

        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"outcome={_Cuts[0].Outcome :n}");
        WaitSeconds(3.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientRecipesThere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Pieces = Get_PieceEntitiesNear(_FloorTop);
        auto AllKept = Pieces.Num() == 2;
        for (const auto& Piece : Pieces)
        { AllKept = AllKept && utils_foodpiece::TryGet_Replay(Piece).IsSet(); }

        auto Result = OutResult;
        Result.Set(AllKept && Get_PieceReport().Serial >= 1);
    }

    UFUNCTION()
    private void OnClientRecipesThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        const auto Expected = Make_CentrePlane();
        const auto Pieces = Get_PieceEntitiesNear(_FloorTop);
        auto Positives = 0;
        auto Negatives = 0;
        auto Exact = 0;
        for (const auto& Piece : Pieces)
        {
            const auto Data = utils_foodpiece::TryGet_Replay(Piece).GetValue().Piece.Data;
            Assert_True(Data.Recipe.Definition == GameplayTags::FoodDef_Mars_MeatSlab, f"the recipe names the slab ({Data.Recipe.Definition.ToString()})");
            Assert_Equals_Int(Data.Recipe.Cuts.Num(), 1, "the recipe holds one cut");
            if (Data.Recipe.Cuts.Num() != 1)
            { continue; }

            const auto RecipeCut = Data.Recipe.Cuts[0];
            Assert_True(Get_IsPlaneEqual(RecipeCut.Plane, Expected), f"the cut's plane arrives exactly ({RecipeCut.Plane.Get_PositionCm()} {RecipeCut.Plane.Get_Normal()} {RecipeCut.Plane.Get_Tangent()})");
            const auto IsPositive = RecipeCut.Kept == EMars_FoodPiece_CutSide::Positive;
            Positives += IsPositive ? 1 : 0;
            Negatives += IsPositive ? 0 : 1;

            const auto ExpectedId = IsPositive ? Report.PositiveId : Report.NegativeId;
            const auto ExpectedMassKg = IsPositive ? Report.PositiveMassKg : Report.NegativeMassKg;
            Assert_True(Data.Id == ExpectedId, f"the {RecipeCut.Kept :n} half's id is the server's");
            Assert_True(Data.ParentId == Report.SourceId, f"the {RecipeCut.Kept :n} half's parent is the source");
            Assert_True(Data.Lineage == Report.Lineage, f"the {RecipeCut.Kept :n} half keeps the source's lineage");
            Assert_True(Data.MassKg == ExpectedMassKg, f"the {RecipeCut.Kept :n} half's mass is the server's exactly ({Data.MassKg} vs {ExpectedMassKg})");
            if (Get_IsPlaneEqual(RecipeCut.Plane, Expected) && Data.Id == ExpectedId && Data.ParentId == Report.SourceId
                && Data.Lineage == Report.Lineage && Data.MassKg == ExpectedMassKg)
            { ++Exact; }
        }

        Assert_Equals_Int(Positives, 1, "one half kept the positive side");
        Assert_Equals_Int(Negatives, 1, "one half kept the negative side");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Pieces.Num()} positive={Positives} negative={Negatives} exact={Exact}");
        End_Client();
    }
}
