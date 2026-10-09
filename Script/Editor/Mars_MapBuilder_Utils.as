// Editor-only helpers shared by the map builders (Mars.Sandbox.*, Mars.Camp.*): the command guards, ProtoGrid blocks
// and the four ProtoGrid MaterialInstanceConstants under /Game/Mars/Materials/ProtoGrid (created on first use from the
// CkUsf master).
#if EDITOR
// One static-mesh block: its label, centre, scale, rotation and surface.
struct FMars_MapBuilder_Block
{
    FString Label;
    FVector Location;
    FVector Scale = FVector::OneVector;
    FRotator Rotation;
    // The component's PhysMaterialOverride, which the Jolt bake reads per component (a material instance's phys mat never
    // reaches it). Null means Stone.
    TSoftObjectPtr<UPhysicalMaterial> PhysMat;

    FMars_MapBuilder_Block() {}

    FMars_MapBuilder_Block(const FString& InLabel, FVector InLocation, FVector InScale, FRotator InRotation = FRotator::ZeroRotator)
    {
        Label = InLabel;
        Location = InLocation;
        Scale = InScale;
        Rotation = InRotation;
    }
}

// One entity-script actor a builder places: its label, location and rotation.
struct FMars_MapBuilder_Placement
{
    FString Label;
    FVector Location;
    FRotator Rotation;

    FMars_MapBuilder_Placement() {}

    FMars_MapBuilder_Placement(const FString& InLabel, FVector InLocation, FRotator InRotation = FRotator::ZeroRotator)
    {
        Label = InLabel;
        Location = InLocation;
        Rotation = InRotation;
    }
}

// A ProtoGrid look: the material instance's three colours and its cell size.
struct FMars_MapBuilder_ProtoGridLook
{
    FLinearColor Primary;
    FLinearColor Secondary;
    FLinearColor Line;
    float32 CellSize = 100.0f;

    FMars_MapBuilder_ProtoGridLook() {}

    FMars_MapBuilder_ProtoGridLook(FLinearColor InPrimary, FLinearColor InSecondary, FLinearColor InLine, float32 InCellSize)
    {
        Primary = InPrimary;
        Secondary = InSecondary;
        Line = InLine;
        CellSize = InCellSize;
    }
}

namespace utils_mars_map_builder
{
    const FString k_MaterialFolder = "/Game/Mars/Materials/ProtoGrid";
    const FString k_ProtoGridMaster = "/CkFoundation/CkUsf/GeneratedLooks/M_CkUsf_Look_ProtoGrid.M_CkUsf_Look_ProtoGrid";
    const FString k_PhysMatFolder = "/Game/Mars/Physics";

    // The surface phys mat /Game/Mars/Physics/<InSurface>_Mars_PhysMat (Stone, Wood, Carpet, ...).
    TSoftObjectPtr<UPhysicalMaterial> Get_PhysMat(const FString& InSurface)
    {
        const FString Name = f"{InSurface}_Mars_PhysMat";
        return TSoftObjectPtr<UPhysicalMaterial>(FSoftObjectPath(f"{k_PhysMatFolder}/{Name}.{Name}"));
    }

    // The open editor world when it is the saved map at InMapPath; warns and returns null otherwise.
    UWorld TryGet_OpenMap(const FString& InCommand, const FString& InMapPath)
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::IsValid(World) && Get_IsMap(World, InMapPath))
        { return World; }

        ck::Warning(f"[{InCommand}] Open [{InMapPath}] first.");
        return nullptr;
    }

    // A world's path is "<package>.<asset>", so matching up to the dot rejects a copy such as <map>_Backup.
    bool Get_IsMap(UWorld InWorld, const FString& InMapPath)
    {
        return InWorld.GetPathName().StartsWith(f"{InMapPath}.");
    }

    // The first level actor labelled InLabel, or null.
    AActor TryGet_LevelActor(const FString& InLabel)
    {
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == InLabel)
            { return Actor; }
        }

        return nullptr;
    }

    // The first level actor whose label starts with InPrefix, or null.
    AActor TryGet_LevelActorWithPrefix(const FString& InPrefix)
    {
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel().StartsWith(InPrefix))
            { return Actor; }
        }

        return nullptr;
    }

    // False, with a warning naming InBlocker and InHint (what to delete to redo the command), when an earlier run's actor
    // is in the way.
    bool Get_IsUnblocked(const FString& InCommand, AActor InBlocker, const FString& InHint)
    {
        if (ck::Is_NOT_Valid(InBlocker))
        { return true; }

        ck::Warning(f"[{InCommand}] [{InBlocker.GetActorLabel()}] already exists. {InHint}");
        return false;
    }

    void SaveOpenLevel(const FString& InCommand)
    {
        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[{InCommand}] done, saved={Saved}");
    }

    AStaticMeshActor Spawn_Block(UStaticMesh InMesh, const FMars_MapBuilder_Block& InBlock)
    {
        auto Actor = Cast<AStaticMeshActor>(
            UEditorActorSubsystem::Get().SpawnActorFromClass(AStaticMeshActor, InBlock.Location, InBlock.Rotation));
        if (ck::EnsureIfNot(ck::IsValid(Actor), f"[Mars.MapBuilder] Failed to spawn the block [{InBlock.Label}]"))
        { return nullptr; }

        Actor.StaticMeshComponent.SetStaticMesh(InMesh);
        Actor.SetActorScale3D(InBlock.Scale);
        Actor.SetActorLabel(InBlock.Label);

        const auto PhysMatSoft = InBlock.PhysMat.IsNull() ? Get_PhysMat("Stone") : InBlock.PhysMat;
        auto PhysMat = System::LoadAsset_Blocking(PhysMatSoft);
        if (ck::EnsureIfNot(ck::IsValid(PhysMat),
            f"[Mars.MapBuilder] Phys mat [{PhysMatSoft.ToSoftObjectPath().ToString()}] for the block [{InBlock.Label}] not found"))
        { return Actor; }

        Actor.StaticMeshComponent.SetPhysMaterialOverride(PhysMat);
        return Actor;
    }

    UMaterialInstanceConstant Get_ProtoGrid_Floor()
    {
        return GetOrCreate_ProtoGrid("ProtoGrid_Floor_Mars_MI", FMars_MapBuilder_ProtoGridLook(
            FLinearColor(0.07, 0.075, 0.085), FLinearColor(0.1, 0.105, 0.12), FLinearColor(0.45, 0.48, 0.55), 100.0));
    }

    UMaterialInstanceConstant Get_ProtoGrid_Wall()
    {
        return GetOrCreate_ProtoGrid("ProtoGrid_Wall_Mars_MI", FMars_MapBuilder_ProtoGridLook(
            FLinearColor(0.109, 0.16, 0.23), FLinearColor(0.148, 0.216, 0.31), FLinearColor(0.766, 0.922, 1.0), 100.0));
    }

    UMaterialInstanceConstant Get_ProtoGrid_Platform()
    {
        return GetOrCreate_ProtoGrid("ProtoGrid_Platform_Mars_MI", FMars_MapBuilder_ProtoGridLook(
            FLinearColor(0.42, 0.14, 0.03), FLinearColor(0.52, 0.19, 0.05), FLinearColor(1.0, 0.72, 0.42), 50.0));
    }

    UMaterialInstanceConstant Get_ProtoGrid_Interactable()
    {
        return GetOrCreate_ProtoGrid("ProtoGrid_Interactable_Mars_MI", FMars_MapBuilder_ProtoGridLook(
            FLinearColor(0.05, 0.22, 0.08), FLinearColor(0.08, 0.3, 0.11), FLinearColor(0.62, 1.0, 0.62), 25.0));
    }

    UMaterialInstanceConstant GetOrCreate_ProtoGrid(const FString& InName, const FMars_MapBuilder_ProtoGridLook& InLook)
    {
        const FString AssetPath = f"{k_MaterialFolder}/{InName}";
        if (EditorAsset::DoesAssetExist(AssetPath))
        {
            auto Existing = Cast<UMaterialInstanceConstant>(EditorAsset::LoadAsset(AssetPath));
            if (ck::EnsureIfNot(ck::IsValid(Existing), f"[Mars.MapBuilder] [{AssetPath}] exists but is not a MaterialInstanceConstant"))
            { return nullptr; }

            return Existing;
        }

        auto Master = Cast<UMaterialInterface>(EditorAsset::LoadAsset(k_ProtoGridMaster));
        if (ck::EnsureIfNot(ck::IsValid(Master), f"[Mars.MapBuilder] ProtoGrid master [{k_ProtoGridMaster}] not found"))
        { return nullptr; }

        auto Factory = Cast<UMaterialInstanceConstantFactoryNew>(NewObject(GetTransientPackage(), UMaterialInstanceConstantFactoryNew));
        auto Instance = Cast<UMaterialInstanceConstant>(
            AssetTools::CreateAsset(InName, k_MaterialFolder, UMaterialInstanceConstant, Factory));
        if (ck::EnsureIfNot(ck::IsValid(Instance), f"[Mars.MapBuilder] Failed to create [{AssetPath}]"))
        { return nullptr; }

        MaterialEditing::SetMaterialInstanceParent(Instance, Master);
        MaterialEditing::SetMaterialInstanceVectorParameterValue(Instance, n"PrimaryColor", InLook.Primary);
        MaterialEditing::SetMaterialInstanceVectorParameterValue(Instance, n"SecondaryColor", InLook.Secondary);
        MaterialEditing::SetMaterialInstanceVectorParameterValue(Instance, n"LineColor", InLook.Line);
        MaterialEditing::SetMaterialInstanceScalarParameterValue(Instance, n"CellSize", InLook.CellSize);
        MaterialEditing::UpdateMaterialInstance(Instance);

        const bool OnlyIfIsDirty = false;
        EditorAsset::SaveLoadedAsset(Instance, OnlyIfIsDirty);

        return Instance;
    }
}
#endif
