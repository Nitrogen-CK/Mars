// The real searing station, the subject seated on the server. Half a second later the server applies one remote look of 12
// degrees up that took 0.1 s on the sender: it arrives in one frame but is slower than the pan's flick speed. Watching one
// second, the server's pan lift stays under 0.3, its command's kick total is 0 and its pan pitches more than 5 degrees; it
// reports (step 1). On the client its pan's lift stayed under 0.5 in every sampled frame and its pan pitched more than 3
// degrees.
// Surface: Ck.Searing.Net.AS_Searing_ASlowLookThatArrivesTogetherDoesNotToss
class UCk_AutoTest_Net_Searing_ASlowLookThatArrivesTogetherDoesNotToss : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 342000.0;
    private const float32 k_HotSeconds = 0.5f;
    private const float64 k_LookDegrees = 12.0;
    private const float32 k_LookSeconds = 0.1f;
    private const float32 k_WatchSeconds = 1.0f;

    // Either machine: the largest lift and pitch this machine's pan showed.
    private float32 _PeakLift = 0.0f;
    private float32 _PeakPitch = 0.0f;

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

    protected void On_HeatStationSample() override
    {
        _PeakLift = Math::Max(_PeakLift, _Searing.Get_PanLift());
        _PeakPitch = Math::Max(_PeakPitch, float32(Math::Abs(_Searing.Get_PanTilt().Pitch)));
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
        WaitSeconds(k_HotSeconds, n"OnServerHot");
    }

    UFUNCTION()
    private void OnServerHot(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("look");
        _PeakLift = 0.0f;
        _PeakPitch = 0.0f;
        Look_Remote(FVector(0.0, -k_LookDegrees, 0.0), k_LookSeconds);
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        const auto KickTotal = _Searing.Get_Pan().Get_Command().KickTotal;
        Assert_True(_PeakLift < 0.3f, f"the server's pan lift stayed under 0.3 (peak {_PeakLift})");
        Assert_True(KickTotal == 0.0f, f"the server's pan command's kick total is 0 (got {KickTotal})");
        Assert_True(_PeakPitch > 5.0f, f"the server's pan pitched more than 5 degrees (peak {_PeakPitch})");
        Report_HeatStep(1);
        End_HeatServer(f"peakLift={_PeakLift} peakPitch={_PeakPitch} kickTotal={KickTotal} {Describe_Pan()} {Describe_SearingLedger()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        Assert_True(_PeakLift < 0.5f, f"the client's pan lift stayed under 0.5 in every sampled frame (peak {_PeakLift})");
        Assert_True(_PeakPitch > 3.0f, f"the client's pan pitched more than 3 degrees (peak {_PeakPitch})");
        End_HeatClient(f"peakLift={_PeakLift} peakPitch={_PeakPitch} ledgerKick={_Searing.Get_PanLedger().Pan.KickTotal} {Describe_Pan()}");
    }
}
