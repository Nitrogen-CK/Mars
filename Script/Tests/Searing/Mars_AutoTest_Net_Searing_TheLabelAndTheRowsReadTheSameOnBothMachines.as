// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only): its own label and add-food
// row at the step it last reported.
struct FMars_Fragment_TESTONLY_NetSearingTexts
{
    UPROPERTY()
    int32 Step = 0;

    UPROPERTY()
    FString Label;

    UPROPERTY()
    FString Row;
}

// The real searing station, the subject seated on the server with nothing docked (step 1); the server docks the input
// platter with one slab frozen on it (step 2), then applies one remote add-food press, and once its pan holds one piece and
// its feed is Idle reports step 3. A second after each step it publishes its own label and add-food row (the station's
// label is re-texted a pass after what it reads changes), and holds before the next. On the client: at step 1 its
// add-food row reads "no platter" and its label says "no platter"; at step 2 "add food - 1 left" and "1 raw"; at step 3 its
// label says "0/1 ready"; at each step its label and its row equal the server's, and its legend shows "tilt the pan, flick
// up to toss".
// Surface: Ck.Searing.Net.AS_Searing_TheLabelAndTheRowsReadTheSameOnBothMachines
class UCk_AutoTest_Net_Searing_TheLabelAndTheRowsReadTheSameOnBothMachines : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 347000.0;

    private const float32 k_TextReadSeconds = 1.0f;

    private FCk_Handle _Slab;
    private FString _TextLog;
    private int32 _TextStep = 0;
    private FName _AfterTexts;

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
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetSearingTexts) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetSearingTexts(), ECk_Replication::Replicates); }

        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    private FMars_Fragment_TESTONLY_NetSearingTexts Get_Texts()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetSearingTexts);
    }

    // The client steps only once the server's texts for InStep arrived too.
    protected bool Get_IsStepArrived(int32 InStep) override
    {
        return Super::Get_IsStepArrived(InStep) && Get_Texts().Step >= InStep;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    // Server: step InStep in every report; k_TextReadSeconds later its own label and add-food row for that step, then
    // InContinuation k_StepGapSeconds after.
    private void Report_TextStepThen(int32 InStep, FName InContinuation)
    {
        Report_HeatStep(InStep);
        _TextStep = InStep;
        _AfterTexts = InContinuation;
        WaitSeconds(k_TextReadSeconds, n"OnServerTextsRead");
    }

    UFUNCTION()
    private void OnServerTextsRead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Subject = Get_SubjectEntity();
        auto& Texts = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetSearingTexts);
        Texts.Step = _TextStep;
        Texts.Label = Get_ShownLabel();
        Texts.Row = Get_AddFoodRowText();
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetSearingTexts);
        const auto Label = Texts.Label.Replace("\n", " / ");
        _TextLog += f"step{_TextStep}=[{Label}|{Texts.Row}] ";
        WaitSeconds(k_StepGapSeconds, _AfterTexts);
    }

    protected void On_ServerPlatterReady() override
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        _Followed.Add(_Slab.As_FoodPiece());
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_TextStepThen(1, n"OnServerGap1");
    }

    UFUNCTION()
    private void OnServerGap1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Await_SourcedThen(1, n"OnServerSourced");
    }

    UFUNCTION()
    private void OnServerSourced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_TextStepThen(2, n"OnServerGap2");
    }

    UFUNCTION()
    private void OnServerGap2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("press");
        Press_Remote(GameplayTags::Mars_Intent_StationAddFood);
        WaitUntil(n"Is_ServerOneOnAndIdle", n"OnServerOneOnAndIdle", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOneOnAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_PieceIds().Num() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void OnServerOneOnAndIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step3");
        Report_TextStepThen(3, n"OnServerTextsDone");
    }

    UFUNCTION()
    private void OnServerTextsDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_HeatServer(f"texts=[{_TextLog}] {Describe_Feed()} {Describe_Pan()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // This machine's label and row against the server's for InStep, and against the texts the step expects.
    private void Assert_Texts(int32 InStep, FString InRow, FString InLabelPart)
    {
        const auto Texts = Get_Texts();
        const auto Label = Get_ShownLabel();
        const auto Row = Get_AddFoodRowText();
        const auto ShownLabel = Label.Replace("\n", " / ");
        const auto ServerLabel = Texts.Label.Replace("\n", " / ");
        _TextLog += f"step{InStep}=[{ShownLabel}|{Row}] ";
        if (InRow.IsEmpty() == false)
        { Assert_True(Row == InRow, f"at step {InStep} the client's add-food row reads {InRow} (got {Row})"); }

        Assert_True(Label.Contains(InLabelPart), f"at step {InStep} the client's label says {InLabelPart} (got {ShownLabel})");
        Assert_True(Label == Texts.Label, f"at step {InStep} the client's label is the server's (client {ShownLabel}, server {ServerLabel})");
        Assert_True(Row == Texts.Row, f"at step {InStep} the client's add-food row is the server's (client {Row}, server {Texts.Row})");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        const auto Legend = TryGet_Row(n"Searing", mars::Mars_IA_Look);
        const auto LegendText = Legend.IsSet() ? Legend.GetValue() : "<no row>";
        Assert_True(LegendText == "tilt the pan, flick up to toss", f"at step {InStep} the client's legend shows tilt the pan, flick up to toss (got {LegendText})");

        if (InStep == 1)
        {
            Assert_Texts(1, "no platter", "no platter");
            Await_Step(2);
            return;
        }

        if (InStep == 2)
        {
            Assert_Texts(2, "add food - 1 left", "1 raw");
            Await_Step(3);
            return;
        }

        Assert_Texts(3, "", "0/1 ready");
        End_HeatClient(f"texts=[{_TextLog}] {Describe_Feed()} {Describe_Pan()}");
    }
}
