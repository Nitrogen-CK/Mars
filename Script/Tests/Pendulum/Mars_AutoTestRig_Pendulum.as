// The Pendulum tests' rig: a pendulum composed as Mars_Pendulum_EntityScript composes it (pivot node with the oscillator,
// bob node with a moving trigger, pushless hazard and the pendulum on one entity), with a fast swing: amplitude 30,
// period 1 s. OnArmedChanged of its hazard and OnCameToRest of its oscillator are counted.
UCLASS(Abstract)
class UMars_AutoTestRig_Pendulum : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: a swing settles or reaches its catch angle within a period or so.
    protected const int32 k_SlowPolls = 900;

    protected FCk_Handle _Entity;
    protected FCk_Handle_Pendulum _Pendulum;
    protected FCk_Handle_Oscillator _Oscillator;
    protected FCk_Handle_Hazard _Hazard;
    protected int32 _ArmedEdges = 0;
    protected int32 _DisarmedEdges = 0;
    protected int32 _RestCount = 0;

    protected FMars_Oscillator_Spec Make_SwingSpec() const
    {
        auto Spec = FMars_Oscillator_Spec();
        Spec.AmplitudeDegrees = 30.0f;
        Spec.PeriodSeconds = 1.0f;
        Spec.SettleSeconds = 0.3f;
        return Spec;
    }

    protected void AddPendulum(FCk_Handle InHandle, FVector InOrigin, FMars_Oscillator_Spec InSwing, EMars_PoweredBehavior InPowered)
    {
        _Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Entity, FTransform(FRotator::ZeroRotator, InOrigin), ECk_Replication::DoesNotReplicate);

        auto Pivot = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 300.0)));
        auto PivotTransform = Pivot.As_Transform();
        auto Bob = utils_scene_node::Create(PivotTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -250.0)));
        _Oscillator = utils_oscillator::Add(Pivot, InSwing);

        auto TriggerSpec = FMars_Trigger_Spec();
        TriggerSpec.BoxHalfExtents = FVector(40.0, 40.0, 40.0);
        TriggerSpec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        TriggerSpec.Moving = true;
        auto BobTransform = Bob.As_Transform();
        auto Trigger = utils_trigger::Add(BobTransform, TriggerSpec);

        auto HazardSpec = FMars_Hazard_Spec();
        HazardSpec.Trigger = Trigger;
        _Hazard = utils_hazard::Add(_Entity, HazardSpec);
        _Hazard.BindTo_OnArmedChanged(FMars_Delegate_Hazard_OnArmedChanged(this, n"OnRigArmedChanged"));

        auto Spec = FMars_Pendulum_Spec();
        Spec.Powered = InPowered;
        Spec.Parts = FMars_Pendulum_Parts(_Oscillator, _Hazard);
        _Pendulum = utils_pendulum::Add(_Entity, Spec);

        _Oscillator.BindTo_OnCameToRest(FMars_Delegate_Oscillator_OnCameToRest(this, n"OnRigCameToRest"));
    }

    UFUNCTION()
    private void OnRigArmedChanged(FCk_Handle_Hazard InHazard, EMars_Hazard_Arming InArming)
    {
        if (InArming == EMars_Hazard_Arming::Armed)
        { ++_ArmedEdges; }
        else
        { ++_DisarmedEdges; }
    }

    UFUNCTION()
    private void OnRigCameToRest(FCk_Handle_Oscillator InOscillator)
    {
        ++_RestCount;
    }
}
