// The real fry station at a second from pale to golden, nobody operating. The server batters a slab and admits it; when its
// kernel first raises OnFaceHeatStage Golden it reports that face (step 1). On the client the ledger row's heat for that
// face never went down across its samples and took at least three values, it reads at least 1, and the kernel's cook
// state of the piece carries at least 1 on that face's batter.
// Surface: Ck.Fry.Net.AS_Fry_TheBatterHeatReachesTheClientsLook
class UCk_AutoTest_Net_Fry_TheBatterHeatReachesTheClientsLook : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 364000.0;
    private const float32 k_GoldenSeconds = 1.0f;

    private FMars_CookingFeed_PieceId _Id;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
    }

    protected FMars_Fry_Spec Make_FrySpec() const override
    {
        auto Spec = FMars_Fry_Spec();
        Spec.Heat.GoldenSeconds = k_GoldenSeconds;
        return Spec;
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
        Spawn_FoodsThen(mars_items::Food_MeatSlab(), 1, n"OnServerFoods");
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
        WaitUntil(n"Is_ServerGolden", n"OnServerGolden", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGolden(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Stages.Contains(EMars_Fry_HeatStage::Golden));
    }

    UFUNCTION()
    private void OnServerGolden(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        const auto Index = _Stages.FindIndex(EMars_Fry_HeatStage::Golden);
        _ReportFace = int32(_StageFaces[Index]);
        Report_HeatStep(1);
        End_HeatServer(f"face={_ReportFace} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Report = Get_HeatStationReport();
        const auto Face = Report.Face;
        _Id = Report.BowlIds.Num() > 0 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();

        auto WentDown = false;
        auto Values = 0;
        auto Last = -1.0f;
        FString Seen = "";
        for (const auto& Sample : _ScoopSamples)
        {
            if (Face < 0 || Sample.FirstRowHeat.IsValidIndex(Face) == false)
            { continue; }

            const auto Heat = Sample.FirstRowHeat[Face];
            if (Heat < Last)
            { WentDown = true; }

            if (Heat != Last)
            {
                ++Values;
                Seen += f"{Heat} ";
            }

            Last = Heat;
        }

        const auto HasPiece = _Fry.Get_HasPiece(_Id);
        const auto Batter = HasPiece ? _Fry.Get_PieceCookState(_Id).Batter : TArray<float32>();
        const auto LookHeat = Batter.IsValidIndex(Face) ? Batter[Face] : -1.0f;
        Assert_True(Face >= 0, "the server reported the golden face");
        Assert_False(WentDown, f"the client's row heat for the face never went down ({Seen})");
        Assert_True(Values >= 3, f"the client's row heat for the face took at least three values ({Seen})");
        Assert_True(Last >= 1.0f, f"the client's row heat for the face reads at least 1 (got {Last})");
        Assert_True(LookHeat >= 1.0f, f"the client's cook state of the piece carries at least 1 on the face (got {LookHeat})");
        End_HeatClient(f"face={Face} values={Values} seen=[{Seen}] lookHeat={LookHeat} {Describe_Fry()} {Describe_FryLedger()}");
    }
}
