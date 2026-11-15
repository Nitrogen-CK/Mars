// Two slabs first (one battered), then the born fryer, whose authority, as it composes, drives the skimmer, asks a
// take-out naming no tray, releases a piece id naming no piece, dips and looks a little right: its spawn-frame drain
// refuses the take-out and the release and dips the scoop at a target off its park. A copy is born into that fryer.
// Once its ledger reads it, the server admits both slabs (the unbattered one refused) and asks a take-out naming no
// tray in one frame; once its ledger reads them it holds 4 s, notes its scoop's height, carries, and once its skimmer
// ledger reads Carry reports (step 1). The client's watch finds its copy before the first application of either
// ledger, which carry the born fryer; its settled dip is at the server's height (1 cm), and a settled second after
// step 1 its copy has raised only what came after: OnTakeOutRefused and OnAdmissionRefused once each (after that
// application), OnSkimRefused never, OnSkimChanged Dip (in the skimmer ledger's first frame) then Carry, OnPieceAdded
// once for the row; and from the first frame its skimmer took the born command it showed it there (0.5 cm).
// Surface: Ck.Fry.Net.AS_Fry_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Fry_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 367000.0;
    private const float32 k_HoldSeconds = 4.0f;
    private const float64 k_HeightToleranceCm = 1.0;
    // The born look moves the target well past this from the park.
    private const float64 k_OffParkCm = 1.0;

    // Client: its settled dip.
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
        _HeatStationBirth = EMars_TESTONLY_HeatStationBirth::Born;
        Begin_HeatStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientDipSettled", n"OnClientDipSettled", k_SlowPolls); }
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
        WaitUntil(n"Is_ServerBorn", n"OnServerBorn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerBorn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ledger = _Fry.Get_Ledger();
        auto Result = OutResult;
        Result.Set(Ledger.Pieces.Num() == 0 && Ledger.TakeOutRefusalSerial == 1 && Ledger.AdmissionRefusalSerial == 1);
    }

    UFUNCTION()
    private void OnServerBorn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto BornLine = f"born: {Describe_FryLedger()} {Describe_Born()}";
        Log_HeatStation(BornLine);
        const auto Skimmer = _Fry.Get_SkimmerLedger();
        Assert_True(Skimmer.Drive == EMars_Implement_Drive::Driven && Skimmer.Skim == EMars_Fry_Skim::Dip,
            f"the server's born skimmer stands driven and dipped ({Describe_FryLedger()})");

        _Followed.Add(_Foods[0].As_FoodPiece());
        Admit(_Foods[0].As_FoodPiece());
        Admit(_Foods[1].As_FoodPiece());
        Request_TakeOutWithoutTray();
        WaitUntil(n"Is_ServerAdmitted", n"OnServerAdmitted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ledger = _Fry.Get_Ledger();
        auto Result = OutResult;
        Result.Set(Ledger.Pieces.Num() == 1 && Ledger.AdmissionRefusalSerial == 2
            && Ledger.LastAdmissionRefusal == EMars_Fry_AdmissionRefusal::NotBattered && Ledger.TakeOutRefusalSerial == 2);
    }

    UFUNCTION()
    private void OnServerAdmitted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ReportValue = float32(_Fry.Get_ScoopRoot().Z);
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Carry));
        WaitUntil(n"Is_ServerCarried", n"OnServerCarried", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCarried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_SkimmerLedger().Skim == EMars_Fry_Skim::Carry);
    }

    UFUNCTION()
    private void OnServerCarried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        const auto Ledger = _Fry.Get_Ledger();
        Assert_Equals_Int(Ledger.Pieces.Num(), 1, f"the server's fryer holds one row ({Describe_FryLedger()})");
        Assert_True(Ledger.AdmissionRefusalSerial == 2 && Ledger.LastAdmissionRefusal == EMars_Fry_AdmissionRefusal::NotBattered,
            f"the server refused two admissions, the last NotBattered ({Describe_FryLedger()})");
        Assert_Equals_Int(Ledger.TakeOutRefusalSerial, 2, "the server refused two take-outs");
        Assert_Equals_Int(Ledger.SkimRefusalSerial, 0, "the server refused no skim");
        Assert_True(_Fry.Get_SkimmerLedger().Skim == EMars_Fry_Skim::Carry, f"the server's skimmer carries ({Describe_FryLedger()})");
        End_HeatServer(f"dippedHeight={_ReportValue} {Describe_Fry()} {Describe_FryLedger()} {Describe_Born()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // A copy the server already destroyed is not settled.
    UFUNCTION()
    private void Is_ClientDipSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Fry) && Get_IsLive(_Fry) && Get_IsDipSettled());
    }

    UFUNCTION()
    private void OnClientDipSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _DippedHeight = _Fry.Get_ScoopRoot().Z;
        Await_Step(1);
    }

    // A settled second after step 1.
    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Line = f"dippedHeight={_DippedHeight} {Describe_Born()} {Describe_FryLedger()}";
        const auto First = Get_BornFirstFryLedger();
        const auto FirstFrame = Get_BornFirstNotifyFrame();
        const auto SkimmerFirst = Get_BornFirstSkimmerLedger();
        const auto SkimmerFirstFrame = Get_BornFirstSkimmerNotifyFrame();
        const auto Ledger = _Fry.Get_Ledger();

        Assert_True(Get_HasBornFirstNotify() && Get_HasBornFirstSkimmerNotify(),
            f"the client recorded both ledgers' first applications ({Line})");
        Assert_True(_BornInitialAtFind == EMars_Net_InitialState::Awaited && _BornSkimmerInitialAtFind == EMars_Net_InitialState::Awaited,
            f"the client watched its copy before it took either ledger's state ({Line})");
        Assert_True(Get_BornInitialState() == EMars_Net_InitialState::Taken && Get_BornSkimmerInitialState() == EMars_Net_InitialState::Taken,
            f"the client's copy took the state it was born into from both ledgers ({Line})");
        Assert_True(First.Pieces.Num() == 0 && First.SkimRefusalSerial == 0 && First.TakeOutRefusalSerial == 1
            && First.AdmissionRefusalSerial == 1,
            f"the first application carried the born fryer: no row, no refused skim, one refused take-out and admission ({Line})");
        Assert_True(SkimmerFirst.Drive == EMars_Implement_Drive::Driven && SkimmerFirst.Skim == EMars_Fry_Skim::Dip
            && (SkimmerFirst.Target - _Fry.Get_SkimmerPark()).Size() > k_OffParkCm,
            f"the skimmer ledger's first application carried the born command: driven, dipped, off its park ({Line})");

        const auto Admissions = Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::AdmissionRefused);
        Assert_Equals_Int(Admissions.Num(), Ledger.AdmissionRefusalSerial - First.AdmissionRefusalSerial,
            f"OnAdmissionRefused only for what came after ({Line})");
        Assert_True(Admissions.Num() == 0 || Admissions[0].Frame > FirstFrame, f"no admission refusal in the first application's frame ({Line})");
        const auto TakeOuts = Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused);
        Assert_Equals_Int(TakeOuts.Num(), Ledger.TakeOutRefusalSerial - First.TakeOutRefusalSerial,
            f"OnTakeOutRefused only for what came after ({Line})");
        Assert_True(TakeOuts.Num() == 0 || TakeOuts[0].Frame > FirstFrame, f"no take-out refusal in the first application's frame ({Line})");
        Assert_Equals_Int(Get_BornEventCount(EMars_TESTONLY_NetHeatBornEventKind::SkimRefused),
            Ledger.SkimRefusalSerial - First.SkimRefusalSerial, f"OnSkimRefused only for what came after ({Line})");

        const auto Skims = Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::SkimChanged);
        Assert_True(Skims.Num() == 2 && Skims[0].Value == int32(EMars_Fry_Skim::Dip) && Skims[0].Frame == SkimmerFirstFrame
            && Skims[1].Value == int32(EMars_Fry_Skim::Carry),
            f"OnSkimChanged Dip in the skimmer ledger's first frame, then Carry ({Line})");
        Assert_True(_BornAddedIds.Num() == 1 && Ledger.Pieces.Num() == 1 && _BornAddedIds[0].Get_IsSame(Ledger.Pieces[0].Id),
            f"OnPieceAdded once, for the row ({Line})");

        Assert_True(Get_BornCommandSampleCount() > 0, f"the skimmer took the born command while the ledger carried it ({Line})");
        Assert_True(Get_BornWorstLiftCm() >= 0.0 && Get_BornWorstLiftCm() <= k_ScoopSettledCm
            && Get_BornWorstSlideCm() >= 0.0 && Get_BornWorstSlideCm() <= k_ScoopSettledCm,
            f"from the first frame the skimmer took the born command it showed its lift and slide there ({Line})");

        const auto Reported = float64(Get_HeatStationReport().Value);
        Assert_True(Math::Abs(_DippedHeight - Reported) <= k_HeightToleranceCm,
            f"the client's settled dip is at the server's height (client {_DippedHeight}, server {Reported})");
        Assert_True(Ledger.Pieces.Num() == 1 && Ledger.AdmissionRefusalSerial == 2 && Ledger.TakeOutRefusalSerial == 2
            && _Fry.Get_SkimmerLedger().Skim == EMars_Fry_Skim::Carry,
            f"the client's ledgers read one row, two refused admissions and take-outs, the skimmer carrying ({Line})");
        End_HeatClient(Line);
    }
}
