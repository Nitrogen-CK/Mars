// The real searing station, nobody operating. The server heats the pan and for a second looks 3 degrees right a frame on its
// own kernel, then reports its pan's roll (step 1); it stops, and 1.5 s later reports again (step 2). On the client, in the
// frame step 1 arrived, its pan's roll is within 3 degrees of the reported one and above 20; at step 2 it is under 1; its
// pan implement is Followed; its roll never moves faster in one frame than the spec's rate allows (plus 1 degree); and its
// pan node moved more than 1 cm sideways while hot (the swirl).
// Surface: Ck.Searing.Net.AS_Searing_ThePanFollowsTheAuthorityOnTheClient
class UCk_AutoTest_Net_Searing_ThePanFollowsTheAuthorityOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 320000.0;
    private const float32 k_LookSeconds = 1.0f;
    private const float32 k_LevelSeconds = 1.5f;
    private const float64 k_LookDegrees = 3.0;

    // Server.
    private float64 _LookStartSeconds = -1.0;
    private int32 _Looks = 0;
    private int64 _LastLookFrame = -1;

    // Client: its roll in the frame each step first arrived.
    private TOptional<float32> _RollAtStep1;
    private TOptional<float32> _ReportedAtStep1;

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
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
        WaitUntil(n"Is_ServerLooked", n"OnServerLooked", k_SlowPolls);
    }

    // One look a frame for k_LookSeconds.
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
            ++_Looks;
        }

        auto Result = OutResult;
        Result.Set(IsDone);
    }

    UFUNCTION()
    private void OnServerLooked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        _ReportValue = float32(_Searing.Get_PanTilt().Roll);
        Report_HeatStep(1);
        Log_HeatStation(f"step 1: looks={_Looks} {Describe_Pan()} {Describe_SearingLedger()}");
        WaitSeconds(k_LevelSeconds, n"OnServerLevelled");
    }

    UFUNCTION()
    private void OnServerLevelled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        _ReportValue = float32(_Searing.Get_PanTilt().Roll);
        Report_HeatStep(2);
        End_HeatServer(f"{Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_HeatStationSample() override
    {
        if (Get_IsServer() || _RollAtStep1.IsSet() || _PanSamples.Num() == 0)
        { return; }

        const auto Report = Get_HeatStationReport();
        if (Report.Step < 1)
        { return; }

        _RollAtStep1 = TOptional<float32>(_PanSamples.Last().Roll);
        _ReportedAtStep1 = TOptional<float32>(Report.Value);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            const auto Roll = _RollAtStep1.IsSet() ? _RollAtStep1.GetValue() : -1000.0f;
            const auto Reported = _ReportedAtStep1.IsSet() ? _ReportedAtStep1.GetValue() : 1000.0f;
            Log_HeatStation(f"step 1: roll at arrival {Roll} reported {Reported} {Describe_Pan()} {Describe_SearingLedger()}");
            Assert_True(Math::Abs(Roll - Reported) <= 3.0f, f"at step 1 the client's roll is within 3 of the server's (client {Roll}, server {Reported})");
            Assert_True(Roll > 20.0f, f"at step 1 the client's pan rolled above 20 (got {Roll})");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Pan = _Searing.Get_Pan();
        const auto Roll = float32(Pan.Get_Tilt().Roll);
        const auto Rate = Pan.Get_Spec().Tilt.MaxTiltRateDegreesPerSecond;
        auto WorstExcess = -1000.0f;
        auto LargestStep = 0.0f;
        auto LargestSideways = 0.0;
        FString WorstAt = "";
        TOptional<FVector> FirstHot;
        // A frame can be sampled twice, before and after the pan's tick (at one game time): a step is measured between the
        // first samples of two frames, one tick and one frame time apart.
        auto Previous = 0;
        for (int32 Index = 1; Index < _PanSamples.Num(); ++Index)
        {
            const auto Sample = _PanSamples[Index];
            const auto Before = _PanSamples[Previous];
            if (Sample.Frame != Before.Frame)
            {
                const auto Step = Math::Abs(Sample.Roll - Before.Roll);
                const auto StepSeconds = float32(Sample.Seconds - Before.Seconds);
                LargestStep = Math::Max(LargestStep, Step);
                const auto Excess = Step - Rate * StepSeconds;
                if (Excess > WorstExcess)
                {
                    WorstExcess = Excess;
                    WorstAt = f"sample {Index}/{_PanSamples.Num()} step={Sample.Step} roll {Before.Roll}->{Sample.Roll} dt={StepSeconds} frames={Sample.Frame - Before.Frame}";
                }

                Previous = Index;
            }

            if (Sample.Heat != EMars_Searing_Heat::Hot)
            { continue; }

            if (FirstHot.IsSet() == false)
            { FirstHot = TOptional<FVector>(Sample.NodeLocation); }

            LargestSideways = Math::Max(LargestSideways, (Sample.NodeLocation - FirstHot.GetValue()).Size2D());
        }

        Assert_True(Math::Abs(Roll) < 1.0f, f"at step 2 the client's pan is level again (roll {Roll}, server {Get_HeatStationReport().Value})");
        Assert_True(Pan.Get_Steering() == EMars_Implement_Steering::Followed, "the client's pan implement is Followed");
        Assert_True(WorstExcess < 1.0f, f"the client's roll never outran its rate by a degree in a frame (worst excess {WorstExcess} at {WorstAt}, largest step {LargestStep})");
        Assert_True(LargestSideways > 1.0, f"the client's pan node moved more than 1 cm sideways while hot (got {LargestSideways})");
        const auto RollAtStep1 = _RollAtStep1.IsSet() ? _RollAtStep1.GetValue() : -1000.0f;
        const auto ReportedAtStep1 = _ReportedAtStep1.IsSet() ? _ReportedAtStep1.GetValue() : 1000.0f;
        End_HeatClient(f"rollAtStep1={RollAtStep1} reportedAtStep1={ReportedAtStep1} errorAtStep1={Math::Abs(RollAtStep1 - ReportedAtStep1)} "
            + f"rollAtStep2={Roll} worstExcess={WorstExcess} worstAt=[{WorstAt}] largestStep={LargestStep} sideways={LargestSideways} samples={_PanSamples.Num()} {Describe_Pan()} {Describe_SearingLedger()}");
    }
}
