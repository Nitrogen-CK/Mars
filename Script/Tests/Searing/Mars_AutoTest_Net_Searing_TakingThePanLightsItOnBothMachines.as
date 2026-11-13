// The real searing station. The server reports step 1; the client reserves the station through the station's act. Once the
// server's station reads the subject operating and its pan is hot it reports step 2: on the client the pan is hot, its pan
// implement Driven and its label does not read "cold"; the client leaves through the station's act. Once the server's
// station is free and its pan cold it reports step 3: on the client the pan is cold, its tilt under 1 degree, its implement
// not Driven, and it raised OnHeatChanged Hot then Cold, each once.
// Surface: Ck.Searing.Net.AS_Searing_TakingThePanLightsItOnBothMachines
class UCk_AutoTest_Net_Searing_TakingThePanLightsItOnBothMachines : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 343000.0;

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
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitUntil(n"Is_ServerOperatedAndHot", n"OnServerOperatedAndHot", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOperatedAndHot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSubjectOperating() && _Searing.Get_IsHot());
    }

    UFUNCTION()
    private void OnServerOperatedAndHot(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStep(2);
        WaitUntil(n"Is_ServerFreeAndCold", n"OnServerFreeAndCold", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFreeAndCold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Station.As_Station().Get_IsOperated() == false && _Searing.Get_IsHot() == false);
    }

    UFUNCTION()
    private void OnServerFreeAndCold(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step3");
        Report_HeatStep(3);
        End_HeatServer(f"{Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        auto Station = _Station.As_Station();
        if (InStep == 1)
        {
            Mark_Time("step1");
            utils_station::Request_ActFor(Station, Get_SubjectEntity(), EMars_Station_Verb::Reserve);
            Await_Step(2);
            return;
        }

        const auto Pan = _Searing.Get_Pan();
        if (InStep == 2)
        {
            Mark_Time("step2");
            const auto Label = Get_ShownLabel();
            Assert_True(_Searing.Get_IsHot(), "the client's pan reads hot");
            Assert_True(Pan.Get_Drive() == EMars_Implement_Drive::Driven, f"the client's pan implement is Driven ({Describe_Pan()})");
            Assert_True(Label.Contains("cold") == false, f"the client's label does not read cold (got {Label})");
            utils_station::Request_ActFor(Station, Get_SubjectEntity(), EMars_Station_Verb::Leave);
            Await_Step(3);
            return;
        }

        Mark_Time("step3");
        const auto Tilt = Pan.Get_Tilt();
        const auto TiltDegrees = Math::Max(Math::Abs(Tilt.Pitch), Math::Max(Math::Abs(Tilt.Roll), Math::Abs(Tilt.Yaw)));
        const auto IsHotThenCold = _HeatChanges.Num() == 2 && _HeatChanges[0] == EMars_Searing_Heat::Hot && _HeatChanges[1] == EMars_Searing_Heat::Cold;
        Assert_True(_Searing.Get_IsHot() == false, "the client's pan reads cold");
        Assert_True(TiltDegrees < 1.0, f"the client's pan tilt is under 1 degree (got {Tilt})");
        Assert_True(Pan.Get_Drive() != EMars_Implement_Drive::Driven, f"the client's pan implement is not Driven ({Describe_Pan()})");
        Assert_True(IsHotThenCold, f"the client raised OnHeatChanged Hot then Cold, each once ({Describe_SearingRecord()})");
        End_HeatClient(f"tilt={Tilt} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
