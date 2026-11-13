// A three-second coat. The server admits one whole food, dips the bowl and one second later reports the piece's coat
// (step 1) and lifts; one second later it reports step 2. The server lifts in the frame it reports step 1, so the client
// reads its step-1 state from the last frame it sampled with its bowl Dipped: its copy then hung under its own bowl lower
// than at rest by the dip depth (0.5 cm), and its coat was within 0.1 of the reported coat and not above it. At step 2 its
// bowl is Resting, its copy is back at rest (0.5 cm), its coat is not lower than at step 1, it raised OnBowlChanged
// Dipped then Resting, each once, and its label said "dipping" in some sampled frame.
// Surface: Ck.Batter.Net.AS_Batter_ADipSinksThePiecesOnTheClient
class UCk_AutoTest_Net_Batter_ADipSinksThePiecesOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 301000.0;
    private const float32 k_CoatSeconds = 3.0f;
    private const float32 k_DipHoldSeconds = 1.0f;
    private const float32 k_LiftHoldSeconds = 1.0f;

    // Client: the last sampled frame with its bowl Dipped (while the report had not reached step 2).
    private int32 _DippedFrames = 0;
    private float64 _DippedErrorCm = -1.0;
    private float64 _DippedDropCm = -1.0;
    private float32 _DippedCoat = -1.0f;

    protected FMars_Batter_Spec Make_BatterSpec() const override
    {
        auto Spec = FMars_Batter_Spec();
        Spec.Coat.CoatSeconds = k_CoatSeconds;
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

    protected void On_HeatStationSample() override
    {
        if (Get_IsServer() || Get_HeatStationReport().Step >= 2 || _Batter.Get_Bowl() != EMars_Batter_Bowl::Dipped)
        { return; }

        const auto Ids = _Batter.Get_PieceIds();
        if (Ids.Num() != 1 || Get_IsLive(Get_BowlCopy(Ids[0])) == false)
        { return; }

        const auto Copy = Get_BowlCopy(Ids[0]);
        const auto Slot = Get_SlotOf(Ids[0]);
        ++_DippedFrames;
        _DippedErrorCm = Get_SlotErrorCm(Copy, Slot, 1.0f);
        _DippedDropCm = Get_RestZ(Copy, Slot) - Get_Offset(Copy).GetLocation().Z;
        _DippedCoat = _Batter.Get_PieceCoat(Ids[0]);
    }

    // The offset Z the piece's slot puts it at, at rest.
    private float64 Get_RestZ(FCk_Handle_FoodPiece InPiece, int32 InSlot)
    {
        auto State = FMars_Batter_PieceState();
        State.Piece = InPiece;
        State.Slot = InSlot;
        return utils_batter::Get_PieceOffset(_Batter.Get_Spec().Bowl, State).GetLocation().Z;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Spawn_FoodsThen(mars_items::Food_Mushroom(), 1, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_PieceCount() == 1);
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EventFrame = utils_time::Get_FrameCounter();
        _Batter.Request_Dip(FMars_Request_Batter_Dip());
        WaitSeconds(k_DipHoldSeconds, n"OnServerDipped");
    }

    UFUNCTION()
    private void OnServerDipped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        _Batter.Request_Lift(FMars_Request_Batter_Lift());
        WaitSeconds(k_LiftHoldSeconds, n"OnServerLifted");
    }

    UFUNCTION()
    private void OnServerLifted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStep(2);
        End_HeatServer(f"reportedCoat={Get_HeatStationReport().Coat} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Report = Get_HeatStationReport();
        const auto DipDepth = float64(_Batter.Get_Spec().Bowl.DipDepthCm);
        if (InStep == 1)
        {
            Mark_Time("step1");
            Assert_True(_DippedFrames > 0, f"the client sampled its bowl Dipped with its copy in it ({_DippedFrames} frames)");
            Assert_True(_DippedErrorCm >= 0.0 && _DippedErrorCm <= constants_heat_station_net_autotest::k_OffsetToleranceCm,
                f"the client's copy hung under its bowl at the dipped offset (off by {_DippedErrorCm} cm)");
            Assert_True(Math::Abs(_DippedDropCm - DipDepth) <= constants_heat_station_net_autotest::k_OffsetToleranceCm,
                f"the client's copy hung lower than at rest by the dip depth ({_DippedDropCm} cm of {DipDepth})");
            Assert_True(_DippedCoat <= Report.Coat && Report.Coat - _DippedCoat <= 0.1f,
                f"the client's coat was within 0.1 of the reported coat and not above it ({_DippedCoat} vs {Report.Coat})");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Ids = _Batter.Get_PieceIds();
        const auto Copy = Get_FollowedCopy(0);
        const auto Slot = Ids.Num() == 1 ? Get_SlotOf(Ids[0]) : -1;
        const auto RestErrorCm = Get_SlotErrorCm(Copy, Slot, 0.0f);
        const auto Coat = Ids.Num() == 1 ? _Batter.Get_PieceCoat(Ids[0]) : -1.0f;
        TArray<EMars_Batter_Bowl> Expected;
        Expected.Add(EMars_Batter_Bowl::Dipped);
        Expected.Add(EMars_Batter_Bowl::Resting);
        const auto IsExpected = _BowlChanges.Num() == 2 && _BowlChanges[0] == Expected[0] && _BowlChanges[1] == Expected[1];
        const auto DipFrames = _BowlChangeFrames.Num() > 0 ? _BowlChangeFrames[0] - int64(Report.EventFrame) : int64(-1);

        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting, f"the client's bowl is Resting ({Describe_BatterLedger()})");
        Assert_True(RestErrorCm >= 0.0 && RestErrorCm <= constants_heat_station_net_autotest::k_OffsetToleranceCm,
            f"the client's copy is back at rest under its bowl (off by {RestErrorCm} cm)");
        Assert_True(Coat >= _DippedCoat, f"the client's coat did not fall ({Coat} after {_DippedCoat})");
        Assert_True(IsExpected, f"the client raised OnBowlChanged Dipped then Resting, each once ({Describe_BatterRecord()})");
        Assert_True(Get_SawLabelAtAnyStep("dipping"), f"the client's label said dipping in some sampled frame ({Describe_Seen(_LabelsSeen)})");
        End_HeatClient(f"dippedFrames={_DippedFrames} dippedErrorCm={_DippedErrorCm} dippedDropCm={_DippedDropCm} restErrorCm={RestErrorCm} reportedCoat={Report.Coat} dippedCoat={_DippedCoat} coatLag={Report.Coat - _DippedCoat} finalCoat={Coat} dipToClientFrames={DipFrames} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
