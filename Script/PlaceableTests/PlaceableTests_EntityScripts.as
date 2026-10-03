// Language=angelscript
// Minimal EntityScripts that opt in to the editor's "Ck Entity Scripts" tab of the Place Actors panel
// (`_ShowInPlaceActors`). A drop spawns an ACk_EntitySpawner_UE with the script assigned; the spawner injects the placed
// actor's world transform into `SpawnTransform`. Non-replicated, so they spawn immediately (no ActorRelay channel).

// Transform + tag only: validates drag-to-spawn and transform injection with no visual dependency.
class UCk_PlaceableTest_Marker_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_PlaceableTest_Marker");
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

// Renders an ISM cube at the placed transform.
class UCk_PlaceableTest_Cube_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_PlaceableTest_Cube");

        auto IsmProxyParams = FCk_IsmProxy_Spec(ck::Asset_PlaceableTest_Cube);
        auto IsmProxyTransform = InHandle.As_Transform();
        utils_ism_proxy::Add(IsmProxyTransform, IsmProxyParams);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

// Renders an ISM sphere at the placed transform; a second visible entry so the panel lists several scripts.
class UCk_PlaceableTest_Sphere_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_PlaceableTest_Sphere");

        auto IsmProxyParams = FCk_IsmProxy_Spec(ck::Asset_PlaceableTest_Sphere);
        auto IsmProxyTransform = InHandle.As_Transform();
        utils_ism_proxy::Add(IsmProxyTransform, IsmProxyParams);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

// Renders a real UStaticMeshComponent (cylinder) through CkUnrealComponent, the other editor-preview visual path. The
// component is mounted on a scene-node child rather than the script entity: scene nodes are lifetime children of their
// anchor, so editor-selection-owner resolution must walk through them (clicking the floating cylinder selects the
// spawner below it). Component setup is async, so the mesh is assigned in the OnAdded handler.
class UCk_PlaceableTest_MeshComponent_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_PlaceableTest_MeshComponent");

        auto TransformHandle = InHandle.As_Transform();
        auto MountLocalTransform = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 100.0), FVector::OneVector);
        auto MountSceneNode = utils_scene_node::Create(TransformHandle, MountLocalTransform);

        const auto Params = utils_unreal_component::Make_Params(UStaticMeshComponent, ECk_UnrealComponent_TickPolicy::DoNotTick, n"PlaceableTest_MeshComponent");
        auto ComponentHandle = utils_unreal_component::Add(MountSceneNode.H(), Params);

        utils_unreal_component::BindTo_OnAdded(
            ComponentHandle,
            FCk_Delegate_UnrealComponent_OnAdded(this, n"OnMeshComponentAdded"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION()
    private void OnMeshComponentAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(Mesh), "[PlaceableTest_MeshComponent] the added component is not a UStaticMeshComponent"))
        { return; }

        Mesh.SetCollisionEnabled(ECollisionEnabled::NoCollision);

        auto Cylinder = Cast<UStaticMesh>(LoadObject(this, "/Engine/BasicShapes/Cylinder.Cylinder"));
        if (ck::EnsureIfNot(ck::IsValid(Cylinder), "[PlaceableTest_MeshComponent] the engine cylinder mesh failed to load"))
        { return; }

        Mesh.SetStaticMesh(Cylinder);
    }
}
