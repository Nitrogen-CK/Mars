//--------------------------------------------------------------------------------------------------------------------------
// VoiceOpenMic
//--------------------------------------------------------------------------------------------------------------------------

// The open microphone: while the player is Alive its owning copy holds a transmit open on the chef's talker, so nearby
// chefs hear it with no key held. Leaving Alive (Downed, Devoured, the pawn ending) stops it: the open mic is scoped to the
// state, and nothing else has to remember to close it. Only the owning copy captures; every other copy plays what the
// server routes to it.
//
// Opening the microphone can fail as an ordinary outcome: no capture device, a process that renders no audio, or an
// unattended process (every automation lane: the engine never opens a microphone there, so every chef's StartTransmit
// completes Failed in a gate run). That outcome is recorded with one Log line (never a Warning, which would fail the
// test running beside it) and not retried; utils_voice_talker::Get_CaptureStartResult holds it until the next attempt.
// Nothing shows that outcome to the player yet: the log line is its only consumer.
class UMars_SmTask_VoiceOpenMic : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_VoiceTalker _Talker;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        auto Talker = ck::Ctx(InHandle).As_VoiceTalker(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Talker), "[Voice] the player entering Alive has no VoiceTalker (AMars_PlayerCharacter::Request_ComposeEntity composes one on every copy)"))
        { return; }

        _Talker = Talker;
        utils_voice_talker::Request_StartTransmit(_Talker, FCk_Request_VoiceTalker_StartTransmit(),
            FCk_Delegate_Request_OnCompleted(this, n"OnStartTransmitCompleted"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Talker))
        { utils_voice_talker::Request_StopTransmit(_Talker); }

        _Talker = FCk_Handle_VoiceTalker();
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
        Log(f"[Voice] {Player} has no open microphone: StartTransmit completed [{InResult :n}], capture [{Capture}]; not retried");
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
