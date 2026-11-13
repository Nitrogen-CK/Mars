// A remote operator at the real tumbler station. The server docks the input platter with one slab frozen on it and seats the
// subject; a remote look points its cursor at the shut hatch and, once the hatch is hovered, it reports (step 1). A remote
// Use press opens the hatch; the open hatch's tab stands elsewhere, so a remote look points at it again and, once it is
// hovered, the server reports (step 2). A remote add-food press brings the slab in; once the drum holds one and the feed is
// Idle it reports (step 3). The client's station reads the subject operating; at step 1 its use row reads "open the hatch";
// at step 2 "close the hatch" and its add-food row "add food - 1 left"; before step 3 its copy of the slab was a child of its
// own feed hand node for at least five sampled frames; at step 3 its kernel holds one row and its label reads "1 in".
// Surface: Ck.Tumbler.Net.AS_Tumbler_ARemoteOperatorOpensTheHatchAndAddsFood
class UCk_AutoTest_Net_Tumbler_ARemoteOperatorOpensTheHatchAndAddsFood : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 389000.0;

    private FCk_Handle _Slab;
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
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        _Followed.Add(_Slab.As_FoodPiece());
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Await_SourcedThen(1, n"OnServerSourced");
    }

    UFUNCTION()
    private void OnServerSourced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Remote, n"OnServerPointedShut");
    }

    UFUNCTION()
    private void OnServerPointedShut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap1");
    }

    UFUNCTION()
    private void OnServerGap1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("use");
        Press_Remote(GameplayTags::Mars_Intent_Interact_Use);
        WaitUntil(n"Is_ServerOpen", n"OnServerOpen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Open);
    }

    UFUNCTION()
    private void OnServerOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Remote, n"OnServerPointedOpen");
    }

    UFUNCTION()
    private void OnServerPointedOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStep(2);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap2");
    }

    UFUNCTION()
    private void OnServerGap2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("addFood");
        Press_Remote(GameplayTags::Mars_Intent_StationAddFood);
        WaitUntil(n"Is_ServerOneInAndIdle", n"OnServerOneInAndIdle", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOneInAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_PieceIds().Num() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void OnServerOneInAndIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step3");
        Report_HeatStep(3);
        End_HeatServer(f"row=[{Get_AddFoodRowText()}] use=[{Get_UseRowText()}] {Describe_Feed()} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        const auto UseRow = Get_UseRowText();
        const auto AddFoodRow = Get_AddFoodRowText();
        _StepLog += f"step{InStep}=[use='{UseRow}' addFood='{AddFoodRow}'] ";
        Assert_True(Get_IsSubjectOperating(), "the client's station reads the subject operating");
        if (InStep == 1)
        {
            Assert_True(UseRow == "open the hatch", f"at step 1 the client's use row reads open the hatch (got {UseRow})");
            Await_Step(2);
            return;
        }

        if (InStep == 2)
        {
            Assert_True(UseRow == "close the hatch", f"at step 2 the client's use row reads close the hatch (got {UseRow})");
            Assert_True(AddFoodRow == "add food - 1 left", f"at step 2 the client's add-food row reads add food - 1 left (got {AddFoodRow})");
            Await_Step(3);
            return;
        }

        const auto Report = Get_HeatStationReport();
        const auto UnderHand = Report.PieceGuids.Num() > 0 ? Get_UnderHandFrames(Report.PieceGuids[0]) : 0;
        const auto Label = Get_ShownLabel().Replace("\n", " / ");
        Assert_True(UnderHand >= 5, f"the client's slab rode its own feed hand node for at least five frames (got {UnderHand})");
        Assert_Equals_Int(_Tumbler.Get_PieceIds().Num(), 1, f"at step 3 the client's kernel holds one row ({Describe_TumblerLedger()})");
        Assert_True(Label.Contains("1 in"), f"at step 3 the client's label reads 1 in ('{Label}')");
        End_HeatClient(f"{_StepLog} underHand={UnderHand} label='{Label}' {Describe_Feed()} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
