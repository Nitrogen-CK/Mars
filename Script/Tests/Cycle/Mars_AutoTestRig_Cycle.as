// The Cycle tests' rig: a three-phase cycle (Idle, Telegraph, Fire; 0.15 s each) on its own entity, with OnPhaseChanged
// and OnRunningChanged recorded.
UCLASS(Abstract)
class UMars_AutoTestRig_Cycle : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: phases advance on their timers.
    protected const int32 k_SlowPolls = 900;
    protected const float32 k_PhaseSeconds = 0.15f;

    protected FCk_Handle_Cycle _Cycle;
    protected TArray<FGameplayTag> _Phases;
    protected TArray<int32> _PhaseIndices;
    protected TArray<EMars_Cycle_RunState> _RunChanges;

    protected FMars_Cycle_Spec Make_Spec(bool InLoop) const
    {
        auto Spec = FMars_Cycle_Spec();
        Spec.Phases.Add(FMars_CyclePhase(GameplayTags::Mechanism_Phase_Idle, k_PhaseSeconds));
        Spec.Phases.Add(FMars_CyclePhase(GameplayTags::Mechanism_Phase_Telegraph, k_PhaseSeconds));
        Spec.Phases.Add(FMars_CyclePhase(GameplayTags::Mechanism_Phase_Fire, k_PhaseSeconds));
        Spec.Loop = InLoop;
        Spec.StartRunning = true;
        return Spec;
    }

    protected FCk_Handle_Cycle AddCycle(FCk_Handle InHandle, FMars_Cycle_Spec InSpec)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Cycle = utils_cycle::Add(Entity, InSpec);
        _Cycle.BindTo_OnPhaseChanged(FMars_Delegate_Cycle_OnPhaseChanged(this, n"OnRigPhaseChanged"));
        _Cycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnRigRunningChanged"));
        return _Cycle;
    }

    UFUNCTION()
    private void OnRigPhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex)
    {
        _Phases.Add(InPhase);
        _PhaseIndices.Add(InIndex);
    }

    UFUNCTION()
    private void OnRigRunningChanged(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState)
    {
        _RunChanges.Add(InRunState);
    }
}
