// Placeable steam vent. The origin is the base of the nozzle block; the jet fires along local +X from the nozzle mouth.
// A looping Trap cycle (Idle / Telegraph / Fire) arms the push hazard in front of the nozzle on Fire. The steam cube is
// visual only: small on Telegraph, full length on Fire, hidden otherwise. An optional MechanismSink gates the cycle
// per Trap.Powered.
class UMars_Vent_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Trap_Spec Trap = utils_trap::Make_VentSpec();

    // No sink is added while InputChannels is empty.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSink_Spec Sink;

    // A zero PushImpulse takes the vent's push away from the nozzle. Not a `default`: the spawn-params generator emits
    // a non-default script struct as a positional constructor call, which script structs do not have.
    UPROPERTY(ExposeOnSpawn)
    FMars_Hazard_Spec Hazard;

    private FCk_Handle_SceneNode SteamPivot;

    private const FVector NozzleMouth = FVector(30.0, 0.0, 60.0);
    private const float64 JetLength = 300.0;
    private const float64 JetWidth = 80.0;

    // Scale of the steam pivot, whose child is a 100 uu cube: X is length, Y/Z the cross-section (in hundreds of uu).
    private const FVector SteamScale_Hidden = FVector(0.01, 0.01, 0.01);
    private const FVector SteamScale_Telegraph = FVector(0.6, 0.35, 0.35);
    private const FVector SteamScale_Fire = FVector(3.0, 0.8, 0.8);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto VentRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsVent");

        // Scaling the pivot scales the steam cube hung in front of it, so the jet always grows out of the nozzle mouth.
        SteamPivot = utils_scene_node::Create(VentRoot,
            FTransform(FRotator::ZeroRotator, NozzleMouth, SteamScale_Hidden));

        auto TriggerSpec = FMars_Trigger_Spec();
        TriggerSpec.Shape = EMars_Trigger_Shape::Box;
        TriggerSpec.BoxHalfExtents = FVector(JetLength * 0.5, JetWidth * 0.5, JetWidth * 0.5);
        TriggerSpec.LocalOffset = FTransform(FRotator::ZeroRotator,
            NozzleMouth + FVector(JetLength * 0.5, 0.0, 0.0), FVector::OneVector);
        TriggerSpec.DetectionFilter = GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Player"));
        auto Trigger = utils_trigger::Add(VentRoot, TriggerSpec);

        auto HazardSpec = Hazard;
        if (HazardSpec.PushImpulse.IsNearlyZero())
        { HazardSpec.PushImpulse = FVector(900.0, 0.0, 250.0); }
        auto HazardHandle = utils_hazard::Add(InHandle, HazardSpec, Trigger);

        utils_trap::Add(InHandle, utils_trap::Resolve_Spec(Trap, utils_trap::Make_VentSpec()), HazardHandle, FCk_Handle_Mover());

        if (Sink.InputChannels.Num() > 0)
        { utils_mechanism_sink::Add(InHandle, Sink); }

        AddVisuals(VentRoot);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Cycle = InHandle.As_Cycle(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Cycle))
        { return; }

        Cycle.BindTo_OnPhaseChanged(FMars_Delegate_Cycle_OnPhaseChanged(this, n"OnCyclePhaseChanged"));
        Cycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnCycleRunningChanged"));

        if (Cycle.Get_IsRunning())
        { ShowSteamForPhase(Cycle.Get_CurrentPhase()); }
    }

    UFUNCTION()
    private void OnCyclePhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex)
    {
        ShowSteamForPhase(InPhase);
    }

    UFUNCTION()
    private void OnCycleRunningChanged(FCk_Handle_Cycle InCycle, bool InRunning)
    {
        if (InRunning == false)
        { SetSteamScale(SteamScale_Hidden); }
    }

    private void ShowSteamForPhase(FGameplayTag InPhase)
    {
        if (InPhase == GameplayTags::ResolveGameplayTag(n"Mechanism.Phase.Fire"))
        {
            SetSteamScale(SteamScale_Fire);
            return;
        }

        if (InPhase == GameplayTags::ResolveGameplayTag(n"Mechanism.Phase.Telegraph"))
        {
            SetSteamScale(SteamScale_Telegraph);
            return;
        }

        SetSteamScale(SteamScale_Hidden);
    }

    private void SetSteamScale(FVector InScale)
    {
        if (ck::Is_NOT_Valid(SteamPivot))
        { return; }

        utils_scene_node::Request_UpdateOffset_Scale(SteamPivot, InScale, ECk_RelativeAbsolute::Absolute);
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        auto CubeMesh = engine::load::Cube();
        if (ck::Is_NOT_Valid(CubeMesh))
        { return; }

        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();

        // Engine cube is 100 uu with its pivot at the centre. The nozzle block ends at the nozzle mouth.
        const auto NozzleDepth = NozzleMouth.X * 2.0;
        const auto NozzleHeight = NozzleMouth.Z + JetWidth;
        AddBox(InRoot, FVector(0.0, 0.0, NozzleHeight * 0.5), FVector(NozzleDepth, JetWidth * 1.4, NozzleHeight) * 0.01,
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"Vent_Nozzle");

        // A unit cube half a length in front of the pivot: the pivot's scale is the jet's length and cross-section.
        auto SteamTransform = SteamPivot.As_Transform();
        AddBox(SteamTransform, FVector(50.0, 0.0, 0.0), FVector::OneVector,
            CubeMesh, WallMaterial, collision::profile::NoCollision, n"Vent_Steam");
    }

    // NewObject needs a UObject outer, hence a private method on the entity script.
    private void AddBox(
        FCk_Handle_Transform& InAttachTo,
        FVector InLocation,
        FVector InScale,
        UStaticMesh InMesh,
        UMaterialInterface InMaterial,
        FName InCollisionProfile,
        FName InDebugName)
    {
        auto Node = utils_scene_node::Create(InAttachTo, FTransform(FRotator::ZeroRotator, InLocation, InScale));
        auto NodeEntity = FCk_Handle(Node);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable even when static: the component is registered first and then receives the entity transform,
        // which a Static component refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(InMesh);
        if (ck::IsValid(InMaterial))
        { Archetype.SetMaterial(0, InMaterial); }
        Archetype.SetCollisionProfileName(InCollisionProfile);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        utils_unreal_component::Add(NodeEntity, ComponentParams);
    }
}
