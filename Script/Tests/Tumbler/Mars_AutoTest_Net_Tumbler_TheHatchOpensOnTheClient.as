// The real tumbler station, nobody operating. The server looks its cursor away from the shut hatch's tab (where it starts)
// and once nothing is hovered reports (step 1). It points at the hatch and presses; once the hatch is Open it reports
// (step 2). The open hatch's tab stands elsewhere, so it points at it again and presses; once the hatch is Closed it reports
// (step 3). The client clears its record at step 1. At step 2 its kernel reads Open, its hinge Mover's alpha is within 0.02
// of 1, and since step 1 it raised OnHatchChanged Open once and OnHoverChanged Hatch once. It clears its record again. At
// step 3 it reads Closed, its hinge within 0.02 of 0, and since step 2 it raised OnHatchChanged Closed once (Closing may be
// merged into it) and OnHoverChanged Hatch once (the second pointing). Each report carries the frame of the press before
// it; the client logs the frames from that press to its hinge at its end.
// Surface: Ck.Tumbler.Net.AS_Tumbler_TheHatchOpensOnTheClient
class UCk_AutoTest_Net_Tumbler_TheHatchOpensOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 380000.0;
    private const float32 k_HingeTolerance = 0.02f;

    // Client: what each step measured.
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
        Point_AwayThen(EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerAway");
    }

    UFUNCTION()
    private void OnServerAway(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerAwayGap");
    }

    UFUNCTION()
    private void OnServerAwayGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointedShut");
    }

    UFUNCTION()
    private void OnServerPointedShut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("open");
        _EventFrame = utils_time::Get_FrameCounter();
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
        Mark_Time("step2");
        Report_HeatStep(2);
        WaitSeconds(k_StepGapSeconds, n"OnServerOpenGap");
    }

    UFUNCTION()
    private void OnServerOpenGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointedOpen");
    }

    UFUNCTION()
    private void OnServerPointedOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("close");
        _EventFrame = utils_time::Get_FrameCounter();
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        WaitUntil(n"Is_ServerClosed", n"OnServerClosed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Closed);
    }

    UFUNCTION()
    private void OnServerClosed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step3");
        Report_HeatStep(3);
        End_HeatServer(f"{Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        if (InStep == 1)
        {
            _StepLog += f"step1=[{Describe_TumblerRecord()}] ";
            Clear_TumblerRecord();
            Await_Step(2);
            return;
        }

        const auto Report = Get_HeatStationReport();
        const auto Hinge = Get_HingeMover().Get_Alpha();
        if (InStep == 2)
        {
            const auto EndFrame = Find_HingeFrame(int64(Report.EventFrame), 1.0f);
            _StepLog += f"step2=[pressFrame={Report.EventFrame} hingeOpenFrame={EndFrame} frames={EndFrame - int64(Report.EventFrame)} hinge={Hinge} {Describe_TumblerRecord()}] ";
            Assert_True(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Open, f"at step 2 the client's kernel reads Open ({Describe_Tumbler()} {Describe_TumblerLedger()})");
            Assert_True(Math::Abs(Hinge - 1.0f) <= k_HingeTolerance, f"at step 2 the client's hinge Mover is open (alpha {Hinge})");
            Assert_Equals_Int(Get_HatchChangeCount(EMars_Tumbler_Hatch::Open), 1, f"the client raised OnHatchChanged Open once ({Describe_TumblerRecord()})");
            Assert_Equals_Int(Get_HoverChangeCount(EMars_Tumbler_Target::Hatch), 1, f"the client raised OnHoverChanged Hatch once ({Describe_TumblerRecord()})");
            Clear_TumblerRecord();
            Await_Step(3);
            return;
        }

        const auto EndFrame = Find_HingeFrame(int64(Report.EventFrame), 0.0f);
        _StepLog += f"step3=[pressFrame={Report.EventFrame} hingeShutFrame={EndFrame} frames={EndFrame - int64(Report.EventFrame)} hinge={Hinge} {Describe_TumblerRecord()}]";
        Assert_True(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Closed, f"at step 3 the client's kernel reads Closed ({Describe_Tumbler()} {Describe_TumblerLedger()})");
        Assert_True(Math::Abs(Hinge) <= k_HingeTolerance, f"at step 3 the client's hinge Mover is shut (alpha {Hinge})");
        Assert_Equals_Int(Get_HatchChangeCount(EMars_Tumbler_Hatch::Closed), 1, f"the client raised OnHatchChanged Closed once ({Describe_TumblerRecord()})");
        Assert_Equals_Int(Get_HoverChangeCount(EMars_Tumbler_Target::Hatch), 1, f"the client raised OnHoverChanged Hatch once for the second pointing ({Describe_TumblerRecord()})");
        End_HeatClient(f"{_StepLog} {Describe_Tumbler()} {Describe_TumblerLedger()}");
    }
}
