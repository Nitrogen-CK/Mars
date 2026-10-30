// Still water: a basin's water line or a flooded cistern (DRIPS_PLAN §3.11, §8). Place it at the water line, size it
// to the pool; attach it to StoneBasin_A's SOCKET_Water for a basin.
//   Surface - the StillWater_Mars_SM plane (100 x 100 cm scaled to Size), no collision. Its serialized custom primitive
//             data carries SizeX, SizeY, Seed, Murk, RainRate for the materials (StillWaterBasin_Mars_MI, opaque, or
//             StillWaterCistern_Mars_MI, Single Layer Water, when Deep).
//   Probe   - a thin query-only WorldStatic box at the water line with Water_Mars_PhysMat. Object-type queries (the drip
//             down-traces, PCG raycasts) hit it and read the phys mat, so drips over it land as rings on the water;
//             it ignores every channel but WorldStatic (PCG raycasts need a Block response on the channel they query),
//             so the camera, interaction traces and pawns pass through.
// Add a Box Reflection Capture fitted to the room: with no SSR or Lumen, captures are the only reflections.
class AMars_StillWater : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;
    default SceneRoot.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UStaticMeshComponent Surface;
    default Surface.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UBoxComponent Probe;
    default Probe.Mobility = EComponentMobility::Static;

    // Pool size (cm).
    UPROPERTY(Category = "Water")
    FVector2D Size = FVector2D(200.0, 200.0);

    UPROPERTY(Category = "Water")
    int32 Seed = 1;

    // Scales the edge-to-deep colour distance: 0.3 = clear and shallow-looking, 2 = black at once.
    UPROPERTY(Category = "Water", meta = (ClampMin = "0.05", ClampMax = "4.0"))
    float32 Murk = 1.0f;

    // Ambient rain rings per m^2 per second (the material's RainRipples switch must be on).
    UPROPERTY(Category = "Water", meta = (ClampMin = "0.0"))
    float32 RainRate = 0.0f;

    // Single Layer Water (moss-dark absorption, an extra composite pass) instead of the opaque basin master.
    UPROPERTY(Category = "Water")
    bool Deep = false;

    // Unset: StillWaterCistern_Mars_MI when Deep, else StillWaterBasin_Mars_MI.
    UPROPERTY(Category = "Water")
    UMaterialInterface WaterMaterial;

    UPROPERTY(Category = "Water|Physics")
    bool UseStaticMobility = true;

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Water")
    void Rebuild()
    {
        auto Mesh = utils_drip::Load_Mesh("StillWater_Mars_SM");
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        const auto Mobility = UseStaticMobility ? EComponentMobility::Static : EComponentMobility::Movable;
        SceneRoot.SetMobility(Mobility);
        Surface.SetMobility(Mobility);
        Probe.SetMobility(Mobility);

        Surface.SetStaticMesh(Mesh);
        auto Material = WaterMaterial;
        if (ck::Is_NOT_Valid(Material))
        { Material = utils_drip::Load_Material(Deep ? "StillWaterCistern_Mars_MI" : "StillWaterBasin_Mars_MI"); }
        Surface.SetMaterial(0, Material);
        Surface.SetRelativeTransform(FTransform(FRotator::ZeroRotator, FVector::ZeroVector,
            FVector(Math::Max(Size.X, 1.0) / 100.0, Math::Max(Size.Y, 1.0) / 100.0, 1.0)));
        utils_drip::Apply_NoCollision(Surface);

        // Serialized defaults (the run-time setter does not save).
        _WrittenData.Empty();
        Write_SurfaceData(EMars_StillWaterData::SizeX, float32(Size.X));
        Write_SurfaceData(EMars_StillWaterData::SizeY, float32(Size.Y));
        Write_SurfaceData(EMars_StillWaterData::Seed, float32(utils_drip::Roll(Seed, 0, 12)));
        Write_SurfaceData(EMars_StillWaterData::Murk, Murk);
        Write_SurfaceData(EMars_StillWaterData::RainRate, RainRate);

        Probe.SetRelativeLocation(FVector(0.0, 0.0, -1.0));
        Probe.SetBoxExtent(FVector(Math::Max(Size.X, 1.0) * 0.5, Math::Max(Size.Y, 1.0) * 0.5, 1.0), false);
        Probe.SetCollisionEnabled(ECollisionEnabled::QueryOnly);
        Probe.SetCollisionObjectType(ECollisionChannel::ECC_WorldStatic);
        Probe.SetCollisionResponseToAllChannels(ECollisionResponse::ECR_Ignore);
        // PCG raycasts only accept hits whose response to the queried channel (WorldStatic) is Block; nothing traces or
        // sweeps on WorldStatic, so pawns, the camera and interaction traces still pass through.
        Probe.SetCollisionResponseToChannel(ECollisionChannel::ECC_WorldStatic, ECollisionResponse::ECR_Block);
        Probe.SetPhysMaterialOverride(utils_drip::Load_WaterPhysMat());
        Probe.SetGenerateOverlapEvents(false);
        Probe.ComponentTags.AddUnique(utils_drip::k_JoltNoBakeTag);
        Probe.ComponentTags.AddUnique(utils_drip::k_WaterTag);
        Tags.AddUnique(utils_drip::k_JoltNoBakeTag);
        Tags.AddUnique(utils_drip::k_WaterTag);
    }

    // The custom primitive data defaults last written (test read-back: script cannot read CustomPrimitiveData).
    float Get_SurfaceData(EMars_StillWaterData InSlot) const
    {
        const int32 Index = int32(InSlot);
        return _WrittenData.IsValidIndex(Index) ? _WrittenData[Index] : -99999.0;
    }

    private TArray<float> _WrittenData;

    private void Write_SurfaceData(EMars_StillWaterData InSlot, float32 InValue)
    {
        Surface.SetDefaultCustomPrimitiveDataFloat(int32(InSlot), InValue);
        const int32 Index = int32(InSlot);
        while (_WrittenData.Num() <= Index)
        { _WrittenData.Add(0.0); }
        _WrittenData[Index] = float(InValue);
    }
}
