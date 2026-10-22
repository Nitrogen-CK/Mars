// Real BurstVent Trap/Cycle/Hazard, directly owned and without a Sink. Legacy powered-coupling red source/results are
// retained in Phase4 evidence; this new topology is deliberate and does not repair legacy source-only consumers.
UCLASS(Abstract)
class UMars_AutoTestRig_BellkeeperDedicatedVent : UMars_AutoTestRig_Bellkeeper
{
    protected FCk_Handle_Cycle _VentCycle;
    protected FCk_Handle_Hazard _Hazard;
    protected TArray<float64> _TelegraphTimes;
    protected TArray<float64> _FireTimes;
    protected TArray<float64> _StopTimes;

    protected void AddDedicatedLock(FCk_Handle InHandle)
    {
        auto Spec = Make_Parts(InHandle);
        Spec.VentPulseSeconds = 2.0f;
        auto VentEntity = utils_entity_lifetime::Request_CreateEntity(_Entity);
        auto Root = utils_transform::Add(VentEntity, FTransform(FVector(40000.0, 340000.0, -41000.0)), ECk_Replication::DoesNotReplicate);
        auto TriggerSpec = FMars_Trigger_Spec();
        TriggerSpec.BoxHalfExtents = FVector(100.0, 100.0, 50.0);
        TriggerSpec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        auto Trigger = utils_trigger::Add(Root, TriggerSpec);
        auto HazardSpec = FMars_Hazard_Spec();
        HazardSpec.Trigger = Trigger;
        _Hazard = utils_hazard::Add(VentEntity, HazardSpec);
        auto TrapSpec = utils_trap::Make_BurstVentSpec();
        TrapSpec.Parts = FMars_Trap_Parts(_Hazard);
        auto Trap = utils_trap::Add(VentEntity, TrapSpec);
        _VentCycle = Trap.Get_Cycle();
        Spec.VentCycle = _VentCycle;
        auto CommitSink = FMars_MechanismSink_Spec();
        CommitSink.InputChannels.Add(GameplayTags::Mechanism_Channel_J);
        utils_mechanism_sink::Add(_Entity, CommitSink);
        auto OutputSpec = FMars_MechanismSource_Spec();
        OutputSpec.OutputChannel = GameplayTags::Mechanism_Channel_L;
        _OutputSource = utils_mechanism_source::Add(_Entity, OutputSpec);
        _Bellkeeper = utils_bellkeeper::Add(_Entity, Spec);
        _VentCycle.BindTo_OnPhaseChanged(FMars_Delegate_Cycle_OnPhaseChanged(this, n"OnDedicatedPhase"));
        _VentCycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnDedicatedRunning"));
    }

    protected bool Get_IsTelegraphing() const
    {
        return _VentCycle.Get_IsRunning() && _VentCycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Telegraph
            && _Hazard.Get_IsArmed() == false;
    }

    protected bool Get_IsFiring() const
    {
        return _VentCycle.Get_IsRunning() && _VentCycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Fire
            && _Hazard.Get_IsArmed();
    }

    UFUNCTION()
    private void OnDedicatedPhase(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex)
    {
        const auto Time = System::GetGameTimeInSeconds();
        if (InPhase == GameplayTags::Mechanism_Phase_Telegraph)
        { _TelegraphTimes.Add(Time); }
        if (InPhase == GameplayTags::Mechanism_Phase_Fire)
        { _FireTimes.Add(Time); }
        Log(f"[BellkeeperDedicated] phase={InIndex} time={Time} telegraphs={_TelegraphTimes.Num()} fires={_FireTimes.Num()}");
    }

    UFUNCTION()
    private void OnDedicatedRunning(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InState)
    {
        if (InState == EMars_Cycle_RunState::Stopped)
        { _StopTimes.Add(System::GetGameTimeInSeconds()); }
        Log(f"[BellkeeperDedicated] running={InCycle.Get_IsRunning()} state={InState :n} time={System::GetGameTimeInSeconds()}");
    }
}
