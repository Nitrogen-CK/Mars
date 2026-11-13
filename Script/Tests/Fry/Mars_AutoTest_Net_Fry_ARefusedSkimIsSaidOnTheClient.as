// The real fry station, nobody operating. The server drives the skimmer and looks it half-way to the basket, into the
// corridor; once its scoop is at its target there, neither in the pot nor over the basket, it asks for a dip (refused), and
// a second later reports (step 1); its kernel raised OnSkimRefused once. The client raised OnSkimRefused once, its ledger's
// skim refusal serial is 1, its kernel reads Carry and its label said "dip in the oil".
// Surface: Ck.Fry.Net.AS_Fry_ARefusedSkimIsSaidOnTheClient
class UCk_AutoTest_Net_Fry_ARefusedSkimIsSaidOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 362000.0;
    private const float32 k_RefusedSeconds = 1.0f;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
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
        _Fry.Request_SetDrive(FMars_Request_Fry_SetDrive(EMars_Implement_Drive::Driven));
        _Fry.Request_Look(FMars_Request_Fry_Look(Get_LookTowardBasket(0.5)));
        WaitUntil(n"Is_ServerInCorridor", n"OnServerInCorridor", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerInCorridor(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsScoopAtTarget() && _Fry.Get_IsScoopInPot() == false && _Fry.Get_IsScoopOverBasket() == false);
    }

    UFUNCTION()
    private void OnServerInCorridor(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Dip));
        WaitSeconds(k_RefusedSeconds, n"OnServerRefused");
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_Equals_Int(_SkimRefusals.Num(), 1, f"the server refused the dip in the corridor once ({Describe_FryRecord()})");
        End_HeatServer(f"{Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        Assert_Equals_Int(_SkimRefusals.Num(), 1, f"the client raised OnSkimRefused once ({Describe_FryRecord()})");
        Assert_Equals_Int(_Fry.Get_Ledger().SkimRefusalSerial, 1, f"the client's ledger's skim refusal serial is 1 ({Describe_FryLedger()})");
        Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Carry, f"the client's kernel reads Carry ({Describe_Fry()})");
        Assert_True(Get_SawLabelAtAnyStep("dip in the oil"), f"the client's label said dip in the oil ({Describe_Seen(_LabelsSeen)})");
        End_HeatClient(f"{Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }
}
