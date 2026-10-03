// Placeable swinging pendulum. The origin is on the floor below the pivot, which sits ArmLength + 50 uu up. The pivot
// node's Oscillator swings the arm and the bob hung from it; the bob carries a moving trigger whose push hazard is
// armed while the swing runs. An optional MechanismSink gates the swing per Pendulum.Powered.
class UMars_Pendulum_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Oscillator_Spec Oscillator;

    // A zero PushImpulse takes the pendulum's push along local +X. Not a `default`: the spawn-params generator emits
    // a non-default script struct as a positional constructor call, which script structs do not have.
    UPROPERTY(ExposeOnSpawn)
    FMars_Hazard_Spec Hazard;

    UPROPERTY(ExposeOnSpawn)
    FMars_Pendulum_Spec Pendulum;

    // No sink is added while InputChannels is empty.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSink_Spec Sink;

    // Pivot to bob centre.
    UPROPERTY(ExposeOnSpawn)
    float32 ArmLength = 250.0f;

    // Height of the resting bob's centre above the origin; with BobSize it leaves 10 uu under the bob.
    private const float64 PivotClearance = 50.0;
    private const float64 BobSize = 80.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto PendulumRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsPendulum");

        const auto PivotHeight = ArmLength + PivotClearance;

        auto PivotNode = utils_scene_node::Create(PendulumRoot,
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PivotHeight), FVector::OneVector));
        auto PivotTransform = PivotNode.As_Transform();
        auto BobNode = utils_scene_node::Create(PivotTransform,
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -ArmLength), FVector::OneVector));

        auto OscillatorHandle = utils_oscillator::Add(PivotNode, Oscillator);

        auto TriggerSpec = FMars_Trigger_Spec();
        TriggerSpec.Shape = EMars_Trigger_Shape::Box;
        TriggerSpec.BoxHalfExtents = FVector::OneVector * (BobSize * 0.5);
        TriggerSpec.DetectionFilter = GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_Player);
        TriggerSpec.Moving = true;
        auto BobTransform = BobNode.As_Transform();
        auto Trigger = utils_trigger::Add(BobTransform, TriggerSpec);

        auto HazardSpec = Hazard;
        if (HazardSpec.PushImpulse.IsNearlyZero())
        { HazardSpec.PushImpulse = FVector(600.0, 0.0, 300.0); }
        auto HazardHandle = utils_hazard::Add(InHandle, HazardSpec, Trigger);

        utils_pendulum::Add(InHandle, Pendulum, FMars_Pendulum_Parts(OscillatorHandle, HazardHandle));

        if (Sink.InputChannels.Num() > 0)
        { utils_mechanism_sink::Add(InHandle, Sink); }

        AddVisuals(PendulumRoot, PivotTransform, BobTransform);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_Transform& InPivot, FCk_Handle_Transform& InBob)
    {
        auto CubeMesh = engine::load::Cube();
        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
        auto HazardMaterial = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine cube is 100 uu with its pivot at the centre.
        const auto PivotHeight = ArmLength + PivotClearance;
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PivotHeight), FVector(60.0, 60.0, 40.0) * 0.01),
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"Pendulum_PivotBlock"));

        InPivot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -ArmLength * 0.5), FVector(10.0, 10.0, ArmLength) * 0.01),
            CubeMesh, HazardMaterial, collision::profile::NoCollision, n"Pendulum_Arm"));

        InBob.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector::OneVector * (BobSize * 0.01)),
            CubeMesh, HazardMaterial, collision::profile::NoCollision, n"Pendulum_Bob"));
    }
}
