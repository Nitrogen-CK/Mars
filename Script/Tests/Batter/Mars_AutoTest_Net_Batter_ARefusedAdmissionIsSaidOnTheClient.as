// A meat slab is cut in half beside the real batter station and the server admits the positive half: the bowl refuses it
// NotWhole (the server raises OnAdmissionRefused once, NotWhole). One second later it reports (step 1). The client raised
// OnAdmissionRefused once, NotWhole; its ledger counts one admission refusal; its bowl has no row; its label said "whole
// ingredients only" in some sampled frame.
// Surface: Ck.Batter.Net.AS_Batter_ARefusedAdmissionIsSaidOnTheClient
class UCk_AutoTest_Net_Batter_ARefusedAdmissionIsSaidOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 303000.0;
    private const float32 k_AnswerSeconds = 1.0f;

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
        Spawn_CutHalfThen(n"OnServerHalf");
    }

    UFUNCTION()
    private void OnServerHalf(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Admit(_CutHalf);
        WaitSeconds(k_AnswerSeconds, n"OnServerAnswered");
    }

    UFUNCTION()
    private void OnServerAnswered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_True(_AdmissionRefusals.Num() == 1 && _AdmissionRefusals[0] == EMars_Batter_AdmissionRefusal::NotWhole,
            f"the server refused the half once, NotWhole ({Describe_BatterRecord()})");
        End_HeatServer(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Ledger = _Batter.Get_Ledger();
        Assert_True(_AdmissionRefusals.Num() == 1 && _AdmissionRefusals[0] == EMars_Batter_AdmissionRefusal::NotWhole,
            f"the client raised OnAdmissionRefused once, NotWhole ({Describe_BatterRecord()})");
        Assert_Equals_Int(Ledger.AdmissionRefusalSerial, 1, "the client's ledger counts one admission refusal");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, "the client's bowl has no row");
        Assert_True(Get_SawLabelAtAnyStep("whole ingredients only"), f"the client's label said whole ingredients only ({Describe_Seen(_LabelsSeen)})");
        End_HeatClient(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
