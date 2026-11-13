// The real searing station, nobody operating. The server heats the pan, half a second later looks 25 degrees up in one frame
// on its own kernel (a toss), and once its pan's lift has risen above 1 uu and settled reports its pan command's kick
// total (step 1). On the client its pan's lift rose above 1 and came back under 0.5, crossing 1 upward exactly once, and its
// pan ledger's kick total is the reported one.
// Surface: Ck.Searing.Net.AS_Searing_ATossShowsOnTheClient
class UCk_AutoTest_Net_Searing_ATossShowsOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 321000.0;
    private const float32 k_HeatSeconds = 0.5f;
    private const float64 k_TossDegrees = 25.0;

    // Server.
    private bool _ServerRose = false;
    private float32 _ServerPeakLift = 0.0f;

    // Client: the frame its lift first rose above 1 uu.
    private int64 _ClientRiseFrame = -1;

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
        WaitSeconds(k_HeatSeconds, n"OnServerHot");
    }

    UFUNCTION()
    private void OnServerHot(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EventFrame = utils_time::Get_FrameCounter();
        _Searing.Request_Look(FMars_Request_Searing_Look(FVector(0.0, -k_TossDegrees, 0.0)));
        WaitUntil(n"Is_ServerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Pan = _Searing.Get_Pan();
        const auto Lift = Pan.Get_Lift();
        _ServerPeakLift = Math::Max(_ServerPeakLift, Lift);
        if (Lift > 1.0f)
        { _ServerRose = true; }

        auto Result = OutResult;
        Result.Set(_ServerRose && Math::Abs(Lift) < 0.05f && Math::Abs(Pan.Get_LiftVelocity()) < 0.5f);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        _ReportValue = _Searing.Get_Pan().Get_Command().KickTotal;
        Report_HeatStep(1);
        End_HeatServer(f"peakLift={_ServerPeakLift} kickFrame={_EventFrame} kickTotal={_ReportValue} {Describe_Pan()} {Describe_SearingLedger()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_HeatStationSample() override
    {
        if (Get_IsServer() || _ClientRiseFrame >= 0 || _PanSamples.Num() == 0)
        { return; }

        if (_PanSamples.Last().Lift > 1.0f)
        { _ClientRiseFrame = utils_time::Get_FrameCounter(); }
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        auto PeakLift = 0.0f;
        auto UpwardCrossings = 0;
        for (int32 Index = 1; Index < _PanSamples.Num(); ++Index)
        {
            PeakLift = Math::Max(PeakLift, _PanSamples[Index].Lift);
            if (_PanSamples[Index - 1].Lift <= 1.0f && _PanSamples[Index].Lift > 1.0f)
            { ++UpwardCrossings; }
        }

        const auto Lift = _Searing.Get_PanLift();
        const auto Report = Get_HeatStationReport();
        const auto LedgerKick = _Searing.Get_PanLedger().Pan.KickTotal;
        const auto RiseFrames = _ClientRiseFrame >= 0 && Report.EventFrame >= 0 ? _ClientRiseFrame - int64(Report.EventFrame) : int64(-1);
        Assert_True(PeakLift > 1.0f, f"the client's pan lift rose above 1 (peak {PeakLift})");
        Assert_True(Math::Abs(Lift) < 0.5f, f"the client's pan lift came back under 0.5 (got {Lift})");
        Assert_Equals_Int(UpwardCrossings, 1, "the client's pan lift crossed 1 upward exactly once");
        Assert_True(LedgerKick == Report.Value, f"the client's pan ledger carries the server's kick total (ledger {LedgerKick}, server {Report.Value})");
        End_HeatClient(f"peakLift={PeakLift} crossings={UpwardCrossings} lift={Lift} ledgerKick={LedgerKick} serverKick={Report.Value} "
            + f"serverKickFrame={Report.EventFrame} clientRiseFrame={_ClientRiseFrame} kickToRiseFrames={RiseFrames} {Describe_Pan()}");
    }
}
