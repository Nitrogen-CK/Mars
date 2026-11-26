// The client's chef speaks (its microphone replaced by a steady tone on the client, its owning machine) beside the host's
// chef. The voice goes the real client path (encoded on the client, sent up through the client's relay, routed by the
// server) and the host's copy of the client's chef plays it: it reads the level riding the bundles the host receives. Also
// proves the open-mic task acts only on the owning copy: the client's chef and the host's chef each tried to open their
// microphone on their own machine, and neither machine's copy of the other chef ever tried. The channel is the production
// Spec on the test subject (see Mars_AutoTestRig_NetRealPawnVoice.as).
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsVoiceReachesTheHost
class UCk_AutoTest_Net_RealPawn_AClientsVoiceReachesTheHost : UMars_AutoTestRig_NetRealPawnVoice
{
    private const FVector k_Base = FVector(952000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsVoiceReachesTheHost";

    private float32 _HeardPeak = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        Add_VoiceRig();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientSpeakerReady", n"OnClientSpeakerReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
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

    // The host's own controller takes the host's chef: a chef nobody plays is no listener (the server sends voice to a
    // player's connection).
    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByLocal(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is local"); return; }

        Mark_Deadline(18.0);
        WaitUntil(n"Is_ServerHeard", n"OnServerHeard", k_SlowPolls);
    }

    // The host's copy of the client's chef reads the level of the bundles the host receives, and the host's own chef's
    // open-mic attempt has resolved.
    UFUNCTION()
    private void Is_ServerHeard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _HeardPeak = Math::Max(_HeardPeak, Get_AmplitudeOf(_Viewer));
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (_HeardPeak > 0.0f && Get_CaptureOf(_Pawn) != ECk_VoiceChat_CaptureStartResult::NotAttempted));
    }

    UFUNCTION()
    private void OnServerHeard(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto ClientChef = Get_CaptureOf(_Viewer);
        const auto HostChef = Get_CaptureOf(_Pawn);
        Write_VoiceHeard(_HeardPeak, ClientChef, HostChef);
        Log_VoiceRow(k_Row, f"heardPeak={_HeardPeak :.3} clientChef=[{Describe_Talker(_Viewer)}] hostChef=[{Describe_Talker(_Pawn)}] distance={Get_DistanceBetween(_Pawn, _Viewer) :.0}");
        Assert_True(_HeardPeak > 0.0f, f"the host received the client's chef's voice (peak {_HeardPeak :.3}; client's chef on the host [{Describe_Talker(_Viewer)}])");
        Assert_True(HostChef != ECk_VoiceChat_CaptureStartResult::NotAttempted,
            "the open-mic task tried to open the host's chef's microphone on its owning copy");
        Assert_True(ClientChef == ECk_VoiceChat_CaptureStartResult::NotAttempted,
            f"the host's copy of the client's chef never tried to open a microphone ({ClientChef :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    // The client controls its own chef, composed with its talker, and has its copy of the host's chef.
    UFUNCTION()
    private void Is_ClientSpeakerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && ck::IsValid(Get_TalkerOf(_Pawn))
            && ck::IsValid(Get_Viewer()) && Get_Viewer().IsLocallyControlled() && ck::IsValid(Get_TalkerOf(Get_Viewer())));
    }

    UFUNCTION()
    private void OnClientSpeakerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ToneTransmit(Get_Viewer(), n"OnClientToneStarted");
    }

    UFUNCTION()
    private void OnClientToneStarted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsToneTransmitting() == false)
        {
            Log_VoiceRow(k_Row, f"speaker=[{Describe_Talker(Get_Viewer())}]");
            FinishFailure(f"the client's chef did not start transmitting the tone ({Describe_Tone()})");
            return;
        }

        Mark_Deadline(22.0);
        WaitUntil(n"Is_ClientReportArrived", n"OnClientChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReportArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_VoiceReport().HeardPeak >= 0.0f);
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_VoiceReport();
        const auto HostChefHere = Get_CaptureOf(_Pawn);
        Log_VoiceRow(k_Row, f"report={Report.Serial} heardPeak={Report.HeardPeak :.3} clientChefOnServer={Report.ClientChefOnServer :n} hostChefOnServer={Report.HostChefOnServer :n} hostChefHere={HostChefHere :n} speaker=[{Describe_Talker(Get_Viewer())}]");
        Assert_True(Report.HeardPeak > 0.0f, f"the host reported hearing this client's chef (peak {Report.HeardPeak :.3}, report {Report.Serial})");
        Assert_True(_AliveCapture != ECk_VoiceChat_CaptureStartResult::NotAttempted,
            "the open-mic task tried to open this client's chef's microphone on its owning copy");
        Assert_True(HostChefHere == ECk_VoiceChat_CaptureStartResult::NotAttempted,
            f"this client's copy of the host's chef never tried to open a microphone ({HostChefHere :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        FinishSuccess();
    }
}
