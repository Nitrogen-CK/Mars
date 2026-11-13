// One bare piece in the bowl and the subject seated. The server applies a remote sample holding Primary; once its bowl is
// Dipped it reports (step 1), a step gap later lets Primary go and, once its bowl is Resting, reports step 2. On the client
// its station reads the subject operating; at step 1 its bowl is Dipped and its dip row reads "release to lift", at step 2
// its bowl is Resting and its dip row reads "hold to dip in the batter".
// Surface: Ck.Batter.Net.AS_Batter_ARemoteOperatorsHoldDipsTheBowl
class UCk_AutoTest_Net_Batter_ARemoteOperatorsHoldDipsTheBowl : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 308000.0;

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
        Spawn_FoodsThen(mars_items::Food_Mushroom(), 1, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_PieceCount() == 1);
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("hold");
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitUntil(n"Is_ServerDipped", n"OnServerDipped", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerDipped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_Bowl() == EMars_Batter_Bowl::Dipped);
    }

    UFUNCTION()
    private void OnServerDipped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("letGo");
        LetGo_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitUntil(n"Is_ServerResting", n"OnServerResting", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerResting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting);
    }

    UFUNCTION()
    private void OnServerResting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStep(2);
        End_HeatServer(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Assert_True(Get_IsSubjectOperating(), "the client's station reads the subject operating");
        const auto Row = Get_DipRowText();
        if (InStep == 1)
        {
            Mark_Time("step1");
            Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Dipped, f"the client's bowl is Dipped ({Describe_BatterLedger()})");
            Assert_True(Row == "release to lift", f"the client's dip row reads release to lift ('{Row}')");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting, f"the client's bowl is Resting ({Describe_BatterLedger()})");
        Assert_True(Row == "hold to dip in the batter", f"the client's dip row reads hold to dip in the batter ('{Row}')");
        End_HeatClient(f"row='{Row}' {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
