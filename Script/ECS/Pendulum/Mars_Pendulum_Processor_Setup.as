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

        if (ck::IsValid(Oscillator))
        { Oscillator.BindTo_OnRunningChanged(FMars_Delegate_Oscillator_OnRunningChanged(this, n"OnOscillatorRunningChanged")); }

        if (ck::IsValid(Hazard))
        {
            Hazard.BindTo_OnHit(FMars_Delegate_Hazard_OnHit(this, n"OnHazardHit"));
            Hazard.Request_SetArmed(ck::IsValid(Oscillator) && Oscillator.Get_IsRunning());
        }

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
        if (ck::IsValid(Oscillator))
        { Oscillator.Request_SetRunning(Running); }
    }

    private FCk_Handle_Pendulum Find_Pendulum(FCk_Handle_Oscillator InOscillator)
    {
        auto Pendulum = InOscillator.As_Pendulum(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Pendulum))
        { return Pendulum; }

        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InOscillator);
        if (ck::Is_NOT_Valid(Owner))
        { return FCk_Handle_Pendulum(); }

        return Owner.As_Pendulum(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void OnOscillatorRunningChanged(FCk_Handle_Oscillator InOscillator, bool InRunning)
    {
        auto Pendulum = Find_Pendulum(InOscillator);
        if (ck::Is_NOT_Valid(Pendulum))
        { return; }

        auto Hazard = Pendulum.Get_Fragment(FMars_Fragment_Pendulum).Hazard;
        if (ck::IsValid(Hazard))
        { Hazard.Request_SetArmed(InRunning); }
    }

    UFUNCTION()
    private void OnSinkPoweredChanged(FCk_Handle_MechanismSink InSink, bool InPowered)
    {
        auto Pendulum = InSink.As_Pendulum(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Pendulum))
        { return; }

        ApplyPowered(Pendulum, InPowered);
    }

    UFUNCTION()
    private void OnHazardHit(FCk_Handle_Hazard InHazard, FCk_Handle InEntity)
    {
        auto Pendulum = InHazard.As_Pendulum(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Pendulum))
        { return; }

        if (Pendulum.Has_Fragment(FMars_Fragment_Pendulum_Signals))
        { Pendulum.Get_Fragment(FMars_Fragment_Pendulum_Signals).OnTriggered.Broadcast(Pendulum, InEntity); }
    }
}
