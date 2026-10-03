// The only writer of the sequence's state. A pending reset applies first, then each input in arrival order: a wrong
// input resets at once (with ResetOnWrongInput), so a later input in the same drain is judged against step 0. Accepting a
// step re-arms the step timer (timeout while in progress, output pulse once complete and unlatched); its end resets.
class UMars_Processor_Sequence_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Sequence_Requests;

    // Unset OutputPulseSeconds on an unlatched sequence.
    private const float32 k_FallbackPulseSeconds = 0.1f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Sequence);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Sequence_Requests& InRequests)
    {
        auto Self = InHandle.As_Sequence();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        const auto InputRequests = InRequests.InputRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Sequence_Requests);

        if (HasReset)
        { Reset(Self); }

        for (const auto& Input : InputRequests)
        { HandleInput(Self, Input.Channel); }
    }

    // Re-reads the fragments on every call: the previous input's broadcasts may have run listeners.
    private void HandleInput(FCk_Handle_Sequence& InSequence, FGameplayTag InChannel)
    {
        const auto& Params = InSequence.Get_Fragment(FMars_Fragment_Sequence_Params);
        const auto StepCount = Params.Steps.Num();
        const auto ResetOnWrongInput = Params.ResetOnWrongInput;
        const auto StepTimeoutSeconds = Params.StepTimeoutSeconds;
        const auto Latch = Params.Latch;
        const auto PulseSeconds = Params.OutputPulseSeconds > 0.0f ? Params.OutputPulseSeconds : k_FallbackPulseSeconds;

        auto& State = InSequence.Get_Fragment(FMars_Fragment_Sequence);
        if (State.IsComplete || State.Progress >= StepCount)
        { return; }

        if (Params.Steps[State.Progress] != InChannel)
        {
            if (InSequence.Has_Fragment(FMars_Fragment_Sequence_Signals))
            { InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnInputRejected.Broadcast(InSequence, InChannel); }

            if (ResetOnWrongInput)
            { Reset(InSequence); }
            return;
        }

        const auto AcceptedIndex = State.Progress;
        State.Progress = AcceptedIndex + 1;
        const auto Completed = State.Progress >= StepCount;

        DestroyStepTimer(State);

        if (Completed)
        {
            State.IsComplete = true;

            if (Latch == false)
            { State.StepTimer = ArmTimer(InSequence, PulseSeconds); }
        }
        else if (StepTimeoutSeconds.IsSet())
        { State.StepTimer = ArmTimer(InSequence, StepTimeoutSeconds.GetValue()); }

        if (InSequence.Has_Fragment(FMars_Fragment_Sequence_Signals))
        { InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnStepAccepted.Broadcast(InSequence, AcceptedIndex); }

        if (Completed == false)
        { return; }

        // The source is optional: a sequence without an output still completes.
        auto Source = InSequence.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        { Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Asserted)); }

        if (InSequence.Has_Fragment(FMars_Fragment_Sequence_Signals))
        { InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnCompleted.Broadcast(InSequence); }
    }

    private void Reset(FCk_Handle_Sequence& InSequence)
    {
        auto& State = InSequence.Get_Fragment(FMars_Fragment_Sequence);
        DestroyStepTimer(State);

        if (State.Progress == 0 && State.IsComplete == false)
        { return; }

        State.Progress = 0;
        State.IsComplete = false;

        auto Source = InSequence.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        { Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Deasserted)); }

        if (InSequence.Has_Fragment(FMars_Fragment_Sequence_Signals))
        { InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnReset.Broadcast(InSequence); }
    }

    private void DestroyStepTimer(FMars_Fragment_Sequence& InState)
    {
        if (ck::IsValid(InState.StepTimer))
        { utils_entity_lifetime::Request_DestroyEntity(InState.StepTimer.H()); }

        InState.StepTimer = FCk_Handle_Timer();
    }

    private FCk_Handle_Timer ArmTimer(FCk_Handle_Sequence& InSequence, float32 InSeconds)
    {
        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(InSequence.H(), TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnStepTimerDone")); }

        return Timer;
    }

    // Step timeout while in progress, output pulse end while complete and unlatched: both reset.
    UFUNCTION()
    private void OnStepTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The owner is gone only while the sequence is being torn down.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Sequence = Owner.As_Sequence();

        // A timer replaced by a newer step can still finish in the frame it was destroyed.
        if (Sequence.Get_Fragment(FMars_Fragment_Sequence).StepTimer != InTimer)
        { return; }

        Sequence.Request_Reset();
    }
}
