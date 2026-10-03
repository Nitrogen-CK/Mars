// A start enters phase 0 afresh (re-entering the kept index would apply only that phase's actions); a stop keeps the
// index. A restart rewinds to phase 0 and re-enters it while running. An advance comes from the current phase's timer.
// Every broadcast comes last, and the fragments are re-read after one: a listener may enqueue requests.
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

        auto TargetRunState = InState.RunState;
        if (InRequests.SetRunningRequests.Num() > 0)
        { TargetRunState = InRequests.SetRunningRequests.Last().RunState; }

        const auto HasRestart = InRequests.RestartRequests.Num() > 0;
        const auto HasAdvance = InRequests.AdvanceRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Cycle_Requests);

        if (HasRestart)
        { InState.PhaseIndex = 0; }

        if (TargetRunState != InState.RunState)
        {
            InState.RunState = TargetRunState;

            const auto Running = TargetRunState == EMars_Cycle_RunState::Running;
            if (Running)
            { EnterPhase(Self, 0); }
            else
            { DestroyPhaseTimer(InState); }

            BroadcastRunningChanged(Self, TargetRunState);
            return;
        }

        if (InState.RunState == EMars_Cycle_RunState::Stopped)
        { return; }

        if (HasRestart)
        {
            EnterPhase(Self, 0);
            return;
        }

        if (HasAdvance)
        { Advance(Self, InState); }
    }

    private void Advance(FCk_Handle_Cycle& InCycle, FMars_Fragment_Cycle& InState)
    {
        const auto& Params = InCycle.Get_Fragment(FMars_Fragment_Cycle_Params);
        const auto NextIndex = InState.PhaseIndex + 1;
        if (NextIndex < Params.Phases.Num())
        {
            EnterPhase(InCycle, NextIndex);
            return;
        }

        if (Params.Loop)
        {
            EnterPhase(InCycle, 0);
            return;
        }

        InState.RunState = EMars_Cycle_RunState::Stopped;
        DestroyPhaseTimer(InState);
        BroadcastRunningChanged(InCycle, EMars_Cycle_RunState::Stopped);
    }

    // Broadcasts last and re-reads the fragment: a listener may enqueue requests, which must not invalidate this state.
    private void EnterPhase(FCk_Handle_Cycle& InCycle, int32 InIndex)
    {
        const auto& Params = InCycle.Get_Fragment(FMars_Fragment_Cycle_Params);
        if (ck::EnsureIfNot(Params.Phases.IsValidIndex(InIndex),
            f"[Cycle] [{InCycle.ToString()}] has no phase [{InIndex}] of [{Params.Phases.Num()}]"))
        { return; }

        const auto Phase = Params.Phases[InIndex];

        auto& State = InCycle.Get_Fragment(FMars_Fragment_Cycle);
        State.PhaseIndex = InIndex;
        DestroyPhaseTimer(State);

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(Phase.Duration));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(InCycle.H(), TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnPhaseTimerDone")); }
        State.PhaseTimer = Timer;

        if (InCycle.Has_Fragment(FMars_Fragment_Cycle_Signals))
        { InCycle.Get_Fragment(FMars_Fragment_Cycle_Signals).OnPhaseChanged.Broadcast(InCycle, Phase.Phase, InIndex); }
    }

    private void DestroyPhaseTimer(FMars_Fragment_Cycle& InState)
    {
        if (ck::IsValid(InState.PhaseTimer))
        { utils_entity_lifetime::Request_DestroyEntity(InState.PhaseTimer.H()); }

        InState.PhaseTimer = FCk_Handle_Timer();
    }

    private void BroadcastRunningChanged(FCk_Handle_Cycle& InCycle, EMars_Cycle_RunState InRunState)
    {
        if (InCycle.Has_Fragment(FMars_Fragment_Cycle_Signals) == false)
        { return; }

        InCycle.Get_Fragment(FMars_Fragment_Cycle_Signals).OnRunningChanged.Broadcast(InCycle, InRunState);
    }

    UFUNCTION()
    private void OnPhaseTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The owner is gone only while the cycle is being torn down.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Cycle = Owner.As_Cycle();

        // A timer replaced by a phase entry or a stop can still finish in the frame it was destroyed.
        if (Cycle.Get_Fragment(FMars_Fragment_Cycle).PhaseTimer != InTimer)
        { return; }

        auto& Requests = Cycle.AddOrGet_Fragment(FMars_Fragment_Cycle_Requests);
        Requests.AdvanceRequests.Add(FMars_Request_Cycle_Advance());
    }
}
