// The real searing station, the subject seated on the server. For one second, every frame, the server applies a remote look
// of 3 degrees right over that frame's seconds, then reports its pan's roll (step 1). On the client its station reads the
// subject operating, its pan's largest roll is within 3 degrees of the reported roll and above 20, and no frame's roll step
// is larger than the pan's tilt rate times that frame plus 1 degree.
// Surface: Ck.Searing.Net.AS_Searing_ARemoteOperatorsLookTiltsThePanOnBothMachines
class UCk_AutoTest_Net_Searing_ARemoteOperatorsLookTiltsThePanOnBothMachines : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 340000.0;
    private const float32 k_LookForSeconds = 1.0f;
    private const float64 k_LookDegrees = 3.0;

    // Server: whether it looks this frame, and the last frame it did.
    private bool _IsLooking = false;
    private int64 _LastLookFrame = -1;
    private int32 _Looks = 0;

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
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("seated");
        _IsLooking = true;
        WaitSeconds(k_LookForSeconds, n"OnServerLooked");
    }

    protected void On_HeatStationSample() override
    {
        if (Get_IsServer() == false || _IsLooking == false)
        { return; }

        const auto Frame = utils_time::Get_FrameCounter();
        if (Frame == _LastLookFrame)
        { return; }

        _LastLookFrame = Frame;
        ++_Looks;
        Look_Remote(FVector(k_LookDegrees, 0.0, 0.0), float32(Gameplay::GetWorldDeltaSeconds()));
    }

    UFUNCTION()
    private void OnServerLooked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _IsLooking = false;
        Mark_Time("step1");
        _ReportValue = float32(_Searing.Get_PanTilt().Roll);
        Report_HeatStep(1);
        End_HeatServer(f"looks={_Looks} roll={_ReportValue} {Describe_Pan()} {Describe_SearingLedger()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Rate = _Searing.Get_Pan().Get_Spec().Tilt.MaxTiltRateDegreesPerSecond;
        auto PeakRoll = 0.0f;
        auto WorstStepExcess = -1000.0f;
        auto LastFrame = int64(-1);
        auto PrevIndex = -1;
        for (int32 Index = 0; Index < _PanSamples.Num(); ++Index)
        {
            const auto& Sample = _PanSamples[Index];
            PeakRoll = Math::Max(PeakRoll, Sample.Roll);
            // The sampler runs twice a frame at one game time: compare the first samples of successive frames.
            if (Sample.Frame == LastFrame)
            { continue; }

            LastFrame = Sample.Frame;
            if (PrevIndex >= 0)
            {
                const auto& Prev = _PanSamples[PrevIndex];
                const auto Allowed = Rate * float32(Sample.Seconds - Prev.Seconds) + 1.0f;
                WorstStepExcess = Math::Max(WorstStepExcess, Math::Abs(Sample.Roll - Prev.Roll) - Allowed);
            }

            PrevIndex = Index;
        }

        const auto Report = Get_HeatStationReport();
        const auto RollError = Math::Abs(PeakRoll - Report.Value);
        Assert_True(Get_IsSubjectOperating(), "the client's station reads the subject operating");
        Assert_True(RollError <= 3.0f, f"the client's pan rolled as far as the server's (client peak {PeakRoll}, server {Report.Value})");
        Assert_True(PeakRoll > 20.0f, f"the client's pan rolled above 20 degrees (peak {PeakRoll})");
        Assert_True(WorstStepExcess < 0.0f, f"no frame's roll step beat the tilt rate plus 1 degree (worst excess {WorstStepExcess})");
        End_HeatClient(f"peakRoll={PeakRoll} serverRoll={Report.Value} rollError={RollError} worstStepExcess={WorstStepExcess} samples={_PanSamples.Num()} {Describe_Pan()}");
    }
}
