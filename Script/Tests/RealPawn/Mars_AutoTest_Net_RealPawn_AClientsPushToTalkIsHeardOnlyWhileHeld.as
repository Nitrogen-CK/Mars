// The client turns the voice mode to push-to-talk (audio.voice_push_to_talk; restored at teardown) while its chef is Alive:
// the Alive task takes the talker to PushToTalk at once, so nothing transmits. Its microphone replaced by a steady tone,
// the client holds the PushToTalk row (a private key stack, UMars_AutoTestHelper_UseKey, handed to its chef's
// InputIntents) and its chef transmits; the host's copy of the client's chef reads the level riding the bundles it
// receives. Once the host has heard it the client lets go: the transmit closes and the host's copy reads silent for as
// long as the host watches. The channel is the production Spec on the test subject (see Mars_AutoTestRig_NetRealPawnVoice.as).
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsPushToTalkIsHeardOnlyWhileHeld
class UCk_AutoTest_Net_RealPawn_AClientsPushToTalkIsHeardOnlyWhileHeld : UMars_AutoTestRig_NetRealPawnVoice
{
    private const FVector k_Base = FVector(970000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsPushToTalkIsHeardOnlyWhileHeld";
    // LOAD-SENSITIVE: how long the host watches its copy of the client's chef after the release once it first reads
    // silent. A steady tone held down never idles past the stale-drop age, so silence that lasts this long is the release.
    private const float64 k_SilentWatchSeconds = 1.5;
    // The silence is meaningful only if it was watched for a while.
    private const int32 k_MinSilentSamples = 10;

    // Server
    private float32 _HeardPeak = 0.0f;
    private float32 _PeakAfterRelease = 0.0f;
    private int32 _SilentSamples = 0;

    // Client
    private UMars_AutoTestHelper_UseKey _Keys;
    private FCk_Handle_InputIntents _Intents;
    private TOptional<bool> _PushToTalkBefore;
    // The client's world, whose GameInstance holds the setting: kept so teardown restores it even once the subject is gone.
    private UWorld _SettingsWorld;
    private bool _WasSilentBeforePress = false;
    private bool _TransmittedWhileHeld = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        Add_VoiceRig();

        if (Get_IsServer() == false)
        {
            // The PushToTalk row on a private key stack under the test entity, so it ends with the test.
            auto Rows = TArray<FMars_AutoTestHelper_KeyRow>();
            Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::V, GameplayTags::Mars_Intent_PushToTalk, n"PT"));
            _Keys = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
            _Keys.Build_Rows(InHandle, Rows);
            WaitUntil(n"Is_ClientChefAlive", n"OnClientChefAlive", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnServerComposed", k_SlowPolls);
    }

    protected void TearDown() override
    {
        Restore_PushToTalk();
        Super::TearDown();
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

        Mark_Deadline(10.0);
        WaitUntil(n"Is_ServerReadyToHear", n"OnServerReadyToHear", k_SlowPolls);
    }

    // Both chefs joined the channel on the server and the client runs its own chef (the server's copy entered its Alive).
    UFUNCTION()
    private void Is_ServerReadyToHear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsMember(_Pawn) && Get_IsMember(_Viewer) && Get_IsViewerAlive()));
    }

    UFUNCTION()
    private void OnServerReadyToHear(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_VoiceRow(k_Row, f"host=[{Describe_Talker(_Pawn)}] clientChef=[{Describe_Talker(_Viewer)}] viewerAlive={Get_IsViewerAlive()}");
            FinishFailure(f"the server never had both chefs in the channel and the client's chef Alive (host [{Describe_Talker(_Pawn)}], client's chef [{Describe_Talker(_Viewer)}], viewer alive {Get_IsViewerAlive()})");
            return;
        }

        Write_VoicePhase(EMars_TESTONLY_NetVoicePhase::KeyHeld);
        Mark_Deadline(12.0);
        WaitUntil(n"Is_ServerHeardHeld", n"OnServerHeardHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHeardHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _HeardPeak = Math::Max(_HeardPeak, Get_AmplitudeOf(_Viewer));
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || _HeardPeak > 0.0f);
    }

    UFUNCTION()
    private void OnServerHeardHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_HeardPeak <= 0.0f)
        {
            Log_VoiceRow(k_Row, f"clientChef=[{Describe_Talker(_Viewer)}] distance={Get_DistanceBetween(_Pawn, _Viewer) :.0}");
            FinishFailure(f"the host never heard the client's chef while its push-to-talk key was held (client's chef on the host [{Describe_Talker(_Viewer)}])");
            return;
        }

        Write_VoicePhase(EMars_TESTONLY_NetVoicePhase::KeyReleased);
        Mark_Deadline(8.0);
        WaitUntil(n"Is_ServerSilentAfterRelease", n"OnServerSilentAfterRelease", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSilentAfterRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_AmplitudeOf(_Viewer) == 0.0f);
    }

    UFUNCTION()
    private void OnServerSilentAfterRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_VoiceRow(k_Row, f"heardPeak={_HeardPeak :.3} clientChef=[{Describe_Talker(_Viewer)}]");
            FinishFailure(f"the host's copy of the client's chef never read silent after the client let go of push-to-talk (client's chef on the host [{Describe_Talker(_Viewer)}])");
            return;
        }

        Mark_Deadline(k_SilentWatchSeconds);
        WaitUntil(n"Is_ServerSilenceWatched", n"OnServerSilenceWatched", k_SlowPolls);
    }

    // Samples the client's chef every frame for the watch window.
    UFUNCTION()
    private void Is_ServerSilenceWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _PeakAfterRelease = Math::Max(_PeakAfterRelease, Get_AmplitudeOf(_Viewer));
        _SilentSamples += 1;
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline());
    }

    UFUNCTION()
    private void OnServerSilenceWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto ClientChef = Get_CaptureOf(_Viewer);
        const auto HostChef = Get_CaptureOf(_Pawn);
        Write_VoiceHeard(_HeardPeak, ClientChef, HostChef);
        Write_VoicePhase(EMars_TESTONLY_NetVoicePhase::Done);
        Log_VoiceRow(k_Row, f"heardPeak={_HeardPeak :.3} peakAfterRelease={_PeakAfterRelease :.3} silentSamples={_SilentSamples} clientChef=[{Describe_Talker(_Viewer)}] hostChef=[{Describe_Talker(_Pawn)}]");
        Assert_True(_HeardPeak > 0.0f, f"the host heard the client's chef while its push-to-talk key was held (peak {_HeardPeak :.3})");
        Assert_True(_SilentSamples >= k_MinSilentSamples, f"the host watched the client's chef for {_SilentSamples} frames after the release (at least {k_MinSilentSamples})");
        Assert_True(_PeakAfterRelease == 0.0f, f"the host heard nothing from the client's chef after the release (peak {_PeakAfterRelease :.3} over {_SilentSamples} frames)");
        Assert_True(ClientChef == ECk_VoiceChat_CaptureStartResult::NotAttempted,
            f"the host's copy of the client's chef never tried to open a microphone ({ClientChef :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    // The client controls its own chef, composed with its talker and running its Alive state (so the transmit task has
    // entered and set the talker's mode from the setting), and has its copy of the host's chef.
    UFUNCTION()
    private void Is_ClientChefAlive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && ck::IsValid(Get_Viewer()) && Get_Viewer().IsLocallyControlled()
            && ck::IsValid(Get_TalkerOf(Get_Viewer())) && Get_IsViewerAlive());
    }

    // The setting turned to push-to-talk while the chef is Alive (the task must follow the change at once).
    UFUNCTION()
    private void OnClientChefAlive(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Intents = Get_Viewer().Get_GameplayComposedEntity().As_InputIntents();

        _SettingsWorld = Get_TestWorld();
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(_SettingsWorld);
        _PushToTalkBefore = TOptional<bool>(utils_game_settings::Get_SettingValue_Bool(constants_settings::k_VoicePushToTalk, false));
        if (utils_game_settings::Request_SetSettingValue_Bool(FCk_Request_GameSettings_SetValue_Bool(constants_settings::k_VoicePushToTalk, true)) == false)
        { FinishFailure("the client could not set audio.voice_push_to_talk (is it registered on this machine?)"); return; }

        Mark_Deadline(8.0);
        WaitUntil(n"Is_ClientKeysRecording", n"OnClientKeysRecording", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientKeysRecording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || _Keys.Get_IsRecording());
    }

    UFUNCTION()
    private void OnClientKeysRecording(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Swapped = _Keys.Request_SwapUseSet();
        if (Swapped.IsValid() == false)
        { FinishFailure(Swapped.Get_Error()); return; }

        WaitUntil(n"Is_ClientPushToTalkReady", n"OnClientPushToTalkReady", k_SlowPolls);
    }

    // The row is live and the chef reads it, and the setting change took the talker to PushToTalk with nothing open.
    UFUNCTION()
    private void Is_ClientPushToTalkReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Keep_TestMatcher();
        const auto Talker = Get_TalkerOf(Get_Viewer());
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (_Keys.Get_IsUseSetActive() && _Intents.Get_Matcher() == _Keys.Get_Matcher()
            && ck::IsValid(Talker) && utils_voice_talker::Get_TransmitMode(Talker) == ECk_VoiceChat_TransmitMode::PushToTalk
            && utils_voice_talker::Get_IsTransmitting(Talker) == false));
    }

    UFUNCTION()
    private void OnClientPushToTalkReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Talker = Get_TalkerOf(Get_Viewer());
        if (Get_IsPastDeadline())
        {
            Log_VoiceRow(k_Row, f"speaker=[{Describe_Talker(Get_Viewer())}] keysActive={_Keys.Get_IsUseSetActive()}");
            const auto Mode = ck::IsValid(Talker) ? f"{utils_voice_talker::Get_TransmitMode(Talker) :n}" : "no talker";
            FinishFailure(f"the client's chef never reached PushToTalk with the row live (mode {Mode}, speaker [{Describe_Talker(Get_Viewer())}], keys active {_Keys.Get_IsUseSetActive()})");
            return;
        }

        Inject_Tone(Talker);
        Mark_Deadline(14.0);
        WaitUntil(n"Is_ClientToldToPress", n"OnClientToldToPress", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientToldToPress(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Keep_TestMatcher();
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_VoiceReport().Phase == EMars_TESTONLY_NetVoicePhase::KeyHeld);
    }

    UFUNCTION()
    private void OnClientToldToPress(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        { FinishFailure(f"the host never asked for the key to be pressed (phase {Get_VoiceReport().Phase :n})"); return; }

        // In PushToTalk with the tone in place and no key held, nothing transmits.
        _WasSilentBeforePress = utils_voice_talker::Get_IsTransmitting(Get_TalkerOf(Get_Viewer())) == false;
        _Keys.Press_Row(GameplayTags::Mars_Intent_PushToTalk);
        Mark_Deadline(12.0);
        WaitUntil(n"Is_ClientToldToRelease", n"OnClientToldToRelease", k_SlowPolls);
    }

    // Holds the key until the host has heard it, noting that the chef transmitted the tone meanwhile.
    UFUNCTION()
    private void Is_ClientToldToRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Keep_TestMatcher();
        const auto Talker = Get_TalkerOf(Get_Viewer());
        if (ck::IsValid(Talker) && utils_voice_talker::Get_IsTransmitting(Talker)
            && utils_voice_talker::Get_CaptureStartResult(Talker) == ECk_VoiceChat_CaptureStartResult::Started)
        { _TransmittedWhileHeld = true; }

        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_VoiceReport().Phase == EMars_TESTONLY_NetVoicePhase::KeyReleased);
    }

    UFUNCTION()
    private void OnClientToldToRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Keys.Release_Row(GameplayTags::Mars_Intent_PushToTalk);
        if (Get_IsPastDeadline())
        {
            Log_VoiceRow(k_Row, f"transmittedWhileHeld={_TransmittedWhileHeld} speaker=[{Describe_Talker(Get_Viewer())}]");
            FinishFailure(f"the host never heard the held key (phase {Get_VoiceReport().Phase :n}, transmitted while held {_TransmittedWhileHeld}, speaker [{Describe_Talker(Get_Viewer())}])");
            return;
        }

        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientReportArrived", n"OnClientReportArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReportArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_VoiceReport().Phase == EMars_TESTONLY_NetVoicePhase::Done);
    }

    UFUNCTION()
    private void OnClientReportArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_VoiceReport();
        const auto Talker = Get_TalkerOf(Get_Viewer());
        const auto IsTransmittingAfter = ck::IsValid(Talker) && utils_voice_talker::Get_IsTransmitting(Talker);
        Log_VoiceRow(k_Row, f"report={Report.Serial} phase={Report.Phase :n} heardPeak={Report.HeardPeak :.3} silentBeforePress={_WasSilentBeforePress} transmittedWhileHeld={_TransmittedWhileHeld} transmittingAfter={IsTransmittingAfter} speaker=[{Describe_Talker(Get_Viewer())}]");
        Assert_True(Report.Phase == EMars_TESTONLY_NetVoicePhase::Done, f"the host finished its watch and reported (phase {Report.Phase :n}, report {Report.Serial})");
        Assert_True(Report.HeardPeak > 0.0f, f"the host reported hearing this client's chef while the key was held (peak {Report.HeardPeak :.3})");
        Assert_True(_WasSilentBeforePress, "in push-to-talk nothing transmitted before the key was pressed");
        Assert_True(_TransmittedWhileHeld, "the held key opened this client's chef's transmit from the tone");
        Assert_True(IsTransmittingAfter == false, "letting go of the key closed this client's chef's transmit");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired during the row ({Get_NewEnsures()})");
        Restore_PushToTalk();
        FinishSuccess();
    }

    // Nothing else hands this chef a matcher in a test world (no gameplay input profile); asked for again if one ever does.
    private void Keep_TestMatcher()
    {
        if (ck::IsValid(_Intents) && _Intents.Get_Matcher() != _Keys.Get_Matcher())
        { _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Keys.Get_Matcher())); }
    }

    // Settings are per GameInstance and persist: the client's own registry gets its value back.
    private void Restore_PushToTalk()
    {
        if (_PushToTalkBefore.IsSet() == false || ck::Is_NOT_Valid(_SettingsWorld))
        { return; }

        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(_SettingsWorld);
        utils_game_settings::Request_SetSettingValue_Bool(FCk_Request_GameSettings_SetValue_Bool(constants_settings::k_VoicePushToTalk, _PushToTalkBefore.GetValue()));
        _PushToTalkBefore.Reset();
    }
}
