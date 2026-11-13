// A remote operator at the real tumbler station. The server seats the subject; a remote look points its cursor at the lever
// and, once the lever is hovered, it reports (step 1). It holds Use in the operator's stream, and once the lever is gripped
// sends for 1 s one remote look a frame along the lever's pull and, once its axle Mover is still, reports its alpha (step
// 2). It lets Use go, and once its drum is Home reports (step 3). The client's station reads the subject operating; at step 1 its use row
// reads "hold to grip the lever"; at step 2 "release to let go" and its axle Mover's alpha is within 0.05 of the reported one
// and above 0.05; at step 3 its kernel reads Home, its alpha is under 0.01 and its hand reads Free.
// Surface: Ck.Tumbler.Net.AS_Tumbler_ARemoteOperatorsGripRocksTheDrum
class UCk_AutoTest_Net_Tumbler_ARemoteOperatorsGripRocksTheDrum : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 390000.0;
    private const float32 k_AlphaTolerance = 0.05f;
    private const float32 k_MinAlpha = 0.05f;
    private const float32 k_HomeAlpha = 0.01f;

    // Client: what each step read.
    private FString _StepLog;

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
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Point_AtThen(EMars_Tumbler_Target::Lever, EMars_TESTONLY_NetTumblerLook::Remote, n"OnServerPointed");
    }

    UFUNCTION()
    private void OnServerPointed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap1");
    }

    UFUNCTION()
    private void OnServerGap1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("hold");
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Use);
        WaitUntil(n"Is_ServerGripped", n"OnServerGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Gripped && _Tumbler.Get_Drum() == EMars_Tumbler_Drum::Gripped);
    }

    UFUNCTION()
    private void OnServerGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("rock");
        auto Rock = FMars_TESTONLY_NetTumblerRock();
        Rock.Seconds = 1.0f;
        Rock.Degrees = 0.5;
        Rock.Look = EMars_TESTONLY_NetTumblerLook::Remote;
        Rock_LeverThen(Rock, n"OnServerRocked");
    }

    // The lever's spring carries the drum on after the last look: the leader's measure is taken once it is still.
    UFUNCTION()
    private void OnServerRocked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("rocked");
        Await_AxleStillThen(n"OnServerAxleStill");
    }

    UFUNCTION()
    private void OnServerAxleStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        _ReportValue = Get_AxleMover().Get_Alpha();
        Report_HeatStep(2);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap2");
    }

    UFUNCTION()
    private void OnServerGap2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("letGo");
        LetGo_Remote(GameplayTags::Mars_Intent_Interact_Use);
        WaitUntil(n"Is_ServerHome", n"OnServerHome", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home && _Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Free);
    }

    UFUNCTION()
    private void OnServerHome(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step3");
        Report_HeatStep(3);
        End_HeatServer(f"alpha={_ReportValue} use=[{Get_UseRowText()}] {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        const auto UseRow = Get_UseRowText();
        const auto Alpha = Get_AxleMover().Get_Alpha();
        _StepLog += f"step{InStep}=[use='{UseRow}' alpha={Alpha}] ";
        Assert_True(Get_IsSubjectOperating(), "the client's station reads the subject operating");
        if (InStep == 1)
        {
            Assert_True(UseRow == "hold to grip the lever", f"at step 1 the client's use row reads hold to grip the lever (got {UseRow})");
            Await_Step(2);
            return;
        }

        if (InStep == 2)
        {
            const auto Reported = Get_HeatStationReport().Value;
            Assert_True(UseRow == "release to let go", f"at step 2 the client's use row reads release to let go (got {UseRow})");
            Assert_True(Math::Abs(Alpha - Reported) <= k_AlphaTolerance, f"the client's axle follows the server's (client {Alpha}, server {Reported})");
            Assert_True(Alpha > k_MinAlpha, f"the client's axle turned (alpha {Alpha})");
            Await_Step(3);
            return;
        }

        Assert_True(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home, f"at step 3 the client's drum reads Home ({Describe_Tumbler()} {Describe_TumblerLedger()})");
        Assert_True(Alpha < k_HomeAlpha, f"the client's axle is home (alpha {Alpha})");
        Assert_True(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Free, f"the client's hand reads Free ({Describe_Tumbler()})");
        End_HeatClient(f"{_StepLog} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
