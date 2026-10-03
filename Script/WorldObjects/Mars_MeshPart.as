// One static mesh on its own scene node under a transform: the visual parts entity scripts build from engine shapes and
// the mechanism meshes.
struct FMars_MeshPart
{
    // Relative to the transform the part is added to; its scale sizes the mesh.
    UPROPERTY()
    FTransform LocalTransform = FTransform::Identity;

    UPROPERTY()
    UStaticMesh Mesh;

    // Unset keeps the mesh's own material.
    UPROPERTY()
    UMaterialInterface Material;

    UPROPERTY()
    FName CollisionProfile = collision::profile::NoCollision;

    UPROPERTY()
    FName DebugName;

    // Set: the part's material slot 0 gets a dynamic instance with this PrimaryColor.
    UPROPERTY()
    TOptional<FLinearColor> PrimaryColor;

    UPROPERTY()
    bool CastShadow = true;

    FMars_MeshPart() {}

    FMars_MeshPart(FTransform InLocalTransform, UStaticMesh InMesh, UMaterialInterface InMaterial, FName InCollisionProfile, FName InDebugName)
    {
        LocalTransform = InLocalTransform;
        Mesh = InMesh;
        Material = InMaterial;
        CollisionProfile = InCollisionProfile;
        DebugName = InDebugName;
    }
}

// Adds InPart on a new scene node under Self and returns its component handle (the component itself is created later).
// NewObject needs a UObject outer for the component archetype, hence InOuter: the entity script building the part.
mixin FCk_Handle_UnrealComponent Add_MeshPart(FCk_Handle_Transform& Self, UObject InOuter, const FMars_MeshPart& InPart)
{
    if (ck::EnsureIfNot(ck::IsValid(InPart.Mesh), f"[MeshPart] [{InPart.DebugName.ToString()}] on [{Self.ToString()}] has no mesh; the part is left out"))
    { return FCk_Handle_UnrealComponent(); }

    auto Node = utils_scene_node::Create(Self, InPart.LocalTransform);

    auto Archetype = NewObject(InOuter, UStaticMeshComponent);
    // Movable even for a part that never moves: the component is registered first and then receives the entity
    // transform, which a Static component refuses once the world has begun play.
    Archetype.SetMobility(EComponentMobility::Movable);
    Archetype.SetStaticMesh(InPart.Mesh);
    if (ck::IsValid(InPart.Material))
    { Archetype.SetMaterial(0, InPart.Material); }
    Archetype.SetCollisionProfileName(InPart.CollisionProfile);
    if (InPart.CastShadow == false)
    { Archetype.SetCastShadow(false); }

    // On the archetype: the hosted component is instanced from it and shares its override material.
    if (InPart.PrimaryColor.IsSet())
    {
        auto TintedMaterial = Archetype.CreateDynamicMaterialInstance(0);
        if (ck::IsValid(TintedMaterial))
        { TintedMaterial.SetVectorParameterValue(n"PrimaryColor", InPart.PrimaryColor.GetValue()); }
    }

    auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
        Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InPart.DebugName);
    return utils_unreal_component::Add(Node.H(), ComponentParams);
}

// Tints a ProtoGrid mesh part: PrimaryColor, with a darker SecondaryColor and a brighter LineColor. Does nothing for a part
// that was left out, or until its component exists (it is created asynchronously): repaint from the part's OnAdded.
mixin void Paint_MeshPart(const FCk_Handle_UnrealComponent& Self, FLinearColor InColor)
{
    if (ck::Is_NOT_Valid(Self))
    { return; }

    auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(Self));
    if (ck::Is_NOT_Valid(Mesh))
    { return; }

    // Returns the existing dynamic instance on later calls.
    auto Material = Mesh.CreateDynamicMaterialInstance(0);
    if (ck::Is_NOT_Valid(Material))
    { return; }

    Material.SetVectorParameterValue(n"PrimaryColor", InColor);
    Material.SetVectorParameterValue(n"SecondaryColor", FLinearColor(InColor.R * 0.6f, InColor.G * 0.6f, InColor.B * 0.6f, InColor.A));
    Material.SetVectorParameterValue(n"LineColor", FLinearColor(InColor.R * 1.5f, InColor.G * 1.5f, InColor.B * 1.5f, InColor.A));
}
