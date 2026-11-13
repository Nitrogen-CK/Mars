// The timing window's pass is 4 s. The server engages its mortar directly, waits 1 s, reports its sweep and its server
// seconds, and holds 2 s. Between two ledger arrivals the client's sweep rises by each frame's seconds (within 0.002 s,
// a wrap apart) over at least 30 sampled frames in a row, and at the report its sweep is within 0.15 s of the reported
// sweep carried on by its own server seconds.
// Surface: Ck.Mortar.Net.AS_Mortar_TheTimingBarRunsOnTheClientFromTheAnchor
class UCk_AutoTest_Net_Mortar_TheTimingBarRunsOnTheClientFromTheAnchor : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 442000.0;
    private const float32 k_SweepSeconds = 4.0f;
    private const float32 k_StepTolerance = 0.002f;
    private const float32 k_AnchorTolerance = 0.15f;
    private const int32 k_RunFrames = 30;

    // Client: per sampled frame, its sweep, the frame's seconds and the ledger's anchor, while engaged in the Crush phase.
    private TArray<float32> _Sweeps;
    private TArray<float32> _Deltas;
    private TArray<float64> _Anchors;

    protected void Configure_Spec(FMars_Mortar_Spec& InOutSpec) override
    {
        InOutSpec.Timing.SweepSeconds = k_SweepSeconds;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    protected void On_ServerStationReady() override
    {
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
        WaitSeconds(1.0f, n"OnServerRan");
    }

    UFUNCTION()
    private void OnServerRan(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Step = FMars_TESTONLY_NetMinigameStep(1);
        Step.Value = _Mortar.Get_SweepSeconds();
        Step.Seconds = utils_mars_net::Get_ServerWorldSeconds(_Mortar);
        Report_Step(Step);
        WaitSeconds(2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_MinigameServer(Describe_Mortar());
    }

    protected void On_Sample(float32 InDeltaSeconds) override
    {
        if (Get_IsServer() || ck::Is_NOT_Valid(_Mortar) || _Mortar.Get_IsEngaged() == false
            || _Mortar.Get_Batch().Phase != EMars_Mortar_Phase::Crush)
        { return; }

        _Sweeps.Add(_Mortar.Get_SweepSeconds());
        _Deltas.Add(InDeltaSeconds);
        _Anchors.Add(_Mortar.Get_Ledger().AnchorServerSeconds);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        // A frame is sampled before or after its tick: a step between two first samples is the tick of one of the two
        // frames, so it is held to either frame's seconds.
        auto Run = 0;
        auto LongestRun = 0;
        auto Bad = 0;
        auto WorstError = 0.0f;
        for (int32 Index = 1; Index < _Sweeps.Num(); ++Index)
        {
            if (_Anchors[Index] != _Anchors[Index - 1])
            {
                Run = 0;
                continue;
            }

            auto Rise = _Sweeps[Index] - _Sweeps[Index - 1];
            if (Rise < -0.5f * k_SweepSeconds)
            { Rise += k_SweepSeconds; }

            const auto Error = Math::Min(Math::Abs(Rise - _Deltas[Index - 1]), Math::Abs(Rise - _Deltas[Index]));
            WorstError = Math::Max(WorstError, Error);
            if (Error > k_StepTolerance)
            {
                ++Bad;
                Run = 0;
                continue;
            }

            ++Run;
            LongestRun = Math::Max(LongestRun, Run);
        }

        const auto Report = Get_Report();
        const auto ServerNow = utils_mars_net::Get_ServerWorldSeconds(_Mortar);
        const auto Expected = utils_mortar::Get_WrappedSweep(Report.Value + float32(ServerNow - Report.Seconds), _MortarSpec.Timing);
        auto AnchorError = Math::Abs(_Mortar.Get_SweepSeconds() - Expected);
        AnchorError = Math::Min(AnchorError, k_SweepSeconds - AnchorError);

        Assert_True(LongestRun >= k_RunFrames, f"the client's sweep rose by each frame's seconds over {k_RunFrames} frames in a row between ledgers (longest {LongestRun})");
        Assert_Equals_Int(Bad, 0, f"no step of the client's sweep between ledgers missed the frame's seconds (worst error {WorstError})");
        Assert_True(AnchorError <= k_AnchorTolerance, f"the client's sweep is within {k_AnchorTolerance} s of the server's carried on (error {AnchorError})");
        End_MinigameClient(f"longestRun={LongestRun} bad={Bad} worstStepError={WorstError} anchorError={AnchorError} "
            + f"reportAge={ServerNow - Report.Seconds} samples={_Sweeps.Num()} {Describe_Mortar()}");
    }
}
