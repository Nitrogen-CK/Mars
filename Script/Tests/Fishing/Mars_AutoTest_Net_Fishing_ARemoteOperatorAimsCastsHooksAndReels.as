// The server seats the subject and applies a remote look of 10 degrees of yaw; once its aim reads it, it reports step 1
// with its yaw. It holds a remote Primary for 0.5 s and lets go (the station's reader charges and casts); once Waiting it
// checks the cast's distance lies between those of power 0.3 and 0.8 and forces a bite; once Bite it applies a remote
// Primary press, held (the reader strikes, then reels); once its line is under half its landed length it reports step 2.
// At step 1 the client's aim's yaw lies within 0.5 degrees of the reported one. At step 2 it raised OnCast once and
// OnBiteEnded once with Hooked, and reads the reel held. The reel is slow so the fish is still on when the client looks.
// Surface: Ck.Fishing.Net.AS_Fishing_ARemoteOperatorAimsCastsHooksAndReels
class UCk_AutoTest_Net_Fishing_ARemoteOperatorAimsCastsHooksAndReels : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 466000.0;
    private const float32 k_LookYawDeg = 10.0f;
    private const float32 k_ChargeSeconds = 0.5f;
    private const float32 k_MaxYawErrorDeg = 0.5f;
    private const float32 k_MinPower = 0.3f;
    private const float32 k_MaxPower = 0.8f;

    // Server: the line's length when the bait landed.
    private float32 _LandedLength = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    // Half the landed line takes about 3.5 s to come in and the whole of it 7 s: the station is gone before the fish lands.
    protected void Configure_Spec(FMars_Fishing_Spec& InOutSpec) override
    {
        InOutSpec.Reel.ReelSpeedCmPerS = 50.0f;
        InOutSpec.Reel.TensionGainPerS = 0.05f;
    }

    protected void On_ServerStationReady() override
    {
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Look_Remote(FVector(k_LookYawDeg, 0.0, 0.0), 0.1f);
        WaitUntil(n"Is_ServerAimed", n"OnServerAimed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAimed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Math::Abs(_Fishing.Get_Aim().YawDeg - k_LookYawDeg) < 0.01f);
    }

    UFUNCTION()
    private void OnServerAimed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Step = FMars_TESTONLY_NetMinigameStep(1);
        Step.Value = _Fishing.Get_Aim().YawDeg;
        Report_Step(Step);
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitSeconds(k_ChargeSeconds, n"OnServerCharged");
    }

    UFUNCTION()
    private void OnServerCharged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        LetGo_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        Await_Phase(EMars_Fishing_Phase::Waiting, n"OnServerWaiting");
    }

    // The station's phase machine steps one phase a poll: a bite forced in the frame the bait lands would leave it in
    // Casting, so it is given a few frames to read Waiting.
    UFUNCTION()
    private void OnServerWaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_SmSettleFrames, n"OnServerWaitingSettled");
    }

    UFUNCTION()
    private void OnServerWaitingSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LandedLength = _Fishing.Get_LineLengthCm();
        const auto Ledger = _Fishing.Get_Ledger();
        const auto Distance = float32(Get_HorizontalDistance(Ledger.BaitPosition, Ledger.CastOrigin));
        const auto Launch = _FishingSpec.Launch;
        const auto Power = (Distance - Launch.MinDistanceCm) / (Launch.MaxDistanceCm - Launch.MinDistanceCm);
        const auto MinDistance = Math::Lerp(Launch.MinDistanceCm, Launch.MaxDistanceCm, k_MinPower);
        const auto MaxDistance = Math::Lerp(Launch.MinDistanceCm, Launch.MaxDistanceCm, k_MaxPower);
        Log_Minigame(f"cast distance={Distance} power={Power}");
        Assert_True(Distance >= MinDistance && Distance <= MaxDistance,
            f"the server's cast went between power {k_MinPower} and {k_MaxPower} ({Distance} cm, power {Power})");

        _Fishing.Request_ForceBite(FMars_Request_Fishing_ForceBite());
        Await_Phase(EMars_Fishing_Phase::Bite, n"OnServerBite");
    }

    // As with Waiting: the strike waits until the station's phase machine has read the bite.
    UFUNCTION()
    private void OnServerBite(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_SmSettleFrames, n"OnServerBiteSettled");
    }

    UFUNCTION()
    private void OnServerBiteSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
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
        Report_Step(FMars_TESTONLY_NetMinigameStep(2));
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            const auto Reported = Get_Report().Value;
            const auto Yaw = _Fishing.Get_Aim().YawDeg;
            Log_Minigame(f"step 1 yaw={Yaw} reported={Reported}");
            Assert_True(Math::Abs(Yaw - Reported) <= k_MaxYawErrorDeg, f"the client's aim follows the server's ({Yaw} vs {Reported})");
            Await_Step(2, EMars_TESTONLY_NetMinigameArrival::Settled);
            return;
        }

        const auto IsHooked = _BiteEnds.Num() == 1 && _BiteEnds[0] == EMars_Fishing_BiteResult::Hooked;
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnCast), 1, f"the client raised OnCast once ({Describe_Record()})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnBiteEnded), 1, f"the client raised OnBiteEnded once ({Describe_Record()})");
        Assert_True(IsHooked, f"the client's bite ended Hooked ({Describe_Record()})");
        Assert_True(_Fishing.Get_Reel() == EMars_Fishing_Reel::Held, f"the client reads the reel held ({Describe_Fishing()})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
