// Placeable torch sconce: TorchSconce_A_Mars_SM (an iron wall plate, a twisted arm, a collar and a pitch torch leaning off
// the wall), the wall torch's rules and numbers on the real mesh. The origin is the mounting surface and the torch reaches
// along local +X (out of the wall), like UMars_WallTorch_EntityScript, so it drops into the same placements: the mesh is
// authored protruding along +Y and turned here. Lit only by an open flame held to it; burns forever once lit. The mesh
// bakes a flame in its EnvFlame slot, kept dark until lit, with the Niagara flame on top.
class UMars_TorchSconce_EntityScript : UMars_FlameFixture_EntityScript
{
    default _ShowInPlaceActors = true;

    // Not in the generated asset registry yet (regenerated on editor start): loaded by path.
    private const FString k_MeshPath = "/Game/Mars/Environment/Dressing/Meshes/Clutter/TorchSconce_A_Mars_SM.TorchSconce_A_Mars_SM";
    // Turns the mesh's +Y (off the wall) onto the fixture's +X.
    private const FRotator k_MeshRotation = FRotator(0.0, -90.0, 0.0);
    // SOCKET_Flame in the mesh's frame: (0, 20.2, 31.7), the pitch head's top.
    private const FVector k_SocketFlame = FVector(0.0, 20.209, 31.699);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        if (Name.IsEmpty())
        { Name = FText::FromString("Torch"); }

        Flame.Fuel.Reset();
        Flame.Enclosure = EMars_Flame_Enclosure::Open;
        Flame.Lighting = EMars_Flame_Lighting::NeedsAFlame;
        Flame.Radius.World = 800.0f;
        return Super::DoConstruct(InHandle);
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        auto Mesh = System::LoadAsset_Blocking(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(k_MeshPath)));
        if (ck::EnsureIfNot(ck::IsValid(Mesh), f"[TorchSconce] no mesh at [{k_MeshPath}]"))
        { return; }

        auto Part = FMars_MeshPart(FTransform(k_MeshRotation, FVector::ZeroVector), Mesh, nullptr,
            collision::profile::NoCollision, n"TorchSconce_Body");
        Part.CastShadow = false;
        _BakedFlamePart = InRoot.Add_MeshPart(this, Part);
    }

    protected FVector Get_FlameLocal() const override
    {
        return k_MeshRotation.RotateVector(k_SocketFlame);
    }

    protected FMars_FlameLook Get_Look() const override
    {
        auto Look = FMars_FlameLook();
        Look.Color = FLinearColor(1.0f, 0.55f, 0.25f, 1.0f);
        Look.IntensityWorld = 7000.0f;
        Look.ShadowsWorld = true;
        Look.FxSize = 18.0f;
        Look.FxEmberRate = 6.0f;
        return Look;
    }
}
