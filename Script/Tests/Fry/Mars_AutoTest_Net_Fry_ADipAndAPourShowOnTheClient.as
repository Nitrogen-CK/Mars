// The real fry station, nobody operating. The server drives the skimmer and dips it at its park over the oil; once the dip
// has settled it reports its scoop's location (step 1). It carries, and once the scoop is clear of the rim looks it to the
// basket's centre; once it is over the basket and at its target it asks for a dip there (a pour) and, pouring, reports
// (step 2). At step 1 the client's kernel reads Dip and its scoop's height is within 1 cm of the server's; at step 2 it
// reads Pour, it raised OnSkimChanged Dip, Carry and Pour in that order, each once, and its skimmer implement's pitch target
// is the spec's pour pitch (1 degree).
// Surface: Ck.Fry.Net.AS_Fry_ADipAndAPourShowOnTheClient
class UCk_AutoTest_Net_Fry_ADipAndAPourShowOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 361000.0;
    private const float64 k_HeightToleranceCm = 1.0;
    private const float64 k_PitchToleranceDegrees = 1.0;

    // Client: its step 1 height against the server's.
    private FString _HeightLog;

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
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Dip));
        WaitUntil(n"Is_ServerDipped", n"OnServerDipped", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerDipped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDipSettled());
    }

    UFUNCTION()
    private void OnServerDipped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        _ReportScoop = _Fry.Get_ScoopRoot();
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Carry));
        WaitUntil(n"Is_ServerClearOfRim", n"OnServerClearOfRim", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerClearOfRim(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_Skim() == EMars_Fry_Skim::Carry && _Fry.Get_IsScoopClearOfRim());
    }

    UFUNCTION()
    private void OnServerClearOfRim(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fry.Request_Look(FMars_Request_Fry_Look(Get_LookTowardBasket(1.0)));
        WaitUntil(n"Is_ServerOverBasket", n"OnServerOverBasket", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOverBasket(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_IsScoopOverBasket() && Get_IsScoopAtTarget());
    }

    UFUNCTION()
    private void OnServerOverBasket(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Dip));
        WaitUntil(n"Is_ServerPouring", n"OnServerPouring", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPouring(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_Skim() == EMars_Fry_Skim::Pour);
    }

    UFUNCTION()
    private void OnServerPouring(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStep(2);
        End_HeatServer(f"{Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            const auto Height = _Fry.Get_ScoopRoot().Z;
            const auto Reported = Get_HeatStationReport().Scoop.Z;
            _HeightLog = f"heightError={Math::Abs(Height - Reported)} (client {Height}, server {Reported})";
            Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Dip, f"at step 1 the client's kernel reads Dip ({Describe_Fry()} {Describe_FryLedger()})");
            Assert_True(Math::Abs(Height - Reported) <= k_HeightToleranceCm, f"at step 1 the client's scoop is at the server's dipped height ({_HeightLog})");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto PourPitch = float64(_Fry.Get_Spec().Scoop.PourPitchDegrees);
        const auto PitchTarget = _Fry.Get_Skimmer().Get_TargetTilt().Pitch;
        const auto IsInOrder = _SkimChanges.Num() == 3 && _SkimChanges[0] == EMars_Fry_Skim::Dip
            && _SkimChanges[1] == EMars_Fry_Skim::Carry && _SkimChanges[2] == EMars_Fry_Skim::Pour;
        Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Pour, f"at step 2 the client's kernel reads Pour ({Describe_Fry()} {Describe_FryLedger()})");
        Assert_True(IsInOrder, f"the client raised OnSkimChanged Dip, Carry, Pour in that order, each once ({Describe_FryRecord()})");
        Assert_True(Math::Abs(PitchTarget - PourPitch) <= k_PitchToleranceDegrees, f"the client's skimmer pitches toward the pour (target {PitchTarget}, spec {PourPitch})");
        End_HeatClient(f"{_HeightLog} pitchTarget={PitchTarget} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }
}
