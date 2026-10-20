// The Hazard tests' rig: a box trigger detecting Probe.Mars.Player at the test's origin, hazards composed around it on
// their own entities (no push: a zero PushImpulse), and kinematic Silent Probe.Mars.Player occupants in their own context
// teleported in and out. Every OnHit and OnArmedChanged of a hazard bound with BindSignals is recorded.
UCLASS(Abstract)
class UMars_AutoTestRig_Hazard : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: the trigger sees occupants through physics overlaps.
    protected const int32 k_SlowPolls = 900;

    protected FVector _Origin;
    protected FCk_Handle_Trigger _Trigger;
    protected FCk_Handle_Transform _Occupant;

    protected TArray<FCk_Handle_Hazard> _HitHazards;
    protected TArray<FCk_Handle> _HitEntities;
    protected TArray<EMars_Hazard_Arming> _ArmingChanges;

    protected void AddTriggerAndOccupant(FCk_Handle InHandle, FVector InOrigin)
    {
        _Origin = InOrigin;
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InOrigin), ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Trigger_Spec();
        Spec.Shape = EMars_Trigger_Shape::Box;
        Spec.BoxHalfExtents = FVector(150.0, 150.0, 100.0);
        Spec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        _Trigger = utils_trigger::Add(Root, Spec);

        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Owner.Request_OverrideToSelf();
        _Occupant = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, Get_OutsideLocation()), ECk_Replication::DoesNotReplicate);

        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(_Occupant, 30.0f, ProbeSpec);
    }

    // A pushless hazard through the rig's trigger on a new entity under the test entity.
    protected FCk_Handle_Hazard AddHazard(FCk_Handle InHandle, EMars_Hazard_Arming InStart)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Hazard_Spec();
        Spec.StartArmed = InStart == EMars_Hazard_Arming::Armed;
        Spec.Trigger = _Trigger;
        return utils_hazard::Add(Entity, Spec);
    }

    protected void BindSignals(FCk_Handle_Hazard InHazard)
    {
        auto Hazard = InHazard;
        Hazard.BindTo_OnHit(FMars_Delegate_Hazard_OnHit(this, n"OnRigHit"));
        Hazard.BindTo_OnArmedChanged(FMars_Delegate_Hazard_OnArmedChanged(this, n"OnRigArmedChanged"));
    }

    protected void MoveIn()
    {
        utils_transform::Request_SetLocation(_Occupant, FCk_Request_Transform_SetLocation(_Origin));
    }

    protected void MoveOut()
    {
        utils_transform::Request_SetLocation(_Occupant, FCk_Request_Transform_SetLocation(Get_OutsideLocation()));
    }

    protected int32 Get_HitCount(const FCk_Handle_Hazard& InHazard) const
    {
        auto Count = 0;
        for (const auto& Hazard : _HitHazards)
        {
            if (Hazard == InHazard)
            { ++Count; }
        }

        return Count;
    }

    UFUNCTION()
    protected void Check_OccupantInside(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Trigger.Get_EntityCount() == 1);
    }

    private FVector Get_OutsideLocation() const
    {
        return _Origin + FVector(1000.0, 0.0, 0.0);
    }

    UFUNCTION()
    private void OnRigHit(FCk_Handle_Hazard InHazard, FCk_Handle InEntity)
    {
        _HitHazards.Add(InHazard);
        _HitEntities.Add(InEntity);
    }

    UFUNCTION()
    private void OnRigArmedChanged(FCk_Handle_Hazard InHazard, EMars_Hazard_Arming InArming)
    {
        _ArmingChanges.Add(InArming);
    }
}
