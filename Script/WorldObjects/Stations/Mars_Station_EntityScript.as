// Base placeable station: composes the transform and the Station feature (see FMars_Station_Spec for the frame: the root
// is the station's origin on the floor; the operator stands at StandLocal facing its +X). Concrete stations fill in the
// geometry-bound spec fields (stand, grip), the Use probe and the visuals.
UCLASS(Abstract)
class UMars_Station_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Not a `default` in subclasses: set geometry-bound fields in Configure_Spec (the spawn-params generator emits a
    // non-default script struct as a positional constructor call).
    UPROPERTY(ExposeOnSpawn)
    FMars_Station_Spec Station;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        auto Spec = Station;
        Configure_Spec(Spec);

        // A rejected spec already ensured in utils_station::Add.
        auto StationHandle = utils_station::Add(Root, Spec, Make_Probe());
        if (ck::IsValid(StationHandle))
        { AddVisuals(Root); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec)
    {
    }

    // Unset = a transform-only Use interactable (no view-trace focus).
    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const
    {
        return TOptional<FMars_Interactable_ProbeInfo>();
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot)
    {
    }

    // NewObject needs a UObject outer, hence a method on the entity script.
    protected void AddMesh(
        FCk_Handle_Transform& InAttachTo,
        FTransform InLocalTransform,
        UStaticMesh InMesh,
        UMaterialInterface InMaterial,
        FName InDebugName)
    {
        if (ck::Is_NOT_Valid(InMesh))
        { return; }

        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);
        auto NodeEntity = FCk_Handle(Node);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable even when static: the component is registered first and then receives the entity transform,
        // which a Static component refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(InMesh);
        if (ck::IsValid(InMaterial))
        { Archetype.SetMaterial(0, InMaterial); }
        Archetype.SetCollisionProfileName(collision::profile::BlockAll);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        utils_unreal_component::Add(NodeEntity, ComponentParams);
    }
}
