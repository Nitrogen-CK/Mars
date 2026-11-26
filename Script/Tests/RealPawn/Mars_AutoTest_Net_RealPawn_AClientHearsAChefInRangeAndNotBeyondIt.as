// The host's chef speaks (its microphone replaced by a steady tone) beside the client's chef, then the server moves it
// beyond the proximity channel's audible range plus the hysteresis margin, then back. On the client, its copy of the host's
// chef is heard while near (positive control), reads silent for as long as it stands far, and is heard again once it is
// back: distance alone silenced it, the tone never stopped (the server checks its own copy still captures while far).
// Also proves a listen host's own possessed chef opens its open mic: the open mic the Alive task armed made its first
// attempt on the host's owning copy, and once re-armed over the tone it opened the transmit the client hears, with no
// Start request. The channel is the production Spec on the test subject (see Mars_AutoTestRig_NetRealPawnVoice.as).
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientHearsAChefInRangeAndNotBeyondIt
class UCk_AutoTest_Net_RealPawn_AClientHearsAChefInRangeAndNotBeyondIt : UMars_AutoTestRig_NetRealPawnVoice
{
    private const FVector k_Base = FVector(946000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientHearsAChefInRangeAndNotBeyondIt";
    // Where the speaker stands while far, from the base: 6000 cm from the listener (the viewer, 400 cm on -Y), well past
    // range + margin (4000 + 100) and well inside the pawn's net cull distance (15000), so the client keeps its copy.
    private const FVector k_FarFromBase = FVector(0.0, 5600.0, 0.0);
    // LOAD-SENSITIVE: the server holds each phase for a span of wall-clock; the client must make its observation inside
    // it. Reds under load as "never heard while near" or too few far samples, with the phase already moved on.
    private const float32 k_NearSeconds = 3.0f;
    private const float32 k_FarSeconds = 4.0f;
    private const float32 k_BackSeconds = 2.5f;
    // The far silence is meaningful only if it was watched for a while.
    private const int32 k_MinFarSamples = 10;

    private float32 _NearPeak = 0.0f;
    private float32 _FarPeak = 0.0f;
    private int32 _FarSamples = 0;
    private float64 _FarDistance = -1.0;
    private float32 _ServerFarCapture = -1.0f;

    private FVector Get_FarFeet() const
    {
        return k_Base + k_FarFromBase;
    }

    private EMars_TESTONLY_NetVoicePhase Get_Phase()
    {
        return Get_VoiceReport().Phase;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        Add_VoiceRig();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReady", n"OnClientReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        Spawn_ServerExtraFloor(Get_FarFeet());
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnServerComposed", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByLocal(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is local"); return; }

        Request_ToneTransmit(_Pawn, n"OnServerToneStarted");
    }

    UFUNCTION()
    private void OnServerToneStarted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsToneTransmitting() == false)
        {
            Log_VoiceRow(k_Row, f"speaker=[{Describe_Talker(_Pawn)}]");
            FinishFailure(f"the host's chef did not start transmitting the tone ({Describe_Tone()})");
            return;
        }

        Mark_Deadline(10.0);
        WaitUntil(n"Is_ServerNearReady", n"OnServerNearReady", k_SlowPolls);
    }

    // Both chefs joined the channel on the server, the client runs its own chef's state machine (the server's copy entered
    // the client's Alive) and the tone is being captured.
    UFUNCTION()
    private void Is_ServerNearReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsMember(_Pawn) && Get_IsMember(_Viewer) && Get_IsViewerAlive() && Get_AmplitudeOf(_Pawn) > 0.0f));
    }

    UFUNCTION()
    private void OnServerNearReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_VoiceRow(k_Row, f"speaker=[{Describe_Talker(_Pawn)}] viewer=[{Describe_Talker(_Viewer)}] viewerAlive={Get_IsViewerAlive()}");
            FinishFailure(f"the server never had both chefs in the channel, the client's chef Alive and the tone captured (speaker [{Describe_Talker(_Pawn)}], viewer [{Describe_Talker(_Viewer)}], viewer alive {Get_IsViewerAlive()})");
            return;
        }

        Write_VoicePhase(EMars_TESTONLY_NetVoicePhase::Near);
        WaitSeconds(k_NearSeconds, n"OnServerNearHeld");
    }

    UFUNCTION()
    private void OnServerNearHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerPlacePawn(_Pawn, Get_FarFeet());
        Write_VoicePhase(EMars_TESTONLY_NetVoicePhase::Far);
        WaitSeconds(k_FarSeconds, n"OnServerFarHeld");
    }

    UFUNCTION()
    private void OnServerFarHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ServerFarCapture = Get_AmplitudeOf(_Pawn);
        _FarDistance = Get_DistanceBetween(_Pawn, _Viewer);
        Request_ServerPlacePawn(_Pawn, k_Base);
        Write_VoicePhase(EMars_TESTONLY_NetVoicePhase::Back);
        WaitSeconds(k_BackSeconds, n"OnServerBackHeld");
    }

    UFUNCTION()
    private void OnServerBackHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_VoiceRow(k_Row, f"farCapture={_ServerFarCapture :.3} farDistance={_FarDistance :.0} silentBeyond={Get_SilentBeyondCm() :.0} speaker=[{Describe_Talker(_Pawn)}]");
        Assert_True(_AliveCapture != ECk_VoiceChat_CaptureStartResult::NotAttempted,
            "the open mic tried to open the host's chef's microphone on its owning copy");
        Assert_True(_ServerFarCapture > 0.0f, f"the host's chef was still capturing the tone while it stood far ({_ServerFarCapture :.3})");
        Assert_True(_FarDistance > Get_SilentBeyondCm(),
            f"the server's copy of the host's chef stood beyond range plus margin while far ({_FarDistance :.0} cm, silent beyond {Get_SilentBeyondCm() :.0} cm)");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    // The client's copies of both chefs are composed with their talkers, and it controls its own.
    UFUNCTION()
    private void Is_ClientReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && ck::IsValid(Get_Viewer()) && Get_Viewer().IsLocallyControlled()
            && ck::IsValid(Get_TalkerOf(_Pawn)) && ck::IsValid(Get_TalkerOf(Get_Viewer())));
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Deadline(20.0);
        WaitUntil(n"Is_ClientHeardNear", n"OnClientHeardNear", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHeardNear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Amplitude = Get_AmplitudeOf(_Pawn);
        const auto IsNear = Get_Phase() == EMars_TESTONLY_NetVoicePhase::None || Get_Phase() == EMars_TESTONLY_NetVoicePhase::Near;
        if (IsNear)
        { _NearPeak = Math::Max(_NearPeak, Amplitude); }

        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || IsNear == false || (IsNear && Amplitude > 0.0f));
    }

    UFUNCTION()
    private void OnClientHeardNear(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_NearPeak <= 0.0f)
        {
            Log_VoiceRow(k_Row, f"phase={Get_Phase() :n} distance={Get_DistanceBetween(_Pawn, Get_Viewer()) :.0} speaker=[{Describe_Talker(_Pawn)}] listener=[{Describe_Talker(Get_Viewer())}]");
            FinishFailure(f"the client never heard the host's chef standing beside its own (phase {Get_Phase() :n}, speaker [{Describe_Talker(_Pawn)}])");
            return;
        }

        Mark_Deadline(15.0);
        WaitUntil(n"Is_ClientSilentFar", n"OnClientSilentFar", k_SlowPolls);
    }

    // The server has moved the speaker far, this machine's copy of it stands beyond range plus margin, and it reads silent.
    UFUNCTION()
    private void Is_ClientSilentFar(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_Phase() == EMars_TESTONLY_NetVoicePhase::Far
            && Get_DistanceBetween(_Pawn, Get_Viewer()) > Get_SilentBeyondCm() && Get_AmplitudeOf(_Pawn) == 0.0f));
    }

    UFUNCTION()
    private void OnClientSilentFar(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_VoiceRow(k_Row, f"phase={Get_Phase() :n} distance={Get_DistanceBetween(_Pawn, Get_Viewer()) :.0} speaker=[{Describe_Talker(_Pawn)}]");
            FinishFailure(f"the client's copy of the host's chef never read silent once it stood far (phase {Get_Phase() :n}, distance {Get_DistanceBetween(_Pawn, Get_Viewer()) :.0} cm, silent beyond {Get_SilentBeyondCm() :.0} cm, speaker [{Describe_Talker(_Pawn)}])");
            return;
        }

        Mark_Deadline(15.0);
        WaitUntil(n"Is_ClientFarWatched", n"OnClientFarWatched", k_SlowPolls);
    }

    // Samples the far chef every frame until the server brings it back.
    UFUNCTION()
    private void Is_ClientFarWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsFar = Get_Phase() == EMars_TESTONLY_NetVoicePhase::Far;
        if (IsFar)
        {
            _FarPeak = Math::Max(_FarPeak, Get_AmplitudeOf(_Pawn));
            _FarSamples += 1;
        }

        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || IsFar == false);
    }

    UFUNCTION()
    private void OnClientFarWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_FarSamples >= k_MinFarSamples, f"the client watched its copy of the far chef for {_FarSamples} frames (at least {k_MinFarSamples})");
        Assert_True(_FarPeak == 0.0f, f"the client heard nothing from the host's chef while it stood far (peak {_FarPeak :.3} over {_FarSamples} frames)");
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientHeardBack", n"OnClientHeardBack", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHeardBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_Phase() == EMars_TESTONLY_NetVoicePhase::Back && Get_AmplitudeOf(_Pawn) > 0.0f));
    }

    UFUNCTION()
    private void OnClientHeardBack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto BackAmplitude = Get_AmplitudeOf(_Pawn);
        Log_VoiceRow(k_Row, f"nearPeak={_NearPeak :.3} farPeak={_FarPeak :.3} farSamples={_FarSamples} back={BackAmplitude :.3} phase={Get_Phase() :n} speaker=[{Describe_Talker(_Pawn)}]");
        Assert_True(Get_Phase() == EMars_TESTONLY_NetVoicePhase::Back && BackAmplitude > 0.0f,
            f"the client heard the host's chef again once it was back beside its own (phase {Get_Phase() :n}, amplitude {BackAmplitude :.3})");
        Assert_True(Get_CaptureOf(_Pawn) == ECk_VoiceChat_CaptureStartResult::NotAttempted,
            f"the client's copy of the host's chef never tried to open a microphone ({Get_CaptureOf(_Pawn) :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        FinishSuccess();
    }
}
