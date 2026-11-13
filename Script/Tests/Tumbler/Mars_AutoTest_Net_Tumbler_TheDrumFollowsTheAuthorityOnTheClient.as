// The real tumbler station, nobody operating. The server points at the lever and presses; once it grips it, it rocks the
// lever for 1 s with one look a frame along the lever's pull and, once its axle Mover is still, reports its alpha (step 1)
// and logs its own largest alpha step in a frame. It lets go, and once its drum is Home reports the frame it let go (step 2). At step 1 the
// client's kernel reads the drum and the hand Gripped, its axle Mover's alpha is within 0.05 of the reported one and above
// 0.05, and its largest alpha step in a frame is under 0.2. At step 2 it reads Home, its alpha is under 0.01 and its axle
// Mover rests; the last OnDrumChanged it raised is Home and the last OnHandModeChanged Free. It logs the frames from the
// server's let-go to its own axle at rest, and whether its own lever ever held a manipulation.
// Surface: Ck.Tumbler.Net.AS_Tumbler_TheDrumFollowsTheAuthorityOnTheClient
class UCk_AutoTest_Net_Tumbler_TheDrumFollowsTheAuthorityOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 381000.0;
    private const float32 k_AlphaTolerance = 0.05f;
    private const float32 k_MinAlpha = 0.05f;
    private const float32 k_MaxFrameStep = 0.2f;
    private const float32 k_HomeAlpha = 0.01f;

    // Client: what step 1 measured.
    private FString _StepLog;

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
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Point_AtThen(EMars_Tumbler_Target::Lever, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointed");
    }

    UFUNCTION()
    private void OnServerPointed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("press");
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        WaitUntil(n"Is_ServerGripped", n"OnServerGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Gripped && _Tumbler.Get_Drum() == EMars_Tumbler_Drum::Gripped);
    }

    UFUNCTION()
    private void OnServerGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("rock");
        auto Rock = FMars_TESTONLY_NetTumblerRock();
        Rock.Seconds = 1.0f;
        Rock.Degrees = 0.5;
        Rock.Look = EMars_TESTONLY_NetTumblerLook::Kernel;
        Rock_LeverThen(Rock, n"OnServerRocked");
    }

    // The lever's spring carries the drum on after the last look: the leader's measure is taken once it is still.
    UFUNCTION()
    private void OnServerRocked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("rocked");
        Await_AxleStillThen(n"OnServerAxleStill");
    }

    UFUNCTION()
    private void OnServerAxleStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        FString StepAt = "";
        const auto LargestStep = Get_LargestAxleStep(0, StepAt);
        _ReportValue = Get_AxleMover().Get_Alpha();
        Report_HeatStep(1);
        Log_HeatStation(f"step1 alpha={_ReportValue} largestStep={LargestStep} at=[{StepAt}]");
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("release");
        _EventFrame = utils_time::Get_FrameCounter();
        _Tumbler.Request_Release(FMars_Request_Tumbler_Release());
        WaitUntil(n"Is_ServerHome", n"OnServerHome", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home);
    }

    UFUNCTION()
    private void OnServerHome(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        const auto HomeFrame = Find_AxleHomeFrame(_EventFrame);
        Report_HeatStep(2);
        End_HeatServer(f"releaseFrame={_EventFrame} homeFrame={HomeFrame} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        const auto Report = Get_HeatStationReport();
        const auto Alpha = Get_AxleMover().Get_Alpha();
        if (InStep == 1)
        {
            FString StepAt = "";
            const auto LargestStep = Get_LargestAxleStep(0, StepAt);
            const auto Error = Math::Abs(Alpha - Report.Value);
            _StepLog += f"step1=[alpha={Alpha} reported={Report.Value} error={Error} largestStep={LargestStep} at=[{StepAt}]] ";
            Assert_True(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Gripped, f"at step 1 the client's drum reads Gripped ({Describe_Tumbler()} {Describe_TumblerLedger()})");
            Assert_True(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Gripped, f"at step 1 the client's hand reads Gripped ({Describe_Tumbler()})");
            Assert_True(Error <= k_AlphaTolerance, f"the client's axle follows the server's (client {Alpha}, server {Report.Value})");
            Assert_True(Alpha > k_MinAlpha, f"the client's axle turned (alpha {Alpha})");
            Assert_True(LargestStep < k_MaxFrameStep, f"the client's axle never jumped 0.2 in a frame (largest {LargestStep} at {StepAt})");
            Await_Step(2);
            return;
        }

        const auto HomeFrame = Find_AxleHomeFrame(int64(Report.EventFrame));
        const auto IsResting = Get_AxleMover().Get_IsResting();
        const auto LastDrum = _DrumChanges.Num() > 0 ? _DrumChanges.Last() : EMars_Tumbler_Drum::Gripped;
        const auto LastMode = _HandModeChanges.Num() > 0 ? _HandModeChanges.Last() : EMars_Tumbler_HandMode::Gripped;
        _StepLog += f"step2=[alpha={Alpha} resting={IsResting} releaseFrame={Report.EventFrame} homeFrame={HomeFrame} frames={HomeFrame - int64(Report.EventFrame)} "
            + f"localManipulation={Get_SawLocalManipulation(0)}]";
        Assert_True(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home, f"at step 2 the client's drum reads Home ({Describe_Tumbler()} {Describe_TumblerLedger()})");
        Assert_True(Alpha < k_HomeAlpha, f"the client's axle is home (alpha {Alpha})");
        Assert_True(IsResting, f"the client's axle Mover rests ({Describe_Tumbler()})");
        Assert_True(LastDrum == EMars_Tumbler_Drum::Home, f"the client's last OnDrumChanged is Home ({Describe_TumblerRecord()})");
        Assert_True(LastMode == EMars_Tumbler_HandMode::Free, f"the client's last OnHandModeChanged is Free ({Describe_TumblerRecord()})");
        End_HeatClient(f"{_StepLog} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
