// Gates the pendulum's Oscillator by an optional MechanismSink on the same entity, arms the Hazard while the
// Oscillator runs, and forwards Hazard hits as OnTriggered.
class UMars_Processor_Pendulum_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Pendulum_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Pendulum);
        Query.Require(FMars_Tag_Pendulum_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Pendulum = InHandle.As_Pendulum();
        const auto& State = Pendulum.Get_Fragment(FMars_Fragment_Pendulum);

        auto Oscillator = State.Oscillator;
        auto Hazard = State.Hazard;

        Oscillator.BindTo_OnRunningChanged(FMars_Delegate_Oscillator_OnRunningChanged(this, n"OnOscillatorRunningChanged"));

        Hazard.BindTo_OnHit(FMars_Delegate_Hazard_OnHit(this, n"OnHazardHit"));
        Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(Oscillator.Get_IsRunning() ? EMars_Hazard_Arming::Armed : EMars_Hazard_Arming::Disarmed));

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Sink))
        {
            Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnSinkPoweredChanged"));
            if (Sink.Get_HasEvaluated())
            { ApplyPowered(Pendulum, Sink.Get_IsPowered()); }
        }

        Pendulum.Request_TryRemove(FMars_Tag_Pendulum_NeedsSetup);
    }

    private void ApplyPowered(FCk_Handle_Pendulum& InPendulum, bool InPowered)
    {
        const auto& Params = InPendulum.Get_Fragment(FMars_Fragment_Pendulum_Params);
        const auto Running = Params.Powered == EMars_PoweredBehavior::RunWhilePowered ? InPowered : (InPowered == false);

        auto Oscillator = InPendulum.Get_Fragment(FMars_Fragment_Pendulum).Oscillator;
        Oscillator.Request_SetRunning(FMars_Request_Oscillator_SetRunning(
            Running ? EMars_Oscillator_RunState::Running : EMars_Oscillator_RunState::Stopped));
    }

    // The oscillator lives on the pendulum's entity or on a scene node directly under it (utils_pendulum::Add).
    private FCk_Handle_Pendulum Find_Pendulum(FCk_Handle_Oscillator InOscillator)
    {
        if (InOscillator.Is_Pendulum())
        { return InOscillator.As_Pendulum(); }

        return utils_entity_lifetime::Get_LifetimeOwner(InOscillator).As_Pendulum();
    }

    UFUNCTION()
    private void OnOscillatorRunningChanged(FCk_Handle_Oscillator InOscillator, EMars_Oscillator_RunState InRunState)
    {
        auto Pendulum = Find_Pendulum(InOscillator);
        auto Hazard = Pendulum.Get_Fragment(FMars_Fragment_Pendulum).Hazard;
        Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(
            InRunState == EMars_Oscillator_RunState::Running ? EMars_Hazard_Arming::Armed : EMars_Hazard_Arming::Disarmed));
    }

    UFUNCTION()
    private void OnSinkPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        auto Pendulum = InSink.As_Pendulum();
        ApplyPowered(Pendulum, InPower == EMars_MechanismSink_Power::Powered);
    }

    UFUNCTION()
    private void OnHazardHit(FCk_Handle_Hazard InHazard, FCk_Handle InEntity)
    {
        auto Pendulum = InHazard.As_Pendulum();
        if (Pendulum.Has_Fragment(FMars_Fragment_Pendulum_Signals))
        { Pendulum.Get_Fragment(FMars_Fragment_Pendulum_Signals).OnTriggered.Broadcast(Pendulum, InEntity); }
    }
}
