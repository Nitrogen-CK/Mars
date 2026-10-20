// The Occupancy tests' rig: a box trigger detecting Probe.Mars.Player on its own entity at the test's origin, occupancies
// composed on further entities around it, and kinematic Silent Probe.Mars.Player occupants (each in its own context, like
// the player's body probe) teleported in and out. Each test sets its own isolated origin.
UCLASS(Abstract)
class UMars_AutoTestRig_Occupancy : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: the trigger sees occupants come and go through physics overlaps.
    protected const int32 k_SlowPolls = 900;

    protected FVector _Origin;
    protected FCk_Handle_Trigger _Trigger;
    protected TArray<FCk_Handle_Transform> _Occupants;

    // One entry per OnActiveChanged of the occupancy bound with BindActiveChanges.
    protected TArray<EMars_Occupancy_Activation> _ActiveChanges;

    private const FVector k_TriggerHalfExtents = FVector(150.0, 150.0, 100.0);

    protected void AddTrigger(FCk_Handle InHandle, FVector InOrigin)
    {
        _Origin = InOrigin;
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InOrigin), ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Trigger_Spec();
        Spec.Shape = EMars_Trigger_Shape::Box;
        Spec.BoxHalfExtents = k_TriggerHalfExtents;
        Spec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        _Trigger = utils_trigger::Add(Root, Spec);
    }

    // A spec counting through the rig's trigger.
    protected FMars_Occupancy_Spec Make_Spec(int32 InRequiredCount, float32 InReleaseDelaySeconds) const
    {
        auto Spec = FMars_Occupancy_Spec();
        Spec.RequiredCount = InRequiredCount;
        Spec.ReleaseDelaySeconds = InReleaseDelaySeconds;
        Spec.Parts = FMars_Occupancy_Parts(_Trigger);
        return Spec;
    }

    // utils_occupancy::Add on a new entity under the test entity.
    protected FCk_Handle_Occupancy AddOccupancy(FCk_Handle InHandle, FMars_Occupancy_Spec InSpec)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        return utils_occupancy::Add(Entity, InSpec);
    }

    protected void BindActiveChanges(FCk_Handle_Occupancy InOccupancy)
    {
        auto Occupancy = InOccupancy;
        Occupancy.BindTo_OnActiveChanged(FMars_Delegate_Occupancy_OnActiveChanged(this, n"OnRigActiveChanged"));
    }

    // InCount occupants, all outside the trigger.
    protected void AddOccupants(FCk_Handle InHandle, int32 InCount)
    {
        for (int32 Index = 0; Index < InCount; ++Index)
        {
            auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
            Owner.Request_OverrideToSelf();
            auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, Get_OutsideLocation(Index)), ECk_Replication::DoesNotReplicate);

            auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
            ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
            utils_prefab::Create_ProbeNode_Sphere(Root, 30.0f, ProbeSpec);
            _Occupants.Add(Root);
        }
    }

    protected void MoveIn(int32 InIndex)
    {
        auto Occupant = _Occupants[InIndex];
        utils_transform::Request_SetLocation(Occupant, FCk_Request_Transform_SetLocation(_Origin + FVector(InIndex * 40.0, 0.0, 0.0)));
    }

    protected void MoveOut(int32 InIndex)
    {
        auto Occupant = _Occupants[InIndex];
        utils_transform::Request_SetLocation(Occupant, FCk_Request_Transform_SetLocation(Get_OutsideLocation(InIndex)));
    }

    protected FCk_Handle_Timer Get_ReleaseTimer(const FCk_Handle_Occupancy& InOccupancy) const
    {
        return InOccupancy.Get_Fragment(FMars_Fragment_Occupancy).ReleaseTimer;
    }

    private FVector Get_OutsideLocation(int32 InIndex) const
    {
        return _Origin + FVector(1000.0 + InIndex * 200.0, 0.0, 0.0);
    }

    UFUNCTION()
    private void OnRigActiveChanged(FCk_Handle_Occupancy InOccupancy, EMars_Occupancy_Activation InActivation)
    {
        _ActiveChanges.Add(InActivation);
    }
}
