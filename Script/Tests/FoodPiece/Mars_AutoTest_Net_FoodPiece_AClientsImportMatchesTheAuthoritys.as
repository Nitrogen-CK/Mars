// The server spawns the nine food items 60 cm apart. On the client, every copy checks its own import against the numbers
// the authority recorded: each reaches Matches and none reads Differs. Each copy's two pairs of numbers are logged.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_AClientsImportMatchesTheAuthoritys
class UCk_AutoTest_Net_FoodPiece_AClientsImportMatchesTheAuthoritys : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 164000.0;
    private const float64 k_SpacingCm = 60.0;
    private const int32 k_FoodCount = 9;
    private const float32 k_ServerWatchSeconds = 8.0f;
    private const float64 k_CheckSeconds = 8.0;

    private TArray<FCk_Handle> _Foods;
    private TOptional<float64> _FirstSeenAt;

    private TArray<UCk_InventoryItem_Definition> Get_Items()
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
        return Items;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientChecked", n"OnClientChecked", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Items = Get_Items();
        for (int32 Index = 0; Index < Items.Num(); ++Index)
        {
            const auto Offset = FVector(0.0, (float64(Index) - float64(k_FoodCount - 1) * 0.5) * k_SpacingCm, 5.0);
            _Foods.Add(Spawn_ServerFood(Items[Index], _FloorTop + Offset));
        }

        WaitUntil(n"Is_ServerFoodsReady", n"OnServerFoodsReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFoodsReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        for (const auto& Food : _Foods)
        {
            if (Get_IsFoodReady(Food) == false)
            {
                Result.Set(false);
                return;
            }
        }

        Result.Set(true);
    }

    UFUNCTION()
    private void OnServerFoodsReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Recorded = 0;
        for (const auto& Food : _Foods)
        {
            const auto Ledger = utils_foodpiece::TryGet_Ledger(Food);
            if (Ledger.IsSet() && Ledger.GetValue().Check == EMars_FoodPiece_Check::Recorded && Ledger.GetValue().CheckTriangles > 0)
            { ++Recorded; }

            Assert_True(Food.As_FoodPiece().Get_CheckResult() == EMars_FoodPiece_CheckResult::Unchecked, "the authority never checks its own geometry");
        }

        Assert_Equals_Int(Recorded, k_FoodCount, "every server food recorded its check numbers");
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"foods={_Foods.Num()}");
        WaitSeconds(2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // Every one of the nine copies checked, or the check time has passed since the first copy was there.
    UFUNCTION()
    private void Is_ClientChecked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Foods = Get_FoodPiecesNear(_FloorTop);
        if (Foods.Num() == 0)
        {
            Result.Set(false);
            return;
        }

        if (_FirstSeenAt.IsSet() == false)
        { _FirstSeenAt = TOptional<float64>(Get_Now()); }

        auto Checked = 0;
        for (const auto& Food : Foods)
        {
            if (Food.Get_CheckResult() != EMars_FoodPiece_CheckResult::Unchecked)
            { ++Checked; }
        }

        Result.Set((Foods.Num() == k_FoodCount && Checked == k_FoodCount) || Get_Now() - _FirstSeenAt.GetValue() > k_CheckSeconds);
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Foods = Get_FoodPiecesNear(_FloorTop);
        auto Matches = 0;
        auto Differs = 0;
        for (const auto& Food : Foods)
        {
            const auto Result = Food.Get_CheckResult();
            if (Result == EMars_FoodPiece_CheckResult::Matches)
            { ++Matches; }

            if (Result == EMars_FoodPiece_CheckResult::Differs)
            { ++Differs; }

            Log_Pair(Food);
        }

        Assert_Equals_Int(Foods.Num(), k_FoodCount, "nine food copies on the client");
        Assert_Equals_Int(Matches, k_FoodCount, "every copy matches the authority's numbers");
        Assert_Equals_Int(Differs, 0, "no copy differs");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"foods={Foods.Num()} matches={Matches} differs={Differs}");
        FinishSuccess();
    }

    private void Log_Pair(FCk_Handle_FoodPiece InFood)
    {
        const auto Ledger = utils_foodpiece::TryGet_Ledger(InFood);
        const auto Metrics = utils_runtime_mesh::Get_Metrics(InFood.Get_Geometry());
        const UMars_Food_Def Def = InFood.Get_Definition().Get();
        const FString Name = ck::IsValid(Def) ? Def.GetName().ToString() : "none";
        const auto RecordedVolume = Ledger.IsSet() ? Ledger.GetValue().CheckVolumeCm3 : -1.0;
        const auto RecordedTriangles = Ledger.IsSet() ? Ledger.GetValue().CheckTriangles : -1;
        Log(f"[FoodPieceNetCheck] {GetClass().GetName()} client pair: food={Name} result={InFood.Get_CheckResult() :n} volume={Metrics.Get_VolumeCm3()} authorityVolume={RecordedVolume} triangles={Metrics.Get_TriangleCount()} authorityTriangles={RecordedTriangles}");
    }
}
