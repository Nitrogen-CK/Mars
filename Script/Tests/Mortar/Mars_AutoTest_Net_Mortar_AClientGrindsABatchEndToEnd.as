// A client grinds a batch. The server reports step 1 and from then on only answers: once the subject operates it seeds
// its stream; once the batch is Done it applies a remote Secondary press; once the tally counts one it reports step 2;
// once the station is free it reports step 3. As step 1 arrives the client reserves the station through the station's
// act. While its batch reads Crush, each time its own window comes onto the marker with no strike it sent unanswered (its
// ledger's strike serial equals its sends) it presses through the station's helper with its own sweep and releases; once
// its batch reads Grind it presses. As step 2 arrives it leaves through the station's act. At step 3 both machines' tallies
// count one salt, both labels say "ground: 1 salt - 0 pepper", and the server landed two strikes, both hits.
// Surface: Ck.Mortar.Net.AS_Mortar_AClientGrindsABatchEndToEnd
class UCk_AutoTest_Net_Mortar_AClientGrindsABatchEndToEnd : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 29.0f;

    private const float64 k_X = 451000.0;

    // Client.
    private bool _IsDriving = false;
    private int32 _Sends = 0;
    private bool _WasOnMarker = true;
    private bool _IsGrindPressed = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Immediate); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerStationReady() override
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        Await_OperatingThenSeed(n"OnServerOperated");
    }

    UFUNCTION()
    private void OnServerOperated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Minigame("operated");
        WaitUntil(n"Is_ServerDone", n"OnServerDone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Done);
    }

    UFUNCTION()
    private void OnServerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Minigame("done");
        Press_Remote(GameplayTags::Mars_Intent_Interact_Secondary);
        WaitUntil(n"Is_ServerTallied", n"OnServerTallied", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTallied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Tally().Get_Count(EMars_Mortar_Seasoning::Salt) == 1);
    }

    UFUNCTION()
    private void OnServerTallied(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(2));
        WaitUntil(n"Is_ServerFree", n"OnServerFree", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFree());
    }

    UFUNCTION()
    private void OnServerFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(3));
        const auto Label = Get_Label();
        const auto IsAllHits = _Landings.Num() == 2 && _Landings[0] == EMars_Mortar_Strike::Hit && _Landings[1] == EMars_Mortar_Strike::Hit;
        Assert_Equals_Int(_Mortar.Get_Tally().Get_Count(EMars_Mortar_Seasoning::Salt), 1, "the server's tally counts one salt");
        Assert_True(Label.Contains("ground: 1 salt - 0 pepper"), f"the server's label says ground: 1 salt - 0 pepper ('{Label}')");
        Assert_True(IsAllHits, f"the server landed two strikes, both hits ({Describe_Record()})");
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            utils_station::Request_ActFor(_Station, Get_SubjectEntity(), EMars_Station_Verb::Reserve);
            _IsDriving = true;
            Await_Step(2, EMars_TESTONLY_NetMinigameArrival::Immediate);
            return;
        }

        if (InStep == 2)
        {
            _IsDriving = false;
            utils_station::Request_ActFor(_Station, Get_SubjectEntity(), EMars_Station_Verb::Leave);
            Await_Step(3, EMars_TESTONLY_NetMinigameArrival::Settled);
            return;
        }

        const auto Label = Get_Label();
        Assert_Equals_Int(_Mortar.Get_Tally().Get_Count(EMars_Mortar_Seasoning::Salt), 1, f"the client's tally counts one salt ({Describe_Mortar()})");
        Assert_True(Label.Contains("ground: 1 salt - 0 pepper"), f"the client's label says ground: 1 salt - 0 pepper ('{Label}')");
        End_MinigameClient(f"sends={_Sends} {Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_Sample(float32 InDeltaSeconds) override
    {
        if (_IsDriving == false || Get_IsSubjectOperating() == false || _Mortar.Get_IsEngaged() == false)
        { return; }

        // Once per pass: the strike just answered is still in flight while the window it was timed on stands on the marker.
        const auto Phase = _Mortar.Get_Batch().Phase;
        const auto IsOnMarker = Get_IsWindowOnMarker();
        const auto HasComeOn = IsOnMarker && _WasOnMarker == false;
        _WasOnMarker = IsOnMarker;
        if (Phase == EMars_Mortar_Phase::Crush && _Mortar.Get_Ledger().StrikeSerial == _Sends && HasComeOn)
        {
            ++_Sends;
            Log_Minigame(f"strike {_Sends} sent sweep={_Mortar.Get_SweepSeconds()} frame={utils_time::Get_FrameCounter()}");
            Pestle_For(EMars_Mortar_PestleVerb::Press, _Mortar.Get_SweepSeconds());
            Pestle_For(EMars_Mortar_PestleVerb::Release, 0.0f);
            return;
        }

        if (Phase == EMars_Mortar_Phase::Grind && _IsGrindPressed == false)
        {
            _IsGrindPressed = true;
            Log_Minigame("grind pressed");
            Pestle_For(EMars_Mortar_PestleVerb::Press, _Mortar.Get_SweepSeconds());
        }
    }
}
