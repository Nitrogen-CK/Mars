// One hit cracks the batch and the grind takes 1 s. The server seats the subject and applies a remote Drop press; once the
// batch is Pepper it applies a remote Primary press, and 1 s later its mortar has started no strike (a remote operator's
// pestle is its cue, not its stream); it reports step 1. As step 1 arrives the client presses through the station's helper
// with a hit's sweep and releases, and once its batch reads Grind it presses. Once the batch is Done the server applies a
// remote Secondary press, and once the tally counts one it reports step 2. Before step 1 the client's switch row read
// "switch to pepper", then "switch to salt"; at step 2 its tally counts one pepper, its batch is fresh, and its collect row
// was shown and is gone.
// Surface: Ck.Mortar.Net.AS_Mortar_ARemoteOperatorsKeysSwitchAndCollectAndItsPrimaryDoesNot
class UCk_AutoTest_Net_Mortar_ARemoteOperatorsKeysSwitchAndCollectAndItsPrimaryDoesNot : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 448000.0;

    // Client: each switch row text it saw before step 1, in order, as it changed; whether its collect row was ever shown.
    private TArray<FString> _SwitchRows;
    private FString _LastSwitchRow = "<unset>";
    private bool _CollectRowShown = false;

    protected void Configure_Spec(FMars_Mortar_Spec& InOutSpec) override
    {
        InOutSpec.CrushesNeeded = 1;
        InOutSpec.GrindSeconds = 1.0f;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Immediate); }
    }

    protected void On_ServerStationReady() override
    {
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Press_Remote(GameplayTags::Mars_Intent_Drop);
        WaitUntil(n"Is_ServerPepper", n"OnServerPepper", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPepper(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Batch().Seasoning == EMars_Mortar_Seasoning::Pepper);
    }

    UFUNCTION()
    private void OnServerPepper(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Press_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitSeconds(1.0f, n"OnServerPrimaryWatched");
    }

    UFUNCTION()
    private void OnServerPrimaryWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Mortar.Get_Ledger().StrikeSerial, 0, f"a remote Primary press started no strike ({Describe_Mortar()})");
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
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
        Press_Remote(GameplayTags::Mars_Intent_Interact_Secondary);
        WaitUntil(n"Is_ServerCollected", n"OnServerCollected", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCollected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Tally().Get_Count(EMars_Mortar_Seasoning::Pepper) == 1);
    }

    UFUNCTION()
    private void OnServerCollected(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(2));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_Sample(float32 InDeltaSeconds) override
    {
        if (Get_IsServer())
        { return; }

        if (TryGet_Row(n"Mortar", mars::Mars_IA_Interact_Secondary).IsSet())
        { _CollectRowShown = true; }

        if (Get_Report().Step >= 1)
        { return; }

        const auto Row = TryGet_Row(n"Mortar", mars::Mars_IA_Drop);
        const FString Text = Row.IsSet() ? Row.GetValue() : "";
        if (Text != _LastSwitchRow && Text.IsEmpty() == false)
        { _SwitchRows.Add(Text); }

        _LastSwitchRow = Text;
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Pestle_For(EMars_Mortar_PestleVerb::Press, Get_HitSweep());
            Pestle_For(EMars_Mortar_PestleVerb::Release, 0.0f);
            WaitUntil(n"Is_ClientGrindPhase", n"OnClientGrindPhase", k_SlowPolls);
            return;
        }

        auto Rows = FString();
        for (const auto& Row : _SwitchRows)
        { Rows += f"'{Row}' "; }

        const auto IsSwitchSeen = _SwitchRows.Num() >= 2 && _SwitchRows[0] == "switch to pepper" && _SwitchRows[1] == "switch to salt";
        Assert_True(IsSwitchSeen, f"before step 1 the client's switch row read switch to pepper, then switch to salt ({Rows})");
        Assert_Equals_Int(_Mortar.Get_Tally().Get_Count(EMars_Mortar_Seasoning::Pepper), 1, f"the client's tally counts one pepper ({Describe_Mortar()})");
        Assert_True(utils_mortar::Get_IsFresh(_Mortar.Get_Batch()), f"the client's batch is fresh ({Describe_Mortar()})");
        Assert_True(_CollectRowShown, "the client's collect row was shown");
        Assert_True(TryGet_Row(n"Mortar", mars::Mars_IA_Interact_Secondary).IsSet() == false, "the client's collect row is gone");
        End_MinigameClient(f"switchRows=[{Rows}] collectShown={_CollectRowShown} {Describe_Record()} {Describe_Mortar()}");
    }

    UFUNCTION()
    private void Is_ClientGrindPhase(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Grind);
    }

    UFUNCTION()
    private void OnClientGrindPhase(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Pestle_For(EMars_Mortar_PestleVerb::Press, _Mortar.Get_SweepSeconds());
        Await_Step(2, EMars_TESTONLY_NetMinigameArrival::Settled);
    }
}
