// The real searing station at half a second a face, as the remote take-out test up to its first step: a tray, a slab seared
// on every face but -Z admitted, the subject seated and the piece Ready (step 1). Then in one frame the server applies a
// remote Secondary press and releases the subject; three seconds later it publishes the tray's rides and reports where the
// piece is (on the tray, or still on the pan), with its pan's rows and its taken-out count (step 2). The server raised no
// ensure and its pan is cold. On the client the station is free and its pan cold, its copy is where the server says (riding
// its tray with no take-out row, or Ready on its pan's books) and its counts equal the server's.
// Surface: Ck.Searing.Net.AS_Searing_ATakeOutAndALeaveInOneFrame
class UCk_AutoTest_Net_Searing_ATakeOutAndALeaveInOneFrame : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 346000.0;
    private const float32 k_SecondsPerFace = 0.5f;
    private const float32 k_AfterSeconds = 3.0f;

    private FMars_CookingFeed_PieceId _Id;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Searing;
    }

    protected FMars_Searing_Spec Make_SearingSpec() const override
    {
        auto Spec = FMars_Searing_Spec();
        Spec.Cook.SecondsPerFace = k_SecondsPerFace;
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

    // Every face but -Z seared, so the face the piece arrives on is the one left to sear.
    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Piece = _Foods[0].As_FoodPiece();
        auto CookState = Piece.Get_CookState();
        for (int32 Index = 0; Index < CookState.Sear.Num(); ++Index)
        { CookState.Sear[Index] = Index == int32(EMars_FoodPiece_Face::NegZ) ? 0.0f : 1.0f; }

        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        WaitUntil(n"Is_ServerFiveSeared", n"OnServerFiveSeared", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFiveSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto CookState = _Foods[0].As_FoodPiece().Get_CookState();
        auto Result = OutResult;
        Result.Set(CookState.Sear.Num() == 6 && CookState.Sear[int32(EMars_FoodPiece_Face::PosZ)] >= 1.0f);
    }

    UFUNCTION()
    private void OnServerFiveSeared(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Dock_TrayThen(n"OnServerTrayDocked");
    }

    UFUNCTION()
    private void OnServerTrayDocked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_HasPiece(_Id) && _Searing.Get_PieceStatus(_Id) == EMars_Searing_PieceStatus::Ready);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("pressAndLeave");
        Press_Remote(GameplayTags::Mars_Intent_Interact_Secondary);
        Release_Subject();
        WaitSeconds(k_AfterSeconds, n"OnServerAfter");
    }

    UFUNCTION()
    private void OnServerAfter(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        const auto OnTray = _Tray.Get_HeldCount() == 1;
        _ReportValue = float32(_Searing.Get_Summary().TakenOut);
        Assert_True(_Searing.Get_IsHot() == false, "the server's pan is cold");
        Report_HeatStepWithRidesOf(2, _Tray);
        const FString Where = OnTray ? "tray" : "pan";
        End_HeatServer(f"where={Where} tray={_Tray.Get_HeldCount()} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Report = Get_HeatStationReport();
        const auto PlatterReport = Get_PlatterReport();
        const auto OnTray = PlatterReport.Count == 1;
        const auto Copy = Get_FollowedCopy(0);
        const auto TrayHeld = Try_FindTray() ? _Tray.Get_HeldCount() : -1;
        const FString Where = OnTray ? "tray" : "pan";
        FString Fault = "";
        if (OnTray)
        {
            Fault = ck::IsValid(_Tray) ? Get_RideFaultOn(_Tray, Copy, Get_Slot(PlatterReport, 0)) : "no tray";
            const auto Row = Get_TakeOutRowText();
            Assert_True(Row == "<no row>", f"the client shows no take-out row (got {Row})");
        }
        else
        {
            const auto Id = Report.BowlIds.Num() == 1 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();
            const auto IsReady = Report.BowlIds.Num() == 1 && _Searing.Get_HasPiece(Id) && _Searing.Get_PieceStatus(Id) == EMars_Searing_PieceStatus::Ready;
            Fault = IsReady ? "" : f"not Ready on the client's pan ({Describe_SearingLedger()})";
        }

        Assert_True(_Station.As_Station().Get_IsOperated() == false, "the client's station is free");
        Assert_True(_Searing.Get_IsHot() == false, "the client's pan is cold");
        Assert_True(Fault.IsEmpty(), f"the client's copy is where the server says ({Where}: {Fault})");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), Report.BowlIds.Num(), "the client's pan rows count the server's");
        Assert_Equals_Int(_Searing.Get_Summary().TakenOut, int32(Report.Value), "the client's taken-out count is the server's");
        Assert_Equals_Int(TrayHeld, PlatterReport.Count, "the client's tray holds what the server's does");
        End_HeatClient(f"where={Where} fault=[{Fault}] tray={TrayHeld} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
