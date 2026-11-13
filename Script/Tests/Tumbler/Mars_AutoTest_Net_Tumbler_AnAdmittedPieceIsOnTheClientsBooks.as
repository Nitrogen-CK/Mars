// The real tumbler station, nobody operating. The server points at the shut hatch and opens it, admits a slab, and once
// the slab is in the drum reports (step 1). The client's kernel names that one id, it raised OnPieceAdded for it once, the
// piece's entity it reads is its own copy of the slab, and its label reads "1 in" and the hatch.
// Surface: Ck.Tumbler.Net.AS_Tumbler_AnAdmittedPieceIsOnTheClientsBooks
class UCk_AutoTest_Net_Tumbler_AnAdmittedPieceIsOnTheClientsBooks : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 382000.0;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Tumbler;
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
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointed");
    }

    UFUNCTION()
    private void OnServerPointed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        WaitUntil(n"Is_ServerOpen", n"OnServerOpen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Open);
    }

    UFUNCTION()
    private void OnServerOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("admit");
        _Followed.Add(_Foods[0].As_FoodPiece());
        Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_PieceIds().Num() == 1);
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        End_HeatServer(f"{Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Report = Get_HeatStationReport();
        const auto Id = Report.BowlIds.Num() > 0 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();
        const auto Ids = _Tumbler.Get_PieceIds();
        const auto Copy = Get_FollowedCopy(0);
        const auto Label = Get_ShownLabel().Replace("\n", " / ");
        Assert_True(Ids.Num() == 1 && Ids[0].Get_IsSame(Id), f"the client's kernel names the one admitted id ({Describe_TumblerLedger()})");
        Assert_Equals_Int(Get_TumblerAddedCount(Id), 1, f"the client raised OnPieceAdded for it once ({Describe_TumblerRecord()})");
        Assert_True(Get_IsLive(Copy) && _Tumbler.Get_HasPiece(Id) && _Tumbler.Get_PieceEntity(Id) == Copy,
            f"the piece's entity the client reads is its copy of the slab ({Describe_TumblerLedger()})");
        Assert_True(Label.Contains("1 in") && Label.Contains("hatch"), f"the client's label reads 1 in and the hatch ('{Label}')");
        End_HeatClient(f"label='{Label}' {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
