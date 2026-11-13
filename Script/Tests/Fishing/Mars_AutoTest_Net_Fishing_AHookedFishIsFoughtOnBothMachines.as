// With two fish in the table the server engages its spot directly and casts; once Waiting it forces a bite, strikes and
// holds the reel; once its line is under half its landed length it reports the line's length and tension and the catch's
// place in the table. The client raised OnBiteEnded once with Hooked and reads the reel held; its line fell over the
// sampled frames, as the report arrived it stood within 40 cm of the reported length and it was never below it by more
// than 40 cm before; its catch's item is the table's entry at the reported place.
// Surface: Ck.Fishing.Net.AS_Fishing_AHookedFishIsFoughtOnBothMachines
class UCk_AutoTest_Net_Fishing_AHookedFishIsFoughtOnBothMachines : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 462000.0;
    private const float32 k_MaxLineErrorCm = 40.0f;

    // Server: the line's length when the bait landed.
    private float32 _LandedLength = 0.0f;

    // Client: its line as the report arrived, and the shortest it sampled before.
    private float32 _LineAtArrival = 0.0f;
    private float32 _ShortestBefore = 0.0f;
    private float32 _FirstReelingLength = -1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Immediate); }
    }

    protected void Configure_Spec(FMars_Fishing_Spec& InOutSpec) override
    {
        InOutSpec.Fish.Table.Add(FMars_Fishing_FishEntry(mars_items::Fig(), 1.0f, 1.0f));
    }

    protected void On_ServerStationReady() override
    {
        _Fishing.Request_Engage(FMars_Request_Fishing_Engage());
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
        Await_Phase(EMars_Fishing_Phase::Waiting, n"OnServerWaiting");
    }

    UFUNCTION()
    private void OnServerWaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LandedLength = _Fishing.Get_LineLengthCm();
        _Fishing.Request_ForceBite(FMars_Request_Fishing_ForceBite());
        _Fishing.Request_Hook(FMars_Request_Fishing_Hook());
        _Fishing.Request_ReelHold(FMars_Request_Fishing_ReelHold());
        WaitUntil(n"Is_ServerHalfIn", n"OnServerHalfIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHalfIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Reeling && _Fishing.Get_LineLengthCm() < _LandedLength * 0.5f);
    }

    UFUNCTION()
    private void OnServerHalfIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Step = FMars_TESTONLY_NetMinigameStep(1);
        Step.Value = _Fishing.Get_LineLengthCm();
        Step.Seconds = _Fishing.Get_Tension();
        Step.Count = _Fishing.Get_Catch().TableIndex;
        Report_Step(Step);
        End_FishingServer(f"landed={_LandedLength} {Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        _LineAtArrival = _Fishing.Get_LineLengthCm();
        _ShortestBefore = _LineAtArrival;
        for (const auto& Sample : _Samples)
        {
            if (Sample.Phase != EMars_Fishing_Phase::Reeling)
            { continue; }

            if (_FirstReelingLength < 0.0f)
            { _FirstReelingLength = Sample.Line.LengthCm; }

            _ShortestBefore = Math::Min(_ShortestBefore, Sample.Line.LengthCm);
        }

        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_Report();
        const auto Reported = Report.Value;
        const auto Index = Report.Count;
        const auto ArrivalError = _LineAtArrival - Reported;
        const auto Lag = ArrivalError / _FishingSpec.Reel.ReelSpeedCmPerS;
        const auto IsHooked = _BiteEnds.Num() == 1 && _BiteEnds[0] == EMars_Fishing_BiteResult::Hooked;
        const auto Table = _FishingSpec.Fish.Table;
        const auto IsIndexValid = Index >= 0 && Index < Table.Num();
        Log_Minigame(f"reported={Reported} tension={Report.Seconds} index={Index} arrival={_LineAtArrival} error={ArrivalError} lagSeconds={Lag} "
            + f"shortestBefore={_ShortestBefore} firstReeling={_FirstReelingLength} {Describe_Record()} {Describe_Fishing()}");

        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnBiteEnded), 1, f"the client raised OnBiteEnded once ({Describe_Record()})");
        Assert_True(IsHooked, f"the client's bite ended Hooked ({Describe_Record()})");
        Assert_True(_Fishing.Get_Reel() == EMars_Fishing_Reel::Held, f"the client reads the reel held ({Describe_Fishing()})");
        Assert_True(_FirstReelingLength > _LineAtArrival, f"the client's line fell over the sampled frames ({_FirstReelingLength} to {_LineAtArrival})");
        Assert_True(Math::Abs(ArrivalError) <= k_MaxLineErrorCm, f"the client's line stood within {k_MaxLineErrorCm} cm of the reported one as it arrived ({_LineAtArrival} vs {Reported})");
        Assert_True(_ShortestBefore >= Reported - k_MaxLineErrorCm, f"the client's line was never below the reported one by more than {k_MaxLineErrorCm} cm ({_ShortestBefore} vs {Reported})");
        Assert_True(IsIndexValid && _Fishing.Get_Catch().Item.Get() == Table[Index].Item.Get(),
            f"the client's catch is the table's entry {Index} ({Describe_Fishing()})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
