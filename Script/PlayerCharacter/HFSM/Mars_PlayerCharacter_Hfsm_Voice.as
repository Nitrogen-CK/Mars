//--------------------------------------------------------------------------------------------------------------------------
// VoiceTransmit
//--------------------------------------------------------------------------------------------------------------------------

// The chef's microphone while the player is Alive, on its owning copy only; every other copy plays what the server routes
// to it. The audio.voice_push_to_talk setting picks the talker's transmit mode on enter, and again the moment it changes:
// - off (the default): OpenMic. CkVoiceChat opens the microphone itself, once per arming, on the talker this machine's
//   player controls (CkVoiceChat/Claude.md, Transmit mode); the voice gate applies.
// - on: PushToTalk. The PushToTalk row's press starts the transmit and its release stops it; the gate is bypassed.
// Leaving Alive (Downed, Devoured, the pawn ending) sets Disabled, which closes any open transmit: a downed chef's
// microphone is closed, and nothing else has to remember to close it. The chef's Spec keeps PushToTalk as its authored
// mode, so no copy arms at Add; only this task arms the owning copy.
//
// Opening the microphone can fail as an ordinary outcome: no capture device, a process that renders no audio, or an
// unattended process (every automation lane: the engine never opens a microphone there). The open mic reports it with the
// module's own Log line ("cannot transmit: opening capture reported") and does not retry until the next arming; a failed
// push-to-talk press is reported by this task's Log line below and the next press tries again. Neither is a Warning, which
// would fail the test running beside it. Nothing shows that outcome to the player yet: the log lines are its only consumer.
class UMars_SmTask_VoiceTransmit : UMars_SmTask_IntentEdges
{
    private FCk_Handle_VoiceTalker _Talker;
    // The mode this task last applied: true = PushToTalk, false = OpenMic.
    private bool _IsPushToTalk = false;
    // A transmit this task opened for a held PushToTalk row and has not stopped yet.
    private bool _IsKeyTransmitting = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        auto Talker = ck::Ctx(InHandle).As_VoiceTalker(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Talker), "[Voice] the player entering Alive has no VoiceTalker (AMars_PlayerCharacter::Request_ComposeEntity composes one on every copy)"))
        { return; }

        // Cached before Super::DoEnterTask: its first OnMatcherRebound runs inside it.
        _Talker = Talker;
        _IsKeyTransmitting = false;

        {
            // The settings registry is per GameInstance: bind and read on the talker's own world (a multi-PIE session
            // has one per machine).
            const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(_Talker));
            utils_game_settings::BindTo_OnSettingChanged(constants_settings::k_VoicePushToTalk,
                FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnPushToTalkSettingChanged"));
            Apply_Mode(utils_game_settings::Get_SettingValue_Bool(constants_settings::k_VoicePushToTalk, false));
        }

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        // A copy this machine does not own never bound anything.
        if (ck::Is_NOT_Valid(_Talker))
        { return; }

        {
            const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(_Talker));
            utils_game_settings::UnbindFrom_OnSettingChanged(constants_settings::k_VoicePushToTalk,
                FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnPushToTalkSettingChanged"));
        }

        // Closes an open transmit, whoever opened it, and disarms the open mic.
        utils_voice_talker::Request_SetTransmitMode(_Talker, ECk_VoiceChat_TransmitMode::Disabled);

        _Talker = FCk_Handle_VoiceTalker();
        _IsKeyTransmitting = false;
    }

    protected void OnMatcherRebound() override
    {
        if (_IsKeyTransmitting && Get_IsRowActive(GameplayTags::Mars_Intent_PushToTalk) == false)
        { Stop_KeyTransmit(); }
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent != GameplayTags::Mars_Intent_PushToTalk || _IsPushToTalk == false || _IsKeyTransmitting)
        { return; }

        _IsKeyTransmitting = true;
        utils_voice_talker::Request_StartTransmit(_Talker, FCk_Request_VoiceTalker_StartTransmit(),
            FCk_Delegate_Request_OnCompleted(this, n"OnStartTransmitCompleted"));
    }

    protected void OnIntentReleased(FGameplayTag InIntent) override
    {
        if (InIntent == GameplayTags::Mars_Intent_PushToTalk && _IsKeyTransmitting)
        { Stop_KeyTransmit(); }
    }

    UFUNCTION()
    private void OnPushToTalkSettingChanged(FName InKey, FString InValue)
    {
        if (ck::Is_NOT_Valid(_Talker))
        { return; }

        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(_Talker));
        const auto IsPushToTalk = utils_game_settings::Get_SettingValue_Bool(constants_settings::k_VoicePushToTalk, false);
        if (IsPushToTalk == _IsPushToTalk)
        { return; }

        Apply_Mode(IsPushToTalk);
    }

    // Leaving push-to-talk with the key still held first stops the key's transmit: PushToTalk -> OpenMic keeps a caller's
    // open transmit and arms nothing, so the open mic would otherwise never take over. The talker drains its requests in
    // order, so the Stop lands before the mode change that arms it.
    private void Apply_Mode(bool InIsPushToTalk)
    {
        if (InIsPushToTalk == false && _IsKeyTransmitting)
        { Stop_KeyTransmit(); }

        _IsPushToTalk = InIsPushToTalk;
        utils_voice_talker::Request_SetTransmitMode(_Talker,
            InIsPushToTalk ? ECk_VoiceChat_TransmitMode::PushToTalk : ECk_VoiceChat_TransmitMode::OpenMic);
    }

    private void Stop_KeyTransmit()
    {
        _IsKeyTransmitting = false;
        utils_voice_talker::Request_StopTransmit(_Talker);
    }

    // Reads only the request's owner (the talker's entity), never this task's members: the completion can land after the
    // task has exited.
    UFUNCTION()
    private void OnStartTransmitCompleted(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        if (InResult == ECk_Request_OperationResult::Succeeded)
        { return; }

        const auto Talker = InRequestOwner.As_VoiceTalker(ECk_SanityCheck::UnChecked);
        const auto Capture = ck::IsValid(Talker) ? f"{utils_voice_talker::Get_CaptureStartResult(Talker) :n}" : "talker gone";
        const auto Player = Describe_Player(InRequestOwner);
        Log(f"[Voice] {Player} has no open microphone: push-to-talk StartTransmit completed [{InResult :n}], capture [{Capture}]; the next press tries again");
    }

    private FString Describe_Player(FCk_Handle InPlayer) const
    {
        auto Pawn = Cast<APawn>(ck::ToActor(InPlayer, ECk_SanityCheck::UnChecked));
        if (ck::Is_NOT_Valid(Pawn))
        { return "a player whose pawn is gone"; }

        const auto PlayerState = Pawn.PlayerState;
        const auto PlayerName = ck::IsValid(PlayerState) ? PlayerState.GetPlayerName() : "no player state";
        return f"player [{PlayerName}] (pawn {Pawn.GetName()})";
    }
}
