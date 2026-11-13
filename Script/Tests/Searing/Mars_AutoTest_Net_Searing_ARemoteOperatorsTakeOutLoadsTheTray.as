// The real searing station at half a second a face. The server docks a tray, admits a slab seared on every face but -Z (it
// arrives flat on -Z), seats the subject (the pan heats) and, once the piece is Ready, reports (step 1); a moment later it
// applies one remote Secondary press, and once the tray has frozen the piece publishes the tray's rides (step 2). At step 1
// the client's take-out row reads "take out - 1 ready" and it raised OnFaceSeared once. At step 2 its take-out row reads
// "take out - 0 ready", its pan has no rows, its copy rides its tray at the published ride and its six sears read 1.
// Surface: Ck.Searing.Net.AS_Searing_ARemoteOperatorsTakeOutLoadsTheTray
class UCk_AutoTest_Net_Searing_ARemoteOperatorsTakeOutLoadsTheTray : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 345000.0;
    private const float32 k_SecondsPerFace = 0.5f;

    private FMars_CookingFeed_PieceId _Id;
    private float64 _AdmitSeconds = 0.0;

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
        _AdmitSeconds = System::GetGameTimeInSeconds();
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("seated");
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
        Mark_Time("takeOut");
        Press_Remote(GameplayTags::Mars_Intent_Interact_Secondary);
        WaitUntil(n"Is_ServerTrayFrozen", n"OnServerTrayFrozen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTrayFrozen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tray.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void OnServerTrayFrozen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStepWithRidesOf(2, _Tray);
        const auto ReadySeconds = System::GetGameTimeInSeconds() - _AdmitSeconds;
        End_HeatServer(f"admitToTrayS={ReadySeconds} tray={_Tray.Get_HeldCount()} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            const auto Row = Get_TakeOutRowText();
            Assert_True(Row == "take out - 1 ready", f"the client's take-out row reads take out - 1 ready (got {Row})");
            Assert_Equals_Int(_SearedIds.Num(), 1, f"the client raised OnFaceSeared once ({Describe_SearingRecord()})");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Row = Get_TakeOutRowText();
        const auto Copy = Get_FollowedCopy(0);
        const auto Report = Get_PlatterReport();
        const auto RideFault = Try_FindTray() && Report.Count == 1 ? Get_RideFaultOn(_Tray, Copy, Get_Slot(Report, 0)) : "no tray or no ride";
        const auto IsSeared = Get_IsLive(Copy) && Get_IsSearedAllRound(Copy.Get_CookState());
        Assert_True(Row == "take out - 0 ready", f"the client's take-out row reads take out - 0 ready (got {Row})");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, f"the client's pan has no rows ({Describe_SearingLedger()})");
        Assert_True(RideFault.IsEmpty(), f"the client's copy rides its tray ({RideFault})");
        Assert_True(IsSeared, "the client's copy's six sears read 1");
        End_HeatClient(f"row=[{Row}] ride=[{RideFault}] seared={IsSeared} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
