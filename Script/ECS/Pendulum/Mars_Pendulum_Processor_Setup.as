// On the authority: gates the pendulum's Oscillator by an optional MechanismSink on the same entity, arms the Hazard
// while the bob swings (from a start until the oscillator reports rest, not merely until it is told to stop), forwards
// Hazard hits as OnTriggered, and writes the phase anchor (the only writer) at setup and at every run-state change and
// rest. A client wires none of it: it binds the anchor's rep-notify, reconciles once, and aligns its own oscillator to
// each new anchor.
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
        Pendulum.Request_TryRemove(FMars_Tag_Pendulum_NeedsSetup);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            InHandle.BindTo_OnRepNotify(FMars_Fragment_Pendulum, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
            Reconcile(Pendulum);
            return;
        }

        auto Oscillator = Pendulum.Get_Oscillator();
        auto Hazard = Pendulum.Get_Hazard();

        Oscillator.BindTo_OnRunningChanged(FMars_Delegate_Oscillator_OnRunningChanged(this, n"OnOscillatorRunningChanged"));
        Oscillator.BindTo_OnCameToRest(FMars_Delegate_Oscillator_OnCameToRest(this, n"OnOscillatorCameToRest"));

        Hazard.BindTo_OnHit(FMars_Delegate_Hazard_OnHit(this, n"OnHazardHit"));
        Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(Oscillator.Get_IsSwinging() ? EMars_Hazard_Arming::Armed : EMars_Hazard_Arming::Disarmed));

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Sink))
        {
            Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnSinkPoweredChanged"),
                ECk_Signal_BindingPolicy::FireIfPayloadInFlight);
        }

        WriteAnchor(Pendulum);
        Pendulum.Request_TryRemove(FMars_Fragment_Pendulum_Mirror);
    }

    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        auto Pendulum = InHandle.As_Pendulum();
        Reconcile(Pendulum);
    }

    // Broadcasts nothing itself (OnTriggered is a hit, the authority's): the oscillator's Align signals its own edges.
    private void Reconcile(FCk_Handle_Pendulum& InPendulum)
    {
        auto& Mirror = InPendulum.Get_Fragment(FMars_Fragment_Pendulum_Mirror);
        const auto LastAnchors = Mirror.Last.Anchors;
        Mirror.Last = InPendulum.Get_Fragment(FMars_Fragment_Pendulum);

        if (Mirror.Last.Anchors == LastAnchors)
        { return; }

        auto Oscillator = InPendulum.Get_Oscillator();
        Oscillator.Request_Align(FMars_Request_Oscillator_Align(InPendulum.Get_AnchoredSample()));
    }

    // Samples the oscillator after the state change that called it. Two writes in one frame replicate as the last.
    private void WriteAnchor(FCk_Handle_Pendulum& InPendulum)
    {
        const auto Swing = InPendulum.Get_Oscillator().Get_Sample();
        const auto Now = utils_mars_net::Get_ServerWorldSeconds(InPendulum);

        auto& Ledger = InPendulum.Get_Fragment(FMars_Fragment_Pendulum);
        Ledger.Swing = Swing;
        Ledger.AnchorServerSeconds = Now;
        Ledger.Anchors += 1;
        InPendulum.H().Request_MarkReplicationDirty(FMars_Fragment_Pendulum);
    }

    // The oscillator lives on the pendulum's entity or on a scene node directly under it (utils_pendulum::Add). The owner
    // is gone only while the pendulum is being torn down.
    private FCk_Handle_Pendulum Find_Pendulum(FCk_Handle_Oscillator InOscillator)
    {
        if (InOscillator.Is_Pendulum())
        { return InOscillator.As_Pendulum(); }

        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InOscillator);
        if (ck::Is_NOT_Valid(Owner))
        { return FCk_Handle_Pendulum(); }

        return Owner.As_Pendulum();
    }

    // A stop disarms nothing: the bob keeps swinging (easing out, or braking to its catch angle) until OnCameToRest.
    UFUNCTION()
    private void OnOscillatorRunningChanged(FCk_Handle_Oscillator InOscillator, EMars_Oscillator_RunState InRunState)
    {
        auto Pendulum = Find_Pendulum(InOscillator);
        if (ck::Is_NOT_Valid(Pendulum))
        { return; }

        WriteAnchor(Pendulum);

        if (InRunState != EMars_Oscillator_RunState::Running)
        { return; }

        auto Hazard = Pendulum.Get_Hazard();
        Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Armed));
    }

    UFUNCTION()
    private void OnOscillatorCameToRest(FCk_Handle_Oscillator InOscillator)
    {
        auto Pendulum = Find_Pendulum(InOscillator);
        if (ck::Is_NOT_Valid(Pendulum))
        { return; }

        WriteAnchor(Pendulum);
        auto Hazard = Pendulum.Get_Hazard();
        Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Disarmed));
    }

    UFUNCTION()
    private void OnSinkPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        auto Pendulum = InSink.As_Pendulum();
        const auto Powered = Pendulum.Get_Fragment(FMars_Fragment_Pendulum_Params).Powered;
        const auto Running = utils_mechanism_sink::Get_ShouldRun(Powered, InPower);

        auto Oscillator = Pendulum.Get_Oscillator();
        Oscillator.Request_SetRunning(FMars_Request_Oscillator_SetRunning(
            Running ? EMars_Oscillator_RunState::Running : EMars_Oscillator_RunState::Stopped));
    }

    UFUNCTION()
    private void OnHazardHit(FCk_Handle_Hazard InHazard, FCk_Handle InEntity)
    {
        auto Pendulum = InHazard.As_Pendulum();
        if (Pendulum.Has_Fragment(FMars_Fragment_Pendulum_Signals))
        { Pendulum.Get_Fragment(FMars_Fragment_Pendulum_Signals).OnTriggered.Broadcast(Pendulum, InEntity); }
    }
}
