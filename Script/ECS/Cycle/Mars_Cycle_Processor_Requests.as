class UMars_Processor_Cycle_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Cycle_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Cycle);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Cycle_Requests& InRequests,
                       FMars_Fragment_Cycle& InState)
    {
        auto Self = InHandle.As_Cycle();

        auto TargetRunning = InState.IsRunning;
        if (InRequests.SetRunningRequest.IsSet())
        { TargetRunning = InRequests.SetRunningRequest.GetValue().Running; }

        const auto HasRestart = InRequests.RestartRequest.IsSet();
        const auto HasAdvance = InRequests.Advance;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Cycle_Requests);

        const auto& Params = Self.Get_Fragment(FMars_Fragment_Cycle_Params);
        if (Params.Phases.Num() == 0)
        { TargetRunning = false; }

        if (HasRestart)
        { InState.PhaseIndex = 0; }

        if (TargetRunning != InState.IsRunning)
        {
            InState.IsRunning = TargetRunning;
            if (TargetRunning == false)
            { DestroyPhaseTimer(InState); }

            BroadcastRunningChanged(Self, TargetRunning);

            // A resumed cycle starts over: re-entering the kept index would apply only that phase's actions.
            if (TargetRunning)
            {
                InState.PhaseIndex = 0;
                EnterPhase(Self, 0);
            }

            return;
        }

        if (InState.IsRunning == false)
        { return; }

        if (HasRestart)
        {
            EnterPhase(Self, 0);
            return;
        }

        if (HasAdvance)
        { Advance(Self, InState, Params); }
    }

    private void Advance(FCk_Handle_Cycle& InCycle, FMars_Fragment_Cycle& InState, const FMars_Fragment_Cycle_Params& InParams)
    {
        const auto NextIndex = InState.PhaseIndex + 1;
        if (NextIndex < InParams.Phases.Num())
        {
            EnterPhase(InCycle, NextIndex);
            return;
        }

        if (InParams.Loop)
        {
            EnterPhase(InCycle, 0);
            return;
        }

        InState.IsRunning = false;
        DestroyPhaseTimer(InState);
        BroadcastRunningChanged(InCycle, false);
    }

    // Broadcasts last and re-reads the fragment: a listener may enqueue requests, which must not invalidate this state.
    private void EnterPhase(FCk_Handle_Cycle& InCycle, int32 InIndex)
    {
        const auto& Params = InCycle.Get_Fragment(FMars_Fragment_Cycle_Params);
        if (Params.Phases.IsValidIndex(InIndex) == false)
        { return; }

        const auto Phase = Params.Phases[InIndex];

        auto& State = InCycle.Get_Fragment(FMars_Fragment_Cycle);
        State.PhaseIndex = InIndex;
        DestroyPhaseTimer(State);

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(Phase.Duration));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto CycleEntity = FCk_Handle(InCycle);
        auto Timer = utils_timer::Add(CycleEntity, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnPhaseTimerDone")); }
        State.PhaseTimer = Timer;

        if (InCycle.Has_Fragment(FMars_Fragment_Cycle_Signals))
        { InCycle.Get_Fragment(FMars_Fragment_Cycle_Signals).OnPhaseChanged.Broadcast(InCycle, Phase.Phase, InIndex); }
    }

    private void DestroyPhaseTimer(FMars_Fragment_Cycle& InState)
    {
        if (ck::IsValid(InState.PhaseTimer))
        { utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(InState.PhaseTimer)); }

        InState.PhaseTimer = FCk_Handle_Timer();
    }

    private void BroadcastRunningChanged(FCk_Handle_Cycle& InCycle, bool InRunning)
    {
        if (InCycle.Has_Fragment(FMars_Fragment_Cycle_Signals) == false)
        { return; }

        InCycle.Get_Fragment(FMars_Fragment_Cycle_Signals).OnRunningChanged.Broadcast(InCycle, InRunning);
    }

    UFUNCTION()
    private void OnPhaseTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Cycle = Owner.As_Cycle(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Cycle))
        { return; }

        // A timer replaced by a phase entry or a stop can still finish in the frame it was destroyed.
        const auto& State = Cycle.Get_Fragment(FMars_Fragment_Cycle);
        if ((FCk_Handle(State.PhaseTimer) == FCk_Handle(InTimer)) == false)
        { return; }

        auto& Requests = Cycle.AddOrGet_Fragment(FMars_Fragment_Cycle_Requests);
        Requests.Advance = true;
    }
}
