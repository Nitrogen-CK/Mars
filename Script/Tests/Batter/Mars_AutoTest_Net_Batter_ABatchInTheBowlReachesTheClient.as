// Two whole foods lie loose beside the real batter station; the server admits both into the bowl and, once both are in,
// reports their ids (step 1). On the client the bowl reads both ids in the server's order, each copy hangs under the
// client's own bowl node within 0.5 cm of its slot's offset at rest, OnPieceAdded was raised once per id and the label
// says two are in.
// Surface: Ck.Batter.Net.AS_Batter_ABatchInTheBowlReachesTheClient
class UCk_AutoTest_Net_Batter_ABatchInTheBowlReachesTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 300000.0;
    private const int32 k_Count = 2;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_HeatStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Spawn_FoodsThen(mars_items::Food_Mushroom(), k_Count, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        for (const auto& Food : _Foods)
        {
            _Followed.Add(Food.As_FoodPiece());
            Admit(Food.As_FoodPiece());
        }

        WaitUntil(n"Is_ServerBothIn", n"OnServerBothIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerBothIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_PieceCount() == k_Count);
    }

    UFUNCTION()
    private void OnServerBothIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_Equals_Int(_AddedIds.Num(), k_Count, "the server raised OnPieceAdded for both");
        End_HeatServer(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Report = Get_HeatStationReport();
        const auto Ids = _Batter.Get_PieceIds();
        auto SameOrder = Ids.Num() == Report.BowlIds.Num();
        for (int32 Index = 0; SameOrder && Index < Ids.Num(); ++Index)
        { SameOrder = Ids[Index].Get_IsSame(Report.BowlIds[Index]); }

        FString Errors = "";
        auto WorstCm = 0.0;
        auto AllUnder = true;
        for (int32 Index = 0; Index < Report.BowlIds.Num(); ++Index)
        {
            const auto Copy = Get_FollowedCopy(Index);
            const auto ErrorCm = Get_SlotErrorCm(Copy, Get_SlotOf(Report.BowlIds[Index]), 0.0f);
            Errors += f"{ErrorCm} ";
            if (ErrorCm < 0.0 || ErrorCm > constants_heat_station_net_autotest::k_OffsetToleranceCm)
            { AllUnder = false; }

            WorstCm = Math::Max(WorstCm, ErrorCm);
        }

        auto AddedOncePerId = _AddedIds.Num() == k_Count;
        for (const auto& Id : Report.BowlIds)
        {
            if (Get_AddedCount(Id) != 1)
            { AddedOncePerId = false; }
        }

        const auto Label = Get_ShownLabel();
        Assert_Equals_Int(Report.BowlIds.Num(), k_Count, "the server reported two ids");
        Assert_True(SameOrder, f"the client's bowl reads the server's ids in its order ({Describe_BatterLedger()})");
        Assert_True(AllUnder, f"each copy hangs under the client's bowl at its slot at rest (errors cm: {Errors})");
        Assert_True(AddedOncePerId, f"the client raised OnPieceAdded once per id ({Describe_BatterRecord()})");
        Assert_True(Label.Contains("2 in"), f"the client's label says two are in ('{Label}')");
        End_HeatClient(f"errorsCm=[{Errors}] worstCm={WorstCm} label='{Label}' {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
