// With a 2 s departure the server asks its spot directly to leave; 1 s later it reports step 1 with its presence's alpha,
// and once its spot reads Gone it reports step 2. The client raised OnPresenceChanged Leaving, then Gone, once each; its
// alpha never rose between samples; as step 1 arrived it stood within 0.15 of the reported alpha; at step 2 it is 0.
// Surface: Ck.Fishing.Net.AS_Fishing_TheSpotLeavingFadesOnTheClient
class UCk_AutoTest_Net_Fishing_TheSpotLeavingFadesOnTheClient : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 469000.0;
    private const float32 k_LeaveSeconds = 2.0f;
    private const float32 k_MaxAlphaError = 0.15f;
    // A sample may read a hair above the last from float rounding; anything larger is a rise.
    private const float32 k_AlphaRiseTolerance = 0.0001f;

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
        InOutSpec.Presence.LeaveSeconds = k_LeaveSeconds;
    }

    protected void On_ServerStationReady() override
    {
        _Fishing.Request_Leave(FMars_Request_Fishing_Leave());
        WaitSeconds(1.0f, n"OnServerHalfGone");
    }

    UFUNCTION()
    private void OnServerHalfGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Step = FMars_TESTONLY_NetMinigameStep(1);
        Step.Value = _Fishing.Get_PresenceAlpha();
        Report_Step(Step);
        WaitUntil(n"Is_ServerGone", n"OnServerGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fishing.Get_Presence() == EMars_Fishing_Presence::Gone);
    }

    UFUNCTION()
    private void OnServerGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(2));
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            const auto Alpha = _Fishing.Get_PresenceAlpha();
            const auto Reported = Get_Report().Value;
            Log_Minigame(f"step 1 alpha={Alpha} reported={Reported}");
            Assert_True(Math::Abs(Alpha - Reported) <= k_MaxAlphaError, f"the client's alpha stands near the server's as step 1 arrives ({Alpha} vs {Reported})");
            Await_Step(2, EMars_TESTONLY_NetMinigameArrival::Settled);
            return;
        }

        auto Rises = 0;
        auto Previous = 1.0f;
        for (const auto& Sample : _Samples)
        {
            if (Sample.PresenceAlpha > Previous + k_AlphaRiseTolerance)
            { ++Rises; }

            Previous = Sample.PresenceAlpha;
        }

        const auto IsInOrder = _Presences.Num() == 2 && _Presences[0] == EMars_Fishing_Presence::Leaving && _Presences[1] == EMars_Fishing_Presence::Gone;
        Log_Minigame(f"rises={Rises} {Describe_Record()} {Describe_Fishing()}");
        Assert_True(IsInOrder, f"the client raised Leaving, then Gone, once each ({Describe_Record()})");
        Assert_Equals_Int(Rises, 0, "the client's alpha never rose between samples");
        Assert_True(_Fishing.Get_PresenceAlpha() == 0.0f, f"the client's alpha is 0 at step 2 ({_Fishing.Get_PresenceAlpha()})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
