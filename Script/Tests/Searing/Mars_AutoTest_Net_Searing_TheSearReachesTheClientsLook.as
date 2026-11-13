// The real searing station with one second per face, nobody operating. The server heats the pan and admits the slab; when
// its kernel raises OnFaceSeared it reports the face (step 1). On the client, across its sampled frames, that face's sear in
// the ledger row never went down and took at least three values; it raised OnFaceSeared once, for that face; its kernel's
// cook state for the piece reads that face 1; it raised OnHeatChanged Hot once; and Get_Sizzle() read Sizzling in some
// sampled frame.
// Surface: Ck.Searing.Net.AS_Searing_TheSearReachesTheClientsLook
class UCk_AutoTest_Net_Searing_TheSearReachesTheClientsLook : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 323000.0;

    private FMars_CookingFeed_PieceId _Id;

    // Client: every sampled ledger row's six sears, in order, and whether it ever read Sizzling.
    private TArray<FMars_Searing_PieceRow> _SampledRows;
    private bool _SawSizzling = false;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Searing;
    }

    protected FMars_Searing_Spec Make_SearingSpec() const override
    {
        auto Spec = FMars_Searing_Spec();
        Spec.Cook.SecondsPerFace = 1.0f;
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
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerSeared", n"OnServerSeared", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_SearedFaces.Num() > 0);
    }

    UFUNCTION()
    private void OnServerSeared(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        _ReportFace = int32(_SearedFaces[0]);
        Report_HeatStep(1);
        End_HeatServer(f"face={_SearedFaces[0] :n} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_HeatStationSample() override
    {
        if (Get_IsServer())
        { return; }

        if (_Searing.Get_Sizzle() == EMars_Searing_Sizzle::Sizzling)
        { _SawSizzling = true; }

        const auto Ledger = _Searing.Get_Ledger();
        if (Ledger.Pieces.Num() == 1)
        { _SampledRows.Add(Ledger.Pieces[0]); }
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Report = Get_HeatStationReport();
        const auto Face = Report.Face;
        _Id = Report.BowlIds.Num() > 0 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();

        auto WentDown = false;
        TArray<float32> Values;
        for (int32 Index = 0; Index < _SampledRows.Num(); ++Index)
        {
            const auto& Sears = _SampledRows[Index].FaceSear;
            if (Sears.IsValidIndex(Face) == false)
            { continue; }

            const auto Sear = Sears[Face];
            if (Values.Num() > 0 && Sear < Values.Last())
            { WentDown = true; }

            if (Values.Num() == 0 || Sear != Values.Last())
            { Values.Add(Sear); }
        }

        FString Seen = "";
        for (const auto Value : Values)
        { Seen += f"{Value} "; }

        const auto IsKnown = _Searing.Get_HasPiece(_Id);
        const auto CookSear = IsKnown ? _Searing.Get_PieceCookState(_Id).Sear : TArray<float32>();
        const auto FaceCookSear = CookSear.IsValidIndex(Face) ? CookSear[Face] : -1.0f;
        Assert_True(Face >= 0, "the server reported the seared face");
        Assert_False(WentDown, f"the client's sear of that face never went down ({Seen})");
        Assert_True(Values.Num() >= 3, f"the client's sear of that face took at least three values ({Seen})");
        Assert_True(_SearedFaces.Num() == 1 && int32(_SearedFaces[0]) == Face, f"the client raised OnFaceSeared once, for that face ({Describe_SearingRecord()})");
        Assert_True(FaceCookSear == 1.0f, f"the client's kernel's cook state reads that face seared (got {FaceCookSear})");
        Assert_True(Get_HeatChangeCount(EMars_Searing_Heat::Hot) == 1 && _HeatChanges.Num() == 1, f"the client raised OnHeatChanged Hot once ({Describe_SearingRecord()})");
        Assert_True(_SawSizzling, "the client's kernel read Sizzling in some sampled frame");
        End_HeatClient(f"face={Face} values=[{Seen}] rows={_SampledRows.Num()} cookSear={FaceCookSear} sizzling={_SawSizzling} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
