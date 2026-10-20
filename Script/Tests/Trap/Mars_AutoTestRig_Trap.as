// The Trap tests' rig: a spike-shaped trap (Safe / Warn / Active, the part rising on Warn and the hazard armed on Active,
// Safe resetting both) with short phases, composed on one entity with its trigger, pushless hazard and mover, as
// Mars_SpikeTrap_EntityScript composes it. OnPhaseChanged of its cycle is recorded.
UCLASS(Abstract)
class UMars_AutoTestRig_Trap : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: the cycle steps through timed phases.
    protected const int32 k_SlowPolls = 900;

    protected FCk_Handle _Entity;
    protected FCk_Handle_Trap _Trap;
    protected FCk_Handle_Hazard _Hazard;
    protected FCk_Handle_Mover _Mover;
    protected FCk_Handle_Cycle _Cycle;
    protected TArray<FGameplayTag> _Phases;

    protected FCk_Handle_Trap AddTrap(FCk_Handle InHandle, FVector InOrigin, EMars_PoweredBehavior InPowered)
    {
        _Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Entity, FTransform(FRotator::ZeroRotator, InOrigin), ECk_Replication::DoesNotReplicate);

        auto Node = utils_scene_node::Create(Root, FTransform::Identity);
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = FVector(0.0, 0.0, 60.0);
        MoverSpec.Duration = 0.05f;
        _Mover = utils_mover::Add(Node, MoverSpec);

        auto TriggerSpec = FMars_Trigger_Spec();
        TriggerSpec.BoxHalfExtents = FVector(100.0, 100.0, 50.0);
        TriggerSpec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        auto Trigger = utils_trigger::Add(Root, TriggerSpec);

        auto HazardSpec = FMars_Hazard_Spec();
        HazardSpec.Trigger = Trigger;
        _Hazard = utils_hazard::Add(_Entity, HazardSpec);

        auto Spec = utils_trap::Make_SpikeTrapSpec();
        Spec.Cycle.Phases[0].Duration = 0.3f;
        Spec.Cycle.Phases[1].Duration = 0.2f;
        Spec.Cycle.Phases[2].Duration = 0.3f;
        Spec.Powered = InPowered;
        Spec.Parts = FMars_Trap_Parts(_Hazard, _Mover);
        _Trap = utils_trap::Add(_Entity, Spec);

        _Cycle = _Trap.Get_Cycle();
        _Cycle.BindTo_OnPhaseChanged(FMars_Delegate_Cycle_OnPhaseChanged(this, n"OnRigPhaseChanged"));
        return _Trap;
    }

    UFUNCTION()
    private void OnRigPhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex)
    {
        _Phases.Add(InPhase);
    }
}
