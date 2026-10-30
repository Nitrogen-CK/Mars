// Assets and shared helpers of the drip dressing. The assets are built by Tools/Blender/mars_water/unreal/mars_water_ue.py
// under /Game/Mars/Environment/Dressing/Water; they are loaded by path (not through the generated MarsAssets accessors)
// so a script build never depends on the asset registry generator having run since they were made.
namespace utils_drip
{
    const FString k_MeshFolder = "/Game/Mars/Environment/Dressing/Water/Meshes";
    const FString k_MaterialFolder = "/Game/Mars/Environment/Dressing/Water/Materials";
    const FName k_JoltNoBakeTag = n"Ck.Jolt.NoBake";
    const FName k_WaterTag = n"Mars.Water";
    const FString k_WaterPhysMatName = "Water_Mars_PhysMat";
    const FString k_WaterPhysMatPath = "/Game/Mars/Physics/Water_Mars_PhysMat.Water_Mars_PhysMat";

    UStaticMesh Load_Mesh(const FString& InName)
    {
        return System::LoadAsset_Blocking(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(f"{k_MeshFolder}/{InName}.{InName}")));
    }

    UMaterialInterface Load_Material(const FString& InName)
    {
        return System::LoadAsset_Blocking(TSoftObjectPtr<UMaterialInterface>(FSoftObjectPath(f"{k_MaterialFolder}/{InName}.{InName}")));
    }

    UPhysicalMaterial Load_WaterPhysMat()
    {
        return System::LoadAsset_Blocking(TSoftObjectPtr<UPhysicalMaterial>(FSoftObjectPath(k_WaterPhysMatPath)));
    }

    // A repeatable [0, 1) per (seed, place, purpose), the HangingRack hash.
    float Roll(int32 InSeed, int32 InPlace, int32 InPurpose)
    {
        const float X = Math::Sin(float(InSeed) * 12.9898 + float(InPlace) * 78.233 + float(InPurpose) * 37.719) * 43758.5453;
        return X - Math::FloorToFloat(X);
    }

    // Dressing never collides and never feeds the CkJolt static-world bake.
    void Apply_NoCollision(UPrimitiveComponent InPrimitive)
    {
        InPrimitive.SetCollisionProfileName(collision::profile::NoCollision);
        InPrimitive.ComponentTags.AddUnique(k_JoltNoBakeTag);
        InPrimitive.SetCastShadow(false);
    }

    // The first static-world hit along the segment (object type WorldStatic, as the PCG raycasts query), self ignored.
    // Volumes are brushes on WorldStatic (a PCG volume over the room, triggers, blocking volumes): they are skipped, as
    // PCG's raycasts skip them, so a leak inside a drip volume still lands on the floor. Check bBlockingHit.
    FHitResult Trace_WorldStatic(AActor InSelf, FVector InStart, FVector InEnd)
    {
        TArray<EObjectTypeQuery> Types;
        Types.Add(EObjectTypeQuery::WorldStatic);
        TArray<AActor> Ignore;
        Ignore.Add(InSelf);
        for (int32 Attempt = 0; Attempt < 4; ++Attempt)
        {
            FHitResult Hit;
            if (System::LineTraceSingleForObjects(InStart, InEnd, Types, true, Ignore, EDrawDebugTrace::None, Hit, true) == false)
            { return Hit; }

            UPrimitiveComponent Component = Hit.Component;
            if (ck::Is_NOT_Valid(Cast<UBrushComponent>(Component)))
            { return Hit; }

            Ignore.Add(Component.Owner);
        }
        return FHitResult();
    }

    // Water_Mars_PhysMat on the hit, or a hit actor tagged Mars.Water (in editor-world queries a phys-mat override
    // reads back null, so the tag is what classifies construction-script traces in the editor).
    bool Is_WaterHit(const FHitResult& InHit)
    {
        UPhysicalMaterial PhysicalMaterial = InHit.PhysMaterial;
        if (ck::IsValid(PhysicalMaterial) && PhysicalMaterial.GetName() == k_WaterPhysMatName)
        { return true; }

        UPrimitiveComponent Component = InHit.Component;
        return ck::IsValid(Component) && ck::IsValid(Component.Owner) && Component.Owner.ActorHasTag(k_WaterTag);
    }

    // A rotation whose Z is InNormal and whose X is the yaw direction projected onto the plane.
    FRotator Make_SurfaceRotation(FVector InNormal, float InYawDegrees)
    {
        const FVector Yaw = FRotator(0.0, InYawDegrees, 0.0).Vector();
        FVector X = Yaw - InNormal * Yaw.DotProduct(InNormal);
        if (X.Size() < 1e-3)
        { X = FVector(1.0, 0.0, 0.0) - InNormal * InNormal.X; }

        return FRotator::MakeFromXZ(X.GetSafeNormal(), InNormal);
    }

    // The decal box is the component's default DecalSize (half extents 128, 256, 256) times its scale: X projects
    // into the wall (16 cm either side), local Y runs up the wall (decal V = 0 at the top, the source), local Z across.
    // Returns the streak length (cm), 0 and hidden when no wall is within 60 cm.
    float Place_Streak(AActor InSelf, UDecalComponent InDecal, const FMars_DripStreakPlacement& InPlacement)
    {
        const auto Wall = Trace_WorldStatic(InSelf, InPlacement.Origin, InPlacement.Origin - InPlacement.Out * 60.0);
        if (!Wall.bBlockingHit)
        {
            InDecal.SetVisibility(false);
            return 0.0;
        }

        const FVector N = Wall.ImpactNormal;
        const FVector Top = Wall.ImpactPoint;
        const float MaxLength = Math::Max(float(InPlacement.Spec.MaxLengthCm), 10.0);
        const auto Floor = Trace_WorldStatic(InSelf, Top + N * 4.0, Top + N * 4.0 - FVector(0.0, 0.0, MaxLength));
        const float Length = Floor.bBlockingHit ? Math::Max(float(Floor.Distance), 10.0) : MaxLength;

        FVector Up = FVector::UpVector - N * N.Z;
        if (Up.Size() < 1e-3)
        { Up = FVector::ForwardVector; }

        InDecal.SetWorldLocationAndRotation(Top - Up.GetSafeNormal() * (0.5 * Length), FRotator::MakeFromXY(-N, Up.GetSafeNormal()));
        InDecal.SetWorldScale3D(FVector(16.0 / 128.0, 0.5 * Length / 256.0, 0.5 * float(InPlacement.Spec.WidthCm) / 256.0));
        InDecal.SetDecalColor(FLinearColor(InPlacement.Seed, InPlacement.Spec.Dampness, InPlacement.Spec.Flow / 100.0f,
            InPlacement.Spec.Mineral));
        InDecal.SetVisibility(true);
        return Length;
    }
}
