// Placeable brazier: Brazier_A_Mars_SM (a hammered iron bowl on three scrolled legs, heaped coals, pivot at its footprint's
// centre on the floor), lit only by an open flame held to it and burning forever once lit; StartLit lights it from data.
// The mesh bakes four tongues in its EnvFlame slot (CandleFlame_Mars_M): the dressing keeps them dark until the brazier is
// lit, so they read as coals, and the Niagara flame rides on top of them. A big open fire: it lights a wide pool and
// throws embers.
class UMars_Brazier_EntityScript : UMars_FlameFixture_EntityScript
{
    default _ShowInPlaceActors = true;

    // Not in the generated asset registry yet (regenerated on editor start): loaded by path.
    private const FString k_MeshPath = "/Game/Mars/Environment/Dressing/Meshes/Clutter/Brazier_A_Mars_SM.Brazier_A_Mars_SM";
    // SOCKET_Fire sits at the tongues' middle, 101 cm up; the effect and the light start where the tongues root, on the
    // coal heap over the rim, so the tongues rise out of the coals rather than float over them.
    private const FVector k_FlameLocal = FVector(0.0, 0.0, 89.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        if (Name.IsEmpty())
        { Name = FText::FromString("Brazier"); }

        Flame.Fuel.Reset();
        Flame.Enclosure = EMars_Flame_Enclosure::Open;
        Flame.Lighting = EMars_Flame_Lighting::NeedsAFlame;
        Flame.Radius.World = 800.0f;
        return Super::DoConstruct(InHandle);
    }

    // The bowl blocks: it stands on the floor where people walk.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        auto Mesh = System::LoadAsset_Blocking(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(k_MeshPath)));
        if (ck::EnsureIfNot(ck::IsValid(Mesh), f"[Brazier] no mesh at [{k_MeshPath}]"))
        { return; }

        _BakedFlamePart = InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity, Mesh, nullptr,
            collision::profile::BlockAll, n"Brazier_Body"));
    }

    protected FVector Get_FlameLocal() const override
    {
        return k_FlameLocal;
    }

    protected FMars_FlameLook Get_Look() const override
    {
        auto Look = FMars_FlameLook();
        Look.Color = FLinearColor(1.0f, 0.55f, 0.25f, 1.0f);
        Look.IntensityWorld = 9000.0f;
        Look.ShadowsWorld = true;
        // The light rides 22 cm over the coals (the dressing lifts it by half FxSize); a wide source there would still
        // cut the baked tongues.
        Look.SourceRadius = 5.0f;
        Look.FxSize = 45.0f;
        Look.FxEmberRate = 20.0f;
        return Look;
    }
}
