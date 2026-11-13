// The real tumbler station, nobody operating. The server looks its cursor away from the shut hatch's tab (where it starts);
// once nothing is hovered it presses and asks the station for a take-out naming no tray, and a second later reports (step
// 1): its kernel raised OnPressRefused once, NoTarget, and OnTakeOutRefused once. The client raised OnPressRefused once,
// NoTarget, and OnTakeOutRefused once, and its ledger's two refusal serials read 1.
// Surface: Ck.Tumbler.Net.AS_Tumbler_ARefusedPressAndARefusedTakeOutAreSaidOnTheClient
class UCk_AutoTest_Net_Tumbler_ARefusedPressAndARefusedTakeOutAreSaidOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 385000.0;
    private const float32 k_RefusedSeconds = 1.0f;

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
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        Request_TakeOutWithoutTray();
        WaitSeconds(k_RefusedSeconds, n"OnServerRefused");
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_True(_PressRefusals.Num() == 1 && _PressRefusals[0] == EMars_Tumbler_Refusal::NoTarget,
            f"the server refused the press once, NoTarget ({Describe_TumblerRecord()})");
        Assert_Equals_Int(_TumblerTakeOutRefusals.Num(), 1, f"the server refused the take-out once ({Describe_TumblerRecord()})");
        End_HeatServer(f"{Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Ledger = _Tumbler.Get_Ledger();
        Assert_True(_PressRefusals.Num() == 1 && _PressRefusals[0] == EMars_Tumbler_Refusal::NoTarget,
            f"the client raised OnPressRefused once, NoTarget ({Describe_TumblerRecord()})");
        Assert_Equals_Int(_TumblerTakeOutRefusals.Num(), 1, f"the client raised OnTakeOutRefused once ({Describe_TumblerRecord()})");
        Assert_True(Ledger.PressRefusalSerial == 1 && Ledger.TakeOutRefusalSerial == 1, f"the client's ledger's two refusal serials read 1 ({Describe_TumblerLedger()})");
        End_HeatClient(f"{Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
