// Drives the trap's Mover/Hazard from its Cycle's phases, gates the Cycle by an optional MechanismSink on the same
// entity, and forwards Hazard hits as OnTriggered.
class UMars_Processor_Trap_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Trap_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Trap);
        Query.Require(FMars_Tag_Trap_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Trap = InHandle.As_Trap();
        const auto& State = Trap.Get_Fragment(FMars_Fragment_Trap);

        auto Cycle = State.Cycle;
        auto Hazard = State.Hazard;

        Cycle.BindTo_OnPhaseChanged(FMars_Delegate_Cycle_OnPhaseChanged(this, n"OnCyclePhaseChanged"));
        Cycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnCycleRunningChanged"));
        Hazard.BindTo_OnHit(FMars_Delegate_Hazard_OnHit(this, n"OnHazardHit"));

        // The cycle may have entered its first phase before these binds; re-applying is idempotent.
        if (Cycle.Get_IsRunning())
        { ApplyPhase(Trap, Cycle.Get_CurrentPhase()); }

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Sink))
        {
            Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnSinkPoweredChanged"));
            if (Sink.Get_HasEvaluated())
            { ApplyPowered(Trap, Sink.Get_IsPowered()); }
        }

        Trap.Request_TryRemove(FMars_Tag_Trap_NeedsSetup);
    }

    private void ApplyPhase(FCk_Handle_Trap& InTrap, FGameplayTag InPhase)
    {
        const auto& Spec = InTrap.Get_Fragment(FMars_Fragment_Trap_Params).Spec;
        const auto& State = InTrap.Get_Fragment(FMars_Fragment_Trap);

        // Add guarantees a mover when an action moves a part.
        auto Mover = State.Mover;
        auto Hazard = State.Hazard;

        for (const auto& Action : Spec.Actions)
        {
            if (Action.Phase != InPhase)
            { continue; }

            if (Action.MoverAtEnd.IsSet())
            { Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(Action.MoverAtEnd.GetValue() ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start)); }

            if (Action.HazardArmed.IsSet())
            { Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(Action.HazardArmed.GetValue() ? EMars_Hazard_Arming::Armed : EMars_Hazard_Arming::Disarmed)); }
        }
    }

    private void ApplyPowered(FCk_Handle_Trap& InTrap, bool InPowered)
    {
        const auto Powered = InTrap.Get_Fragment(FMars_Fragment_Trap_Params).Spec.Powered;
        const auto Running = Powered == EMars_PoweredBehavior::RunWhilePowered ? InPowered : (InPowered == false);

        auto Cycle = InTrap.Get_Fragment(FMars_Fragment_Trap).Cycle;
        Cycle.Request_SetRunning(FMars_Request_Cycle_SetRunning(Running ? EMars_Cycle_RunState::Running : EMars_Cycle_RunState::Stopped));
    }

    UFUNCTION()
    private void OnCyclePhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex)
    {
        auto Trap = InCycle.As_Trap();
        ApplyPhase(Trap, InPhase);
    }

    UFUNCTION()
    private void OnCycleRunningChanged(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState)
    {
        if (InRunState == EMars_Cycle_RunState::Running)
        { return; }

        auto Trap = InCycle.As_Trap();
        const auto& State = Trap.Get_Fragment(FMars_Fragment_Trap);

        auto Hazard = State.Hazard;
        Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Disarmed));

        // Invalid when the trap moves no part.
        auto Mover = State.Mover;
        if (ck::IsValid(Mover))
        { Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::Start)); }
    }

    UFUNCTION()
    private void OnSinkPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        auto Trap = InSink.As_Trap();
        ApplyPowered(Trap, InPower == EMars_MechanismSink_Power::Powered);
    }

    UFUNCTION()
    private void OnHazardHit(FCk_Handle_Hazard InHazard, FCk_Handle InEntity)
    {
        auto Trap = InHazard.As_Trap();
        if (Trap.Has_Fragment(FMars_Fragment_Trap_Signals))
        { Trap.Get_Fragment(FMars_Fragment_Trap_Signals).OnTriggered.Broadcast(Trap, InEntity); }
    }
}
