// The link: the sequence consumes rising edges from the MechanismSink on its own entity and drives the MechanismSource
// on that entity (asserted while complete).
class UMars_Processor_Sequence_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Sequence_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Sequence);
        Query.Require(FMars_Tag_Sequence_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Sequence = InHandle.As_Sequence();

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Sink))
        { Sink.BindTo_OnInputEdge(FMars_Delegate_MechanismSink_OnInputEdge(this, n"OnSinkInputEdge")); }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        { Source.Request_SetAsserted(Sequence.Get_IsComplete()); }

        Sequence.Request_TryRemove(FMars_Tag_Sequence_NeedsSetup);
    }

    UFUNCTION()
    private void OnSinkInputEdge(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel, bool InAsserted)
    {
        if (InAsserted == false)
        { return; }

        auto Sequence = InSink.As_Sequence(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Sequence))
        { return; }

        const auto& Params = Sequence.Get_Fragment(FMars_Fragment_Sequence_Params);
        const auto Steps = Params.Steps;
        const auto ResetOnWrongInput = Params.ResetOnWrongInput;
        const auto StepTimeoutSeconds = Params.StepTimeoutSeconds;
        const auto Latch = Params.Latch;
        const auto OutputPulseSeconds = Params.OutputPulseSeconds;

        auto& State = Sequence.Get_Fragment(FMars_Fragment_Sequence);

        if (State.IsComplete || State.Progress >= Steps.Num())
        { return; }

        if (Steps[State.Progress] != InChannel)
        {
            if (Sequence.Has_Fragment(FMars_Fragment_Sequence_Signals))
            { Sequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnInputRejected.Broadcast(Sequence, InChannel); }

            if (ResetOnWrongInput)
            { utils_sequence::Reset(Sequence); }
            return;
        }

        const auto AcceptedIndex = State.Progress;
        State.Progress = AcceptedIndex + 1;
        const auto Completed = State.Progress >= Steps.Num();

        utils_sequence::DestroyStepTimer(State);

        if (Completed)
        {
            State.IsComplete = true;

            if (Latch == false)
            {
                const float32 FallbackPulseSeconds = 0.1f;
                State.StepTimer = ArmTimer(Sequence, OutputPulseSeconds > 0.0f ? OutputPulseSeconds : FallbackPulseSeconds);
            }
        }
        else if (StepTimeoutSeconds > 0.0f)
        { State.StepTimer = ArmTimer(Sequence, StepTimeoutSeconds); }

        if (Sequence.Has_Fragment(FMars_Fragment_Sequence_Signals))
        { Sequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnStepAccepted.Broadcast(Sequence, AcceptedIndex); }

        if (Completed == false)
        { return; }

        auto Source = Sequence.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        { Source.Request_SetAsserted(true); }

        if (Sequence.Has_Fragment(FMars_Fragment_Sequence_Signals))
        { Sequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnCompleted.Broadcast(Sequence); }
    }

    private FCk_Handle_Timer ArmTimer(FCk_Handle_Sequence& InSequence, float32 InSeconds)
    {
        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto SequenceEntity = FCk_Handle(InSequence);
        auto Timer = utils_timer::Add(SequenceEntity, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnStepTimerDone")); }

        return Timer;
    }

    // Step timeout while in progress, output pulse end while complete and unlatched: both reset.
    UFUNCTION()
    private void OnStepTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Sequence = Owner.As_Sequence(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Sequence))
        { return; }

        // A timer replaced by a newer step can still finish in the frame it was destroyed.
        const auto& State = Sequence.Get_Fragment(FMars_Fragment_Sequence);
        if ((FCk_Handle(State.StepTimer) == FCk_Handle(InTimer)) == false)
        { return; }

        Sequence.Request_Reset();
    }
}
