// Two slabs first (one battered), then the station. In the continuation in which the server first finds its station ready
// it drives the skimmer, admits both (the unbattered one refused) and dips; it holds 4 s, notes its scoop's height, carries
// and reports (step 1). The client starts counting only once its ledger reads one admission refusal and one row, its
// skimmer ledger reads Dip and its copy announced that row (a listener that arrives after them): OnPieceAdded was raised
// for the row once in all, and once its dip has settled its scoop is at the server's dipped height (1 cm). From the clear
// to step 1 it raised OnSkimChanged Carry once and nothing else, no OnAdmissionRefused and no OnPieceAdded.
// Surface: Ck.Fry.Net.AS_Fry_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Fry_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 367000.0;
    private const float32 k_HoldSeconds = 4.0f;
    private const float64 k_HeightToleranceCm = 1.0;

    // Client: what it saw when its ledgers first stood as the server left them, and its settled dip.
    private int32 _AddedBeforeClear = -1;
    private int64 _FoundFrame = -1;
    private int64 _ClearFrame = -1;
    private float64 _DippedHeight = -1000.0;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _ServerActsOnFirstFind = true;
        Begin_HeatStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientLedgerStands", n"OnClientLedgerStands", k_SlowPolls); }
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
        _Fry.Request_SetDrive(FMars_Request_Fry_SetDrive(EMars_Implement_Drive::Driven));
        Admit(_Foods[0].As_FoodPiece());
        Admit(_Foods[1].As_FoodPiece());
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Dip));
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ReportValue = float32(_Fry.Get_ScoopRoot().Z);
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Carry));
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_True(_FryAdmissionRefusals.Num() == 1 && _FryAdmissionRefusals[0] == EMars_Fry_AdmissionRefusal::NotBattered,
            f"the server refused the unbattered slab once, NotBattered ({Describe_FryRecord()})");
        End_HeatServer(f"dippedHeight={_ReportValue} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientLedgerStands(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Try_FindHeatStation() == false || Get_IsLive(_Station) == false)
        {
            Result.Set(false);
            return;
        }

        if (_FoundFrame < 0)
        { _FoundFrame = utils_time::Get_FrameCounter(); }

        const auto Ledger = _Fry.Get_Ledger();
        Result.Set(Ledger.AdmissionRefusalSerial == 1 && Ledger.Pieces.Num() == 1 && _Fry.Get_SkimmerLedger().Skim == EMars_Fry_Skim::Dip
            && Get_FryAnnouncedRows().Num() == 1);
    }

    // The listener arrives now: what its copy raised before is not its to count.
    UFUNCTION()
    private void OnClientLedgerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClearFrame = utils_time::Get_FrameCounter();
        const auto Id = _Fry.Get_Ledger().Pieces[0].Id;
        _AddedBeforeClear = Get_FryAddedCount(Id);
        Clear_FryRecord();
        Assert_Equals_Int(_AddedBeforeClear, 1, "the client raised OnPieceAdded for the row once before it started counting");
        WaitUntil(n"Is_ClientDipSettled", n"OnClientDipSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientDipSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDipSettled());
    }

    UFUNCTION()
    private void OnClientDipSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _DippedHeight = _Fry.Get_ScoopRoot().Z;
        Await_Step(1);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Reported = float64(Get_HeatStationReport().Value);
        Assert_True(Math::Abs(_DippedHeight - Reported) <= k_HeightToleranceCm, f"the client's settled dip is at the server's height (client {_DippedHeight}, server {Reported})");
        Assert_True(Get_SkimChangeCount(EMars_Fry_Skim::Carry) == 1 && _SkimChanges.Num() == 1,
            f"since it started counting the client raised OnSkimChanged Carry once ({Describe_FryRecord()})");
        Assert_Equals_Int(_FryAdmissionRefusals.Num(), 0, "the client raised no earlier admission refusal again");
        Assert_Equals_Int(_FryAddedIds.Num(), 0, "the client raised no OnPieceAdded again");
        End_HeatClient(f"addedBeforeClear={_AddedBeforeClear} foundFrame={_FoundFrame} clearFrame={_ClearFrame} dippedHeight={_DippedHeight} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }
}
