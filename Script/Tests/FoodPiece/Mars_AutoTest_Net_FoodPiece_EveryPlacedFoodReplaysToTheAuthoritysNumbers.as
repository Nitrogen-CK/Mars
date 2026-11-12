// The server lays the nine food items 60 cm apart, cuts each at the middle of its local X bounds (normal +X), then each
// half at the middle of its local Y bounds (normal +Y); a refused cut is skipped, and at least nine cuts commit. On the
// client every Ready piece matches the authority's geometry, none differs, no replay failed, and the client has as many
// leaf pieces as the server. The client logs its leaf count per food definition.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_EveryPlacedFoodReplaysToTheAuthoritysNumbers
class UCk_AutoTest_Net_FoodPiece_EveryPlacedFoodReplaysToTheAuthoritysNumbers : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 174000.0;
    private const float64 k_SpacingCm = 60.0;
    private const int32 k_MinimumCommits = 9;
    private const float32 k_ServerWatchSeconds = 6.0f;

    private TArray<FCk_Handle> _Foods;
    private int32 _CutsIssued = 0;

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

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TArray<UCk_InventoryItem_Definition> Items;
        Items.Add(mars_items::Food_MeatSlab());
        Items.Add(mars_items::Food_MushroomSlice());
        Items.Add(mars_items::Food_Drumstick());
        Items.Add(mars_items::Food_Tentacle());
        Items.Add(mars_items::Food_Puffer());
        Items.Add(mars_items::Food_SpikedBerry());
        Items.Add(mars_items::Food_Mushroom());
        Items.Add(mars_items::Food_Pickle());
        Items.Add(mars_items::Food_Fish());

        for (int32 Index = 0; Index < Items.Num(); ++Index)
        {
            const auto Offset = (float64(Index) - float64(Items.Num() - 1) * 0.5) * k_SpacingCm;
            _Foods.Add(Spawn_ServerFood(Items[Index], _FloorTop + FVector(0.0, Offset, 5.0)));
        }

        WaitUntil(n"Is_ServerFoodsReady", n"OnServerFoodsReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFoodsReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Ready = 0;
        for (const auto& Food : _Foods)
        {
            if (Get_IsFoodReady(Food))
            { ++Ready; }
        }

        auto Result = OutResult;
        Result.Set(Ready == _Foods.Num());
    }

    UFUNCTION()
    private void OnServerFoodsReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        for (auto Food : _Foods)
        {
            auto Piece = Food.As_FoodPiece();
            Cut(Piece, Make_MiddlePlane(Piece, 0));
            ++_CutsIssued;
        }

        WaitUntil(n"Is_ServerCutsResolved", n"OnServerCutsResolved", k_SlowPolls);
    }

    // A whole food's cut that committed: each half is cut across Y.
    protected void On_CutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult) override
    {
        if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut || InResult.Positive.Get_Recipe().Cuts.Num() != 1)
        { return; }

        Cut(InResult.Positive, Make_MiddlePlane(InResult.Positive, 1));
        Cut(InResult.Negative, Make_MiddlePlane(InResult.Negative, 1));
        _CutsIssued += 2;
    }

    UFUNCTION()
    private void Is_ServerCutsResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() == _CutsIssued);
    }

    UFUNCTION()
    private void OnServerCutsResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(2, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Report = Get_PieceReport();
        Report.LeafCount = Get_ReadyPieceCountNear(_FloorTop);
        Publish_PieceReport(Report);

        const auto Commits = Get_CutCount(EMars_FoodPiece_CutOutcome::Cut);
        Assert_True(Commits >= k_MinimumCommits, f"at least {k_MinimumCommits} cuts committed (got {Commits})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"issued={_CutsIssued} committed={Commits} leaves={Report.LeafCount} {Describe_Tally()}");
        WaitSeconds(k_ServerWatchSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    // Done once the server's count arrived, every piece entity at the test's X resolved its replay and every Ready piece
    // was checked.
    UFUNCTION()
    private void Is_ClientLeavesBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Report = Get_PieceReport();
        auto Waiting = 0;
        for (auto Entity : Get_PieceEntitiesNear(_FloorTop))
        {
            const auto Replay = utils_foodpiece::TryGet_ReplayResult(Entity);
            if (Replay.IsSet() && Replay.GetValue().State == EMars_FoodPiece_ReplayState::Waiting)
            { ++Waiting; }
        }

        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        auto Result = OutResult;
        Result.Set(Report.Serial >= 1 && Pieces.Num() == Report.LeafCount && Waiting == 0 && Get_AreChecked(Pieces));
    }

    UFUNCTION()
    private void OnClientLeavesBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        const auto Matches = Get_CheckCount(Pieces, EMars_FoodPiece_CheckResult::Matches);
        const auto Differs = Get_CheckCount(Pieces, EMars_FoodPiece_CheckResult::Differs);
        Assert_Equals_Int(Matches, Pieces.Num(), "every Ready piece matches the authority");
        Assert_Equals_Int(Differs, 0, "no piece differs");
        Assert_Equals_Int(Pieces.Num(), Report.LeafCount, "as many leaves as the server");

        const auto Tally = Get_Tally();
        Assert_Equals_Int(Tally.Failed, 0, "no replay failed");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"leaves={Pieces.Num()} server={Report.LeafCount} matches={Matches} differs={Differs} perDefinition=[{Describe_PerDefinition(Pieces)}] {Describe_Tally()}");
        End_Client();
    }

    private FString Describe_PerDefinition(TArray<FCk_Handle_FoodPiece> InPieces)
    {
        TArray<FGameplayTag> Definitions;
        TArray<int32> Counts;
        for (const auto& Piece : InPieces)
        {
            const auto Definition = Piece.Get_Recipe().Definition;
            auto Index = -1;
            for (int32 Known = 0; Known < Definitions.Num(); ++Known)
            {
                if (Definitions[Known] == Definition)
                { Index = Known; }
            }

            if (Index >= 0)
            {
                Counts[Index] += 1;
                continue;
            }

            Definitions.Add(Definition);
            Counts.Add(1);
        }

        auto Text = FString();
        for (int32 Index = 0; Index < Definitions.Num(); ++Index)
        { Text += f"{Definitions[Index].ToString()}={Counts[Index]} "; }

        return Text;
    }
}
