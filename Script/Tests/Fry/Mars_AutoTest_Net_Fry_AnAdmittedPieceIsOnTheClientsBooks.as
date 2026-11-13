// The real fry station, nobody operating. The server batters one of two slabs and admits it; once it is in the oil it
// reports (step 1). It admits the unbattered one (refused NotBattered) and a second later reports again (step 2). At step 1
// the client's kernel names that one id, raised OnPieceAdded for it once, reads it in the Oil and its label reads
// "1 frying". At step 2 it raised OnAdmissionRefused once, NotBattered, still holds one row, and its label said
// "not battered: batter it first".
// Surface: Ck.Fry.Net.AS_Fry_AnAdmittedPieceIsOnTheClientsBooks
class UCk_AutoTest_Net_Fry_AnAdmittedPieceIsOnTheClientsBooks : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 363000.0;
    private const float32 k_RefusedSeconds = 1.0f;

    private FMars_CookingFeed_PieceId _Id;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
    }

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
        Spawn_FoodsThen(mars_items::Food_MeatSlab(), 2, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TArray<FCk_Handle_FoodPiece> Battered;
        Battered.Add(_Foods[0].As_FoodPiece());
        Batter_Then(Battered, n"OnServerBattered");
    }

    UFUNCTION()
    private void OnServerBattered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerInOil", n"OnServerInOil", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerInOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsInOil(_Id));
    }

    UFUNCTION()
    private void OnServerInOil(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Admit(_Foods[1].As_FoodPiece());
        WaitSeconds(k_RefusedSeconds, n"OnServerRefused");
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStep(2);
        Assert_True(_FryAdmissionRefusals.Num() == 1 && _FryAdmissionRefusals[0] == EMars_Fry_AdmissionRefusal::NotBattered,
            f"the server refused the unbattered slab once, NotBattered ({Describe_FryRecord()})");
        End_HeatServer(f"{Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Label = Get_ShownLabel().Replace("\n", " / ");
        if (InStep == 1)
        {
            Mark_Time("step1");
            const auto Report = Get_HeatStationReport();
            _Id = Report.BowlIds.Num() > 0 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();
            const auto Ids = _Fry.Get_PieceIds();
            Assert_True(Ids.Num() == 1 && Ids[0].Get_IsSame(_Id), f"the client's kernel names the one admitted id ({Describe_FryLedger()})");
            Assert_Equals_Int(Get_FryAddedCount(_Id), 1, f"the client raised OnPieceAdded for it once ({Describe_FryRecord()})");
            Assert_True(_Fry.Get_HasPiece(_Id) && _Fry.Get_PieceWhereabouts(_Id) == EMars_Fry_Whereabouts::Oil, f"the client reads it in the Oil ({Describe_FryLedger()})");
            Assert_True(Get_ShownLabel().Contains("1 frying"), f"the client's label reads 1 frying ('{Label}')");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        Assert_True(_FryAdmissionRefusals.Num() == 1 && _FryAdmissionRefusals[0] == EMars_Fry_AdmissionRefusal::NotBattered,
            f"the client raised OnAdmissionRefused once, NotBattered ({Describe_FryRecord()})");
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 1, f"the client's kernel still holds one row ({Describe_FryLedger()})");
        Assert_True(Get_SawLabelAtAnyStep("not battered: batter it first"), f"the client's label said not battered ({Describe_Seen(_LabelsSeen)})");
        End_HeatClient(f"label='{Label}' {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }
}
