// The Gaze tests' rig: the eye node in the test's isolated Z band, a spec that looks for player body probes and aims at
// their Head, and the foreign owners the gaze is pointed at.
UCLASS(Abstract)
class UMars_AutoTestRig_Gaze : UCk_AutoTest_Base
{
    protected FCk_Handle_Gaze _Gaze;

    // A transform root of its own at InLocation.
    protected FCk_Handle_Transform Make_EyeNode(FCk_Handle InHandle, FVector InLocation)
    {
        auto EyeEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        return utils_transform::Add(EyeEntity, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
    }

    protected FMars_Gaze_Spec MakeSpec() const
    {
        auto Spec = FMars_Gaze_Spec();
        Spec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        Spec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
        Spec.RangeCm = 300.0f;
        return Spec;
    }

    // Its own owner and context (so the gaze's probe may overlap it) with a kinematic Silent Probe.Mars.Player sphere like
    // the player's body probe, InLocalOffset from the owner's origin, and no attach points.
    protected FCk_Handle MakeOwner(FCk_Handle InHandle, FVector InLocation, FVector InLocalOffset = FVector::ZeroVector)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Owner.Request_OverrideToSelf();
        auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto BodyProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        BodyProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(Root, 20.0f, BodyProbeSpec, FTransform(FRotator::ZeroRotator, InLocalOffset));
        return Owner;
    }

    // Publishes a single attach point InLocalOffset from the owner's origin.
    protected void PublishPoint(FCk_Handle& InOwner, FGameplayTag InTag, FVector InLocalOffset = FVector::ZeroVector)
    {
        auto Root = InOwner.As_Transform();
        auto Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, InLocalOffset)).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(InTag, Node));
        utils_attach_points::Add(InOwner, AttachPointsSpec);
    }

    // MakeOwner with its Head attach point on the probe.
    protected FCk_Handle MakeTarget(FCk_Handle InHandle, FVector InLocation, FVector InLocalOffset = FVector::ZeroVector)
    {
        auto Owner = MakeOwner(InHandle, InLocation, InLocalOffset);
        PublishPoint(Owner, GameplayTags::AttachPoint_Mars_Head, InLocalOffset);
        return Owner;
    }

    protected FCk_Handle_Transform DoGet_Head(const FCk_Handle& InOwner) const
    {
        return InOwner.As_AttachPoints().Get_AttachPoint(GameplayTags::AttachPoint_Mars_Head);
    }

    // True when one of InOwner's probes is inside the gaze's sense trigger.
    protected bool DoGet_IsSensed(const FCk_Handle& InOwner) const
    {
        const auto& State = _Gaze.Get_Fragment(FMars_Fragment_Gaze);
        for (auto Entity : State.Sense.Get_EntitiesInside())
        {
            if (ck::Ctx(Entity) == InOwner)
            { return true; }
        }
        return false;
    }
}
