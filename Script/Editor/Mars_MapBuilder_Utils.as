// Editor-only helpers shared by the map builders (Mars.Sandbox.*, Mars.Camp.*): ProtoGrid blocks and the four
// ProtoGrid MaterialInstanceConstants under /Game/Mars/Materials/ProtoGrid (created on first use from the CkUsf master).
#if EDITOR
namespace utils_mars_map_builder
{
    const FString k_MaterialFolder = "/Game/Mars/Materials/ProtoGrid";
    const FString k_ProtoGridMaster = "/CkFoundation/CkUsf/GeneratedLooks/M_CkUsf_Look_ProtoGrid.M_CkUsf_Look_ProtoGrid";

    // A scaled static-mesh block with the given label. Returns the actor so the caller can set its material at once.
    AStaticMeshActor Spawn_Block(UStaticMesh InMesh, const FString& InLabel, FVector InLocation, FVector InScale,
                                 FRotator InRotation = FRotator::ZeroRotator)
    {
        auto Actor = Cast<AStaticMeshActor>(UEditorActorSubsystem::Get().SpawnActorFromClass(AStaticMeshActor, InLocation, InRotation));
        if (ck::Is_NOT_Valid(Actor))
        { return nullptr; }

        Actor.StaticMeshComponent.SetStaticMesh(InMesh);
        Actor.SetActorScale3D(InScale);
        Actor.SetActorLabel(InLabel);
        return Actor;
    }

    UMaterialInstanceConstant Get_ProtoGrid_Floor()
    {
        return GetOrCreate_ProtoGrid("ProtoGrid_Floor_Mars_MI",
            FLinearColor(0.07, 0.075, 0.085), FLinearColor(0.1, 0.105, 0.12), FLinearColor(0.45, 0.48, 0.55), 100.0);
    }

    UMaterialInstanceConstant Get_ProtoGrid_Wall()
    {
        return GetOrCreate_ProtoGrid("ProtoGrid_Wall_Mars_MI",
            FLinearColor(0.109, 0.16, 0.23), FLinearColor(0.148, 0.216, 0.31), FLinearColor(0.766, 0.922, 1.0), 100.0);
    }

    UMaterialInstanceConstant Get_ProtoGrid_Platform()
    {
        return GetOrCreate_ProtoGrid("ProtoGrid_Platform_Mars_MI",
            FLinearColor(0.42, 0.14, 0.03), FLinearColor(0.52, 0.19, 0.05), FLinearColor(1.0, 0.72, 0.42), 50.0);
    }

    UMaterialInstanceConstant Get_ProtoGrid_Interactable()
    {
        return GetOrCreate_ProtoGrid("ProtoGrid_Interactable_Mars_MI",
            FLinearColor(0.05, 0.22, 0.08), FLinearColor(0.08, 0.3, 0.11), FLinearColor(0.62, 1.0, 0.62), 25.0);
    }

    UMaterialInstanceConstant GetOrCreate_ProtoGrid(const FString& InName, FLinearColor InPrimary, FLinearColor InSecondary,
                                                     FLinearColor InLine, float32 InCellSize)
    {
        const FString AssetPath = f"{k_MaterialFolder}/{InName}";
        if (EditorAsset::DoesAssetExist(AssetPath))
        { return Cast<UMaterialInstanceConstant>(EditorAsset::LoadAsset(AssetPath)); }

        auto Master = Cast<UMaterialInterface>(EditorAsset::LoadAsset(k_ProtoGridMaster));
        if (ck::EnsureIfNot(ck::IsValid(Master), f"[Mars.MapBuilder] ProtoGrid master [{k_ProtoGridMaster}] not found"))
        { return nullptr; }

        auto Factory = Cast<UMaterialInstanceConstantFactoryNew>(NewObject(GetTransientPackage(), UMaterialInstanceConstantFactoryNew));
        auto Instance = Cast<UMaterialInstanceConstant>(
            AssetTools::CreateAsset(InName, k_MaterialFolder, UMaterialInstanceConstant, Factory));
        if (ck::EnsureIfNot(ck::IsValid(Instance), f"[Mars.MapBuilder] Failed to create [{AssetPath}]"))
        { return nullptr; }

        MaterialEditing::SetMaterialInstanceParent(Instance, Master);
        MaterialEditing::SetMaterialInstanceVectorParameterValue(Instance, n"PrimaryColor", InPrimary);
        MaterialEditing::SetMaterialInstanceVectorParameterValue(Instance, n"SecondaryColor", InSecondary);
        MaterialEditing::SetMaterialInstanceVectorParameterValue(Instance, n"LineColor", InLine);
        MaterialEditing::SetMaterialInstanceScalarParameterValue(Instance, n"CellSize", InCellSize);
        MaterialEditing::UpdateMaterialInstance(Instance);
        EditorAsset::SaveLoadedAsset(Instance, false);

        return Instance;
    }
}
#endif
