// The proximity-voice real-pawn net tests' shared steps, on top of the real-pawn rig: production chefs, each composing its
// own VoiceTalker (AMars_PlayerCharacter::Request_ComposeEntity) and holding a microphone open while Alive
// (UMars_SmTask_VoiceOpenMic).
//
// The channel's host is a stand-in. Mars composes its proximity channel on AMars_Master_GameState's entity, but a net
// test runs in the harness's /Engine/Maps/Entry under the project's GlobalDefaultGameMode (a CkFoundation gym mode), so no
// Mars GameState exists in a test world. Every machine therefore composes the production Spec (mars::Mars_Voice_Config,
// the one the GameState composes) on the test's replicated subject entity instead. What these rows prove is the chefs'
// side (talker, auto-join, routing, playback, the open-mic task) against the production channel Spec; that the
// GameState's own entity carries the channel's control plane to a client is not proven here.
//
// A gate lane never opens a microphone (the engine source reports Unavailable_UnattendedProcess, so the Alive task's
// StartTransmit completes Failed), so a speaking row replaces its speaker's microphone with a tone on the speaker's
// owning machine (the CkTests hook UCk_Utils_AutoTest_VoiceChat_UE::Debug_InjectToneCaptureSource) and starts the transmit
// itself, once the Alive task's own attempt has resolved.

enum EMars_TESTONLY_NetVoicePhase
{
    None,
    // The speaker stands beside the listener.
    Near,
    // The speaker stands beyond the channel's audible range plus the hysteresis margin.
    Far,
    // The speaker is back beside the listener.
    Back
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only: a feature's processors are
// the only writers in game code).
struct FMars_Fragment_TESTONLY_NetRealPawnVoiceReport
{
    UPROPERTY()
    EMars_TESTONLY_NetVoicePhase Phase = EMars_TESTONLY_NetVoicePhase::None;

    // What the server's copy of a chef reads (see the row writing it); -1 before it is written.
    UPROPERTY()
    float32 HeardPeak = -1.0f;

    // The capture outcome on the server's copy of the client's chef (a copy that does not own the chef never tries).
    UPROPERTY()
    ECk_VoiceChat_CaptureStartResult ClientChefOnServer = ECk_VoiceChat_CaptureStartResult::NotAttempted;

    // The capture outcome the Alive task's attempt left on the host's own chef.
    UPROPERTY()
    ECk_VoiceChat_CaptureStartResult HostChefOnServer = ECk_VoiceChat_CaptureStartResult::NotAttempted;

    UPROPERTY()
    int32 Serial = 0;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetRealPawnVoice : UMars_AutoTestRig_NetRealPawn
{
    // Long enough to outlast any row: the tone must still be playing when a row checks that distance alone silenced it.
    protected const float32 k_ToneSeconds = 26.0f;
    // Peak of the injected sine, 0..1 of full scale.
    protected const float32 k_ToneAmplitude = 0.4f;
    protected const float32 k_ToneFrequencyHz = 300.0f;

    protected FCk_Handle_VoiceChannel _Channel;
    // What the Alive task's own StartTransmit left on the speaker's owning copy before the tone replaced its microphone.
    protected ECk_VoiceChat_CaptureStartResult _AliveCapture = ECk_VoiceChat_CaptureStartResult::NotAttempted;

    private AMars_PlayerCharacter _ToneSpeaker;
    private FName _ToneContinuation;
    private bool _IsToneCompleted = false;
    private ECk_Request_OperationResult _ToneResult = ECk_Request_OperationResult::Failed;
    private AStaticMeshActor _ExtraFloor;

    //------------------------------------------------------------------------------------------------------------------
    // Composition (every machine)
    //------------------------------------------------------------------------------------------------------------------

    // The production proximity channel Spec on the subject entity, and the voice report; call on every machine.
    protected void Add_VoiceRig()
    {
        _Channel = utils_voice_channel::Add(Get_SubjectEntity(), mars::Mars_Voice_Config.ProximityChannel);
        if (ck::Is_NOT_Valid(_Channel))
        {
            FinishFailure(f"the {Get_MachineName()} could not compose the production proximity channel Spec on the subject");
            return;
        }

        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetRealPawnVoiceReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetRealPawnVoiceReport(), ECk_Replication::Replicates); }
    }

    //------------------------------------------------------------------------------------------------------------------
    // Reading
    //------------------------------------------------------------------------------------------------------------------

    // This machine's copy of InPawn's talker; invalid before the copy is composed.
    protected FCk_Handle_VoiceTalker Get_TalkerOf(AMars_PlayerCharacter InPawn)
    {
        if (ck::Is_NOT_Valid(InPawn))
        { return FCk_Handle_VoiceTalker(); }

        const auto Entity = InPawn.Get_GameplayComposedEntity();
        if (ck::Is_NOT_Valid(Entity))
        { return FCk_Handle_VoiceTalker(); }

        return Entity.As_VoiceTalker(ECk_SanityCheck::UnChecked);
    }

    // How loud this machine's copy of InPawn's talker is: the captured level on the owning copy, the level riding the
    // bundles this machine receives elsewhere (it releases to zero once the stream has idled about 0.15 s); -1 without
    // a composed talker.
    protected float32 Get_AmplitudeOf(AMars_PlayerCharacter InPawn)
    {
        const auto Talker = Get_TalkerOf(InPawn);
        return ck::IsValid(Talker) ? utils_voice_talker::Get_CurrentAmplitude(Talker) : -1.0f;
    }

    protected ECk_VoiceChat_CaptureStartResult Get_CaptureOf(AMars_PlayerCharacter InPawn)
    {
        const auto Talker = Get_TalkerOf(InPawn);
        return ck::IsValid(Talker) ? utils_voice_talker::Get_CaptureStartResult(Talker) : ECk_VoiceChat_CaptureStartResult::NotAttempted;
    }

    // This machine's copy of InPawn's talker is a member of this machine's proximity channel.
    protected bool Get_IsMember(AMars_PlayerCharacter InPawn)
    {
        const auto Talker = Get_TalkerOf(InPawn);
        return ck::IsValid(_Channel) && ck::IsValid(Talker) && utils_voice_channel::Get_IsMember(_Channel, Talker);
    }

    // This machine's copy of the viewer (the client's chef) is in Alive. On the server that means the client started its
    // own chef's state machine (owning-client authoritative: the server's copy enters the client's states).
    protected bool Get_IsViewerAlive()
    {
        if (ck::Is_NOT_Valid(_Viewer))
        { return false; }

        const auto Sm = _Viewer.Get_GameplayComposedEntity().As_StateMachine(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Sm) && utils_state_machine::IsInState(Sm, UMars_SmState_Alive);
    }

    protected float64 Get_DistanceBetween(AMars_PlayerCharacter InA, AMars_PlayerCharacter InB)
    {
        if (ck::Is_NOT_Valid(InA) || ck::Is_NOT_Valid(InB))
        { return -1.0; }

        return (InA.GetActorLocation() - InB.GetActorLocation()).Size();
    }

    // Beyond this a recipient that was hearing a Positional3D talker stops receiving it.
    protected float64 Get_SilentBeyondCm()
    {
        return float64(utils_voice_channel::Get_AudibleRange(_Channel)) + float64(utils_voice_chat_settings::Get_ProximityHysteresisMarginCm());
    }

    protected FString Describe_Talker(AMars_PlayerCharacter InPawn)
    {
        const auto Talker = Get_TalkerOf(InPawn);
        if (ck::Is_NOT_Valid(Talker))
        { return "no talker"; }

        return f"amp={utils_voice_talker::Get_CurrentAmplitude(Talker) :.3} transmitting={utils_voice_talker::Get_IsTransmitting(Talker)} "
            + f"capture={utils_voice_talker::Get_CaptureStartResult(Talker) :n} member={Get_IsMember(InPawn)}";
    }

    //------------------------------------------------------------------------------------------------------------------
    // The speaker's tone (the speaker's owning machine)
    //------------------------------------------------------------------------------------------------------------------

    // Waits for the Alive task's own attempt to open InSpeaker's microphone to resolve (recorded in _AliveCapture), stops
    // the transmit if a real microphone opened (an attended run), replaces the microphone with the tone and starts the
    // transmit; then InContinuation, where Get_IsToneTransmitting answers. Only the machine that owns InSpeaker calls it.
    protected void Request_ToneTransmit(AMars_PlayerCharacter InSpeaker, FName InContinuation)
    {
        _ToneSpeaker = InSpeaker;
        _ToneContinuation = InContinuation;
        _IsToneCompleted = false;
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ToneSpeakerAttempted", n"OnToneSpeakerAttempted", k_SlowPolls);
    }

    protected bool Get_IsToneTransmitting()
    {
        return _IsToneCompleted && _ToneResult == ECk_Request_OperationResult::Succeeded;
    }

    protected FString Describe_Tone()
    {
        return f"aliveCapture={_AliveCapture :n} toneCompleted={_IsToneCompleted} toneResult={_ToneResult :n}";
    }

    UFUNCTION()
    private void Is_ToneSpeakerAttempted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Talker = Get_TalkerOf(_ToneSpeaker);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (ck::IsValid(Talker)
            && (utils_voice_talker::Get_CaptureStartResult(Talker) != ECk_VoiceChat_CaptureStartResult::NotAttempted
                || utils_voice_talker::Get_IsTransmitting(Talker))));
    }

    UFUNCTION()
    private void OnToneSpeakerAttempted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Talker = Get_TalkerOf(_ToneSpeaker);
        if (ck::Is_NOT_Valid(Talker))
        { FinishFailure(f"the {Get_MachineName()}'s copy of the speaker has no VoiceTalker"); return; }

        _AliveCapture = utils_voice_talker::Get_CaptureStartResult(Talker);
        if (_AliveCapture == ECk_VoiceChat_CaptureStartResult::NotAttempted && utils_voice_talker::Get_IsTransmitting(Talker) == false)
        {
            FinishFailure(f"the Alive task never tried to open the speaker's microphone on its owning copy ({Describe_Talker(_ToneSpeaker)}; states [{Describe_ActiveStates()}])");
            return;
        }

        if (utils_voice_talker::Get_IsTransmitting(Talker) == false)
        {
            OnToneSpeakerReady(InTimer, InChrono, InDeltaT);
            return;
        }

        // An attended run: the Alive task opened a real microphone. The tone can replace it only while nothing transmits.
        utils_voice_talker::Request_StopTransmit(Talker);
        WaitUntil(n"Is_ToneSpeakerStopped", n"OnToneSpeakerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ToneSpeakerStopped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Talker = Get_TalkerOf(_ToneSpeaker);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (ck::IsValid(Talker) && utils_voice_talker::Get_IsTransmitting(Talker) == false));
    }

    UFUNCTION()
    private void OnToneSpeakerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Talker = Get_TalkerOf(_ToneSpeaker);
        if (ck::Is_NOT_Valid(Talker) || utils_voice_talker::Get_IsTransmitting(Talker))
        { FinishFailure(f"the speaker's talker cannot take the tone ({Describe_Talker(_ToneSpeaker)})"); return; }

        UCk_Utils_AutoTest_VoiceChat_UE::Debug_InjectToneCaptureSource(Talker, FCk_Time(0.0), FCk_Time(k_ToneSeconds), k_ToneAmplitude, k_ToneFrequencyHz);
        utils_voice_talker::Request_StartTransmit(Talker, FCk_Request_VoiceTalker_StartTransmit(),
            FCk_Delegate_Request_OnCompleted(this, n"OnToneTransmitCompleted"));
        WaitUntil(n"Is_ToneTransmitCompleted", _ToneContinuation, k_SlowPolls);
    }

    UFUNCTION()
    private void OnToneTransmitCompleted(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        _ToneResult = InResult;
        _IsToneCompleted = true;
    }

    UFUNCTION()
    private void Is_ToneTransmitCompleted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || _IsToneCompleted);
    }

    //------------------------------------------------------------------------------------------------------------------
    // The server's report
    //------------------------------------------------------------------------------------------------------------------

    protected FMars_Fragment_TESTONLY_NetRealPawnVoiceReport Get_VoiceReport()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetRealPawnVoiceReport);
    }

    protected void Write_VoicePhase(EMars_TESTONLY_NetVoicePhase InPhase)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetRealPawnVoiceReport);
        Report.Phase = InPhase;
        Report.Serial += 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetRealPawnVoiceReport);
    }

    protected void Write_VoiceHeard(float32 InPeak, ECk_VoiceChat_CaptureStartResult InClientChef, ECk_VoiceChat_CaptureStartResult InHostChef)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetRealPawnVoiceReport);
        Report.HeardPeak = InPeak;
        Report.ClientChefOnServer = InClientChef;
        Report.HostChefOnServer = InHostChef;
        Report.Serial += 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetRealPawnVoiceReport);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Placing (server)
    //------------------------------------------------------------------------------------------------------------------

    // Server: a second floor block (the engine cube, 20 m square) whose top face is at InTop; one per row.
    protected void Spawn_ServerExtraFloor(FVector InTop)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Cube = Cast<UStaticMesh>(LoadObject(UStaticMesh, "/Engine/BasicShapes/Cube.Cube"));
        _ExtraFloor = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, InTop - FVector(0.0, 0.0, 50.0)));
        if (ck::Is_NOT_Valid(_ExtraFloor) || ck::Is_NOT_Valid(Cube))
        {
            FinishFailure("the extra floor block (the engine cube) did not spawn");
            return;
        }

        _ExtraFloor.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        _ExtraFloor.StaticMeshComponent.SetStaticMesh(Cube);
        _ExtraFloor.SetActorScale3D(FVector(20.0, 20.0, 1.0));
    }

    // Server: teleports InPawn so its feet stand just above InFeet.
    protected void Request_ServerPlacePawn(AMars_PlayerCharacter InPawn, FVector InFeet)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        const auto HalfHeight = float64(InPawn.CapsuleComponent.GetScaledCapsuleHalfHeight());
        FHitResult Hit;
        InPawn.SetActorLocation(InFeet + FVector(0.0, 0.0, HalfHeight + 2.0), false, Hit, true);
    }

    protected void TearDown() override
    {
        if (ck::IsValid(_ExtraFloor))
        { _ExtraFloor.DestroyActor(); }

        _ExtraFloor = nullptr;
        Super::TearDown();
    }

    // The row's one log line on this machine.
    protected void Log_VoiceRow(FString InRow, FString InExtra)
    {
        Log_RealPawnRow(InRow, f"{Describe_Tone()} {InExtra}");
    }
}
