// The real searing station, nobody operating. The server admits the slab on a cold pan and, once it is on the books,
// reports (step 1); it heats the pan, for a second looks 3 degrees right a frame on its own kernel, and reports again (step
// 2). At step 1 the client's kernel names that one id, raised OnPieceAdded for it once, reads it Cooking and gives this
// machine's copy as its entity. After step 2 its label is not "cold" and reads "0/1 ready". Between the steps it counts
// the sampled frames in which its copy's location changed and the largest change (more than five changes), and logs them
// with the seconds they cover and both machines' mean frame seconds.
// Surface: Ck.Searing.Net.AS_Searing_AnAdmittedPieceIsOnTheClientsBooks
class UCk_AutoTest_Net_Searing_AnAdmittedPieceIsOnTheClientsBooks : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 322000.0;
    private const float32 k_LookSeconds = 1.0f;
    private const float64 k_LookDegrees = 3.0;
    // A change smaller than this (cm) is not a change of pose.
    private const float64 k_MovedCm = 0.001;

    private FMars_CookingFeed_PieceId _Id;

    // Server.
    private float64 _LookStartSeconds = -1.0;
    private int32 _LookFrames = 0;
    private int64 _LastLookFrame = -1;
    private int64 _LastSampleFrame = -1;

    // Client: its copy's location between the steps.
    private TOptional<FVector> _LastCopyLocation;
    private int32 _PoseChanges = 0;
    private int32 _BetweenFrames = 0;
    private float64 _LargestChangeCm = 0.0;
    private float32 _BetweenSeconds = 0.0f;
    // Of those, the frames while its pan read hot (the server's looks).
    private int32 _HotFrames = 0;
    private int32 _HotPoseChanges = 0;
    private float64 _HotLargestChangeCm = 0.0;
    private float32 _HotSeconds = 0.0f;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Searing;
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
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerOnBooks", n"OnServerOnBooks", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOnBooks(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_HasPiece(_Id));
    }

    UFUNCTION()
    private void OnServerOnBooks(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    // The client reads step 1 before the pan moves.
    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
        WaitUntil(n"Is_ServerLooked", n"OnServerLooked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLooked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Now = System::GetGameTimeInSeconds();
        if (_LookStartSeconds < 0.0)
        { _LookStartSeconds = Now; }

        const auto IsDone = Now - _LookStartSeconds >= k_LookSeconds;
        // A frame can be polled twice: one look per frame.
        const auto Frame = utils_time::Get_FrameCounter();
        if (IsDone == false && Frame != _LastLookFrame)
        {
            _LastLookFrame = Frame;
            _Searing.Request_Look(FMars_Request_Searing_Look(FVector(k_LookDegrees, 0.0, 0.0)));
            ++_LookFrames;
        }

        auto Result = OutResult;
        Result.Set(IsDone);
    }

    // The report's number is the server's mean frame seconds over the looks.
    UFUNCTION()
    private void OnServerLooked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        _ReportValue = _LookFrames > 0 ? k_LookSeconds / float32(_LookFrames) : 0.0f;
        Report_HeatStep(2);
        End_HeatServer(f"lookFrames={_LookFrames} meanFrameSeconds={_ReportValue} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_HeatStationSample() override
    {
        if (Get_IsServer() || _PanSamples.Num() == 0 || _PanSamples.Last().Step != 1)
        { return; }

        const auto Copy = Get_FollowedCopy(0);
        if (Get_IsLive(Copy) == false)
        { return; }

        // A frame can be sampled twice, before and after its tick (at one game time): changes are counted between the
        // first samples of two frames.
        FCk_Handle Entity = Copy;
        const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
        const auto Frame = _PanSamples.Last().Frame;
        const auto IsNewFrame = Frame != _LastSampleFrame;
        _LastSampleFrame = Frame;
        _BetweenSeconds += _PanSamples.Last().DeltaSeconds;
        if (IsNewFrame)
        { ++_BetweenFrames; }

        if (IsNewFrame && _LastCopyLocation.IsSet())
        {
            const auto Change = Location.Distance(_LastCopyLocation.GetValue());
            const auto IsHot = _PanSamples.Last().Heat == EMars_Searing_Heat::Hot;
            if (IsHot)
            {
                ++_HotFrames;
                _HotSeconds += _PanSamples.Last().DeltaSeconds;
            }

            if (Change > k_MovedCm)
            {
                ++_PoseChanges;
                _LargestChangeCm = Math::Max(_LargestChangeCm, Change);
                if (IsHot)
                {
                    ++_HotPoseChanges;
                    _HotLargestChangeCm = Math::Max(_HotLargestChangeCm, Change);
                }
            }
        }

        if (IsNewFrame)
        { _LastCopyLocation = TOptional<FVector>(Location); }
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            const auto Ids = _Searing.Get_PieceIds();
            const auto Report = Get_HeatStationReport();
            _Id = Report.BowlIds.Num() > 0 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();
            const auto Copy = Get_FollowedCopy(0);
            Assert_True(Ids.Num() == 1 && Ids[0].Get_IsSame(_Id), f"the client's kernel names the one admitted id ({Describe_SearingLedger()})");
            Assert_Equals_Int(Get_PanAddedCount(_Id), 1, f"the client raised OnPieceAdded for it once ({Describe_SearingRecord()})");
            Assert_True(_Searing.Get_HasPiece(_Id) && _Searing.Get_PieceStatus(_Id) == EMars_Searing_PieceStatus::Cooking, "the client reads it Cooking");
            Assert_True(Get_IsLive(Copy) && _Searing.Get_HasPiece(_Id) && _Searing.Get_PieceEntity(_Id) == Copy, "the client's kernel gives its own copy as the piece");
            Log_HeatStation(f"step 1: {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Label = Get_ShownLabel();
        const auto LabelLine = Label.Replace("\n", " / ");
        const auto ClientFrameSeconds = _BetweenFrames > 0 ? _BetweenSeconds / float32(_BetweenFrames) : 0.0f;
        const auto Measured = f"poseChanges={_PoseChanges} largestChangeCm={_LargestChangeCm} frames={_BetweenFrames} seconds={_BetweenSeconds} "
            + f"hot: poseChanges={_HotPoseChanges} largestChangeCm={_HotLargestChangeCm} frames={_HotFrames} seconds={_HotSeconds} "
            + f"clientFrameSeconds={ClientFrameSeconds} serverFrameSeconds={Get_HeatStationReport().Value}";
        Log_HeatStation(f"pose arrival: {Measured}");
        Assert_False(Label.Contains("cold"), f"after step 2 the client's label is not cold ('{LabelLine}')");
        Assert_True(Label.Contains("0/1 ready"), f"after step 2 the client's label reads 0/1 ready ('{LabelLine}')");
        Assert_True(_PoseChanges > 5, f"the client's copy moved in more than five sampled frames between the steps ({Measured})");
        End_HeatClient(f"{Measured} label='{LabelLine}'{Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
