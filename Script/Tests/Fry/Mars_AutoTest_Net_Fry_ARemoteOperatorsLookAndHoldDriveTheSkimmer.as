// A remote operator at the real fry station. The server seats the subject and, once its skimmer is driven, holds Primary in
// the operator's stream; once the dip has settled it reports its scoop's location (step 1). It lets Primary go, and once the
// scoop carries clear of the rim sends a remote look to the basket's centre; once the scoop is over the basket, at its
// target and at its carry height it holds Primary again and, pouring, reports its scoop's location (step 2). The client's station reads the subject
// operating; at step 1 its kernel reads Dip and its dip row "release to lift"; at step 2 Pour and "pouring - release to
// level"; at each step its scoop is within 2 cm of the server's.
// Surface: Ck.Fry.Net.AS_Fry_ARemoteOperatorsLookAndHoldDriveTheSkimmer
class UCk_AutoTest_Net_Fry_ARemoteOperatorsLookAndHoldDriveTheSkimmer : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 369000.0;
    private const float32 k_LookSeconds = 0.5f;
    private const float64 k_ScoopToleranceCm = 2.0;

    // Client: its scoop against the server's at each step.
    private FString _StepLog;

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
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerDriven", n"OnServerDriven", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerDriven(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_Drive() == EMars_Implement_Drive::Driven);
    }

    UFUNCTION()
    private void OnServerDriven(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("hold");
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
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
        LetGo_Remote(GameplayTags::Mars_Intent_Interact_Primary);
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
        Mark_Time("look");
        Look_Remote(Get_LookTowardBasket(1.0), k_LookSeconds);
        WaitUntil(n"Is_ServerOverBasket", n"OnServerOverBasket", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOverBasket(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_IsScoopOverBasket() && Get_IsScoopSettled());
    }

    UFUNCTION()
    private void OnServerOverBasket(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("pour");
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
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
        _ReportScoop = _Fry.Get_ScoopRoot();
        Report_HeatStep(2);
        End_HeatServer(f"{Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    private FString Get_DipRow()
    {
        const auto Row = TryGet_Row(n"Fry", mars::Mars_IA_Interact_Primary);
        return Row.IsSet() ? Row.GetValue() : "<no row>";
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        const auto Scoop = _Fry.Get_ScoopRoot();
        const auto Reported = Get_HeatStationReport().Scoop;
        const auto ScoopError = Scoop.Distance(Reported);
        const auto Row = Get_DipRow();
        _StepLog += f"step{InStep}=[skim={_Fry.Get_Skim() :n} row='{Row}' scoopError={ScoopError}] ";
        Assert_True(Get_IsSubjectOperating(), "the client's station reads the subject operating");
        Assert_True(ScoopError <= k_ScoopToleranceCm, f"at step {InStep} the client's scoop is within 2 cm of the server's (client {Scoop}, server {Reported})");
        if (InStep == 1)
        {
            Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Dip, f"at step 1 the client's kernel reads Dip ({Describe_Fry()} {Describe_FryLedger()})");
            Assert_True(Row == "release to lift", f"at step 1 the client's dip row reads release to lift (got {Row})");
            Await_Step(2);
            return;
        }

        Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Pour, f"at step 2 the client's kernel reads Pour ({Describe_Fry()} {Describe_FryLedger()})");
        Assert_True(Row == "pouring - release to level", f"at step 2 the client's dip row reads pouring - release to level (got {Row})");
        End_HeatClient(f"{_StepLog} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }
}
