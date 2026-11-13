// With a 0.4 s hook window the server engages its spot directly and casts; once Waiting it forces a bite, and once its spot
// reads Waiting again (the window closed unhooked) it reports. The client raised OnBite once, then OnBiteEnded once with
// Missed, and OnPhaseChanged read Bite then Waiting; its bait dipped in some sampled frame and has no dip at the report.
// Surface: Ck.Fishing.Net.AS_Fishing_ABiteAndAMissReachTheClient
class UCk_AutoTest_Net_Fishing_ABiteAndAMissReachTheClient : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 461000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    protected void Configure_Spec(FMars_Fishing_Spec& InOutSpec) override
    {
        InOutSpec.Bite.HookWindowSeconds = 0.4f;
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
        _Fishing.Request_ForceBite(FMars_Request_Fishing_ForceBite());
        Await_Phase(EMars_Fishing_Phase::Bite, n"OnServerBite");
    }

    UFUNCTION()
    private void OnServerBite(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_Phase(EMars_Fishing_Phase::Waiting, n"OnServerWaitingAgain");
    }

    UFUNCTION()
    private void OnServerWaitingAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        auto MaxDip = 0.0f;
        for (const auto& Sample : _Samples)
        { MaxDip = Math::Max(MaxDip, Sample.Bait.DipCm); }

        auto BiteAt = -1;
        auto EndAt = -1;
        for (int32 Index = 0; Index < _Signals.Num(); ++Index)
        {
            if (_Signals[Index] == EMars_TESTONLY_NetFishingSignal::OnBite && BiteAt < 0)
            { BiteAt = Index; }

            if (_Signals[Index] == EMars_TESTONLY_NetFishingSignal::OnBiteEnded && EndAt < 0)
            { EndAt = Index; }
        }

        const auto PhaseBiteAt = Find_Phase(EMars_Fishing_Phase::Bite, 0);
        const auto IsMissed = _BiteEnds.Num() == 1 && _BiteEnds[0] == EMars_Fishing_BiteResult::Missed;
        Log_Minigame(f"maxDip={MaxDip} {Describe_Record()} {Describe_Fishing()}");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnBite), 1, f"the client raised OnBite once ({Describe_Record()})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnBiteEnded), 1, f"the client raised OnBiteEnded once ({Describe_Record()})");
        Assert_True(IsMissed, f"the client's bite ended Missed ({Describe_Record()})");
        Assert_True(BiteAt >= 0 && EndAt > BiteAt, f"the client raised OnBite before OnBiteEnded ({Describe_Record()})");
        Assert_True(PhaseBiteAt >= 0 && Find_Phase(EMars_Fishing_Phase::Waiting, PhaseBiteAt + 1) > PhaseBiteAt, f"the client's phase read Bite then Waiting ({Describe_Record()})");
        Assert_True(MaxDip > 0.0f, f"the client's bait dipped in some sampled frame ({MaxDip})");
        Assert_True(_Fishing.Get_Bait().DipCm == 0.0f, f"the client's bait has no dip at the report ({Describe_Fishing()})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
