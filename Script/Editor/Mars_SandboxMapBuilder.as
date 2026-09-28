// Editor-only: generates the gameplay sandbox map into /Game/Mars/Maps/Sandbox_Mars_MAP.
//   1. File > New Level > Empty Level
//   2. Console: Mars.Sandbox.Build
// It populates the open untitled level (floor, lights, player starts, jump ledge, crouch tunnel, two test
// interactables) and saves it to the map path.
//
// Surfaces use CkUsf ProtoGrid color variants: MaterialInstanceConstants under /Game/Mars/Materials/ProtoGrid,
// parented to the generated M_CkUsf_Look_ProtoGrid master (created on first use). To (re)apply them to an existing
// sandbox map, open it and run: Mars.Sandbox.ApplyMaterials
//
// It must NOT create/load a level itself: swapping the editor world from inside a script call GCs the world the
// calling script context holds, and the next nested script call (Ck processor Configure during the new world's
// subsystem init) restores that dangling context -> access violation in FAngelscriptManager::AssignWorldContext.
//
// Game mode: AWorldSettings::DefaultGameMode is BlueprintReadOnly, so the map picks up AMars_Gameplay_GameMode
// through the "Sandbox_Mars_" entry in Config/DefaultEngine.ini [GameMapsSettings] GameModeMapPrefixes.

#if EDITOR
UFUNCTION()
void Mars_BuildSandboxFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::Build();
}

const FConsoleCommand Mars_BuildSandboxCommand("Mars.Sandbox.Build", n"Mars_BuildSandboxFunc");

UFUNCTION()
void Mars_ApplySandboxMaterialsFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::ApplyMaterials();
}

const FConsoleCommand Mars_ApplySandboxMaterialsCommand("Mars.Sandbox.ApplyMaterials", n"Mars_ApplySandboxMaterialsFunc");

namespace utils_mars_sandbox
{
    const FString k_MapPath = "/Game/Mars/Maps/Sandbox_Mars_MAP";
    const FString k_MaterialFolder = "/Game/Mars/Materials/ProtoGrid";
    const FString k_ProtoGridMaster = "/CkFoundation/CkUsf/GeneratedLooks/M_CkUsf_Look_ProtoGrid.M_CkUsf_Look_ProtoGrid";

    void Build()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::EnsureIfNot(ck::IsValid(World), "[Mars.Sandbox.Build] No editor world"))
        { return; }

        if (EditorAsset::DoesAssetExist(k_MapPath))
        {
            ck::Warning(f"[Mars.Sandbox.Build] [{k_MapPath}] already exists. Delete it first to rebuild.");
            return;
        }

        const FString WorldPath = World.GetPathName();
        if (WorldPath.StartsWith("/Temp/") == false)
        {
            ck::Warning(f"[Mars.Sandbox.Build] The open level [{WorldPath}] is a saved map. Open File > New Level > Empty Level first.");
            return;
        }

        auto Cube = engine::load::Cube();

        // Floor: 40m x 40m slab, top face at Z=0.
        Spawn_Block(Cube, "Floor", FVector(0.0, 0.0, -10.0), FVector(40.0, 40.0, 0.2));

        // Jump/fall: a 60uu step (above MaxStepHeight, below jump apex) then a 120uu platform.
        Spawn_Block(Cube, "Ledge_Step", FVector(300.0, -600.0, 30.0), FVector(2.0, 2.0, 0.6));
        Spawn_Block(Cube, "Ledge_Platform", FVector(500.0, -600.0, 60.0), FVector(4.0, 4.0, 1.2));

        // Crouch tunnel: 130uu clearance - too low standing (176), fits crouched (~104).
        Spawn_Block(Cube, "Tunnel_WallLeft", FVector(500.0, 300.0, 65.0), FVector(4.0, 0.2, 1.3));
        Spawn_Block(Cube, "Tunnel_WallRight", FVector(500.0, 600.0, 65.0), FVector(4.0, 0.2, 1.3));
        Spawn_Block(Cube, "Tunnel_Roof", FVector(500.0, 450.0, 140.0), FVector(4.0, 3.2, 0.2));

        auto Actors = UEditorActorSubsystem::Get();

        auto Sun = Actors.SpawnActorFromClass(ADirectionalLight, FVector(0.0, 0.0, 800.0), FRotator(-50.0, 35.0, 0.0));
        Sun.SetActorLabel("Sun");
        Actors.SpawnActorFromClass(ASkyLight, FVector(0.0, 0.0, 900.0)).SetActorLabel("SkyLight");
        Actors.SpawnActorFromClass(ASkyAtmosphere, FVector::ZeroVector).SetActorLabel("SkyAtmosphere");

        for (int32 Index = 0; Index < 4; ++Index)
        {
            auto Start = Actors.SpawnActorFromClass(APlayerStart, FVector(-600.0, -225.0 + 150.0 * Index, 100.0));
            Start.SetActorLabel(f"PlayerStart_{Index}");
        }

        Actors.SpawnActorFromClass(AMars_TestLamp, FVector(0.0, 300.0, 50.0)).SetActorLabel("TestLamp_A");
        Actors.SpawnActorFromClass(AMars_TestLamp, FVector(0.0, -300.0, 50.0)).SetActorLabel("TestLamp_B");

        Apply_ProtoGridMaterials();

        const bool Saved = UEditorLoadingAndSavingUtils::SaveMap(World, k_MapPath);
        ck::Trace(f"[Mars.Sandbox.Build] [{k_MapPath}] built, saved={Saved}");
    }

    void ApplyMaterials()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.ApplyMaterials] Open [{k_MapPath}] first.");
            return;
        }

        Apply_ProtoGridMaterials();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.ApplyMaterials] applied, saved={Saved}");
    }

    // Matches blocks by the labels Build gives them.
    void Apply_ProtoGridMaterials()
    {
        auto Floor = GetOrCreate_ProtoGrid("ProtoGrid_Floor_Mars_MI",
            FLinearColor(0.07, 0.075, 0.085), FLinearColor(0.1, 0.105, 0.12), FLinearColor(0.45, 0.48, 0.55), 100.0);
        auto Wall = GetOrCreate_ProtoGrid("ProtoGrid_Wall_Mars_MI",
            FLinearColor(0.109, 0.16, 0.23), FLinearColor(0.148, 0.216, 0.31), FLinearColor(0.766, 0.922, 1.0), 100.0);
        auto Platform = GetOrCreate_ProtoGrid("ProtoGrid_Platform_Mars_MI",
            FLinearColor(0.42, 0.14, 0.03), FLinearColor(0.52, 0.19, 0.05), FLinearColor(1.0, 0.72, 0.42), 50.0);
        auto Interactable = GetOrCreate_ProtoGrid("ProtoGrid_Interactable_Mars_MI",
            FLinearColor(0.05, 0.22, 0.08), FLinearColor(0.08, 0.3, 0.11), FLinearColor(0.62, 1.0, 0.62), 25.0);

        auto AllActors = UEditorActorSubsystem::Get().GetAllLevelActors();
        for (auto Actor : AllActors)
        {
            const FString Label = Actor.GetActorLabel();

            auto Lamp = Cast<AMars_TestLamp>(Actor);
            if (ck::IsValid(Lamp))
            {
                Lamp.Mesh.SetMaterial(0, Interactable);
                continue;
            }

            auto Block = Cast<AStaticMeshActor>(Actor);
            if (ck::Is_NOT_Valid(Block))
            { continue; }

            if (Label == "Floor")
            { Block.StaticMeshComponent.SetMaterial(0, Floor); }
            else if (Label.StartsWith("Ledge_"))
            { Block.StaticMeshComponent.SetMaterial(0, Platform); }
            else if (Label.StartsWith("Tunnel_"))
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
        }
    }

    UMaterialInstanceConstant GetOrCreate_ProtoGrid(const FString& InName, FLinearColor InPrimary, FLinearColor InSecondary,
                                                     FLinearColor InLine, float32 InCellSize)
    {
        const FString AssetPath = f"{k_MaterialFolder}/{InName}";
        if (EditorAsset::DoesAssetExist(AssetPath))
        { return Cast<UMaterialInstanceConstant>(EditorAsset::LoadAsset(AssetPath)); }

        auto Master = Cast<UMaterialInterface>(EditorAsset::LoadAsset(k_ProtoGridMaster));
        if (ck::EnsureIfNot(ck::IsValid(Master), f"[Mars.Sandbox] ProtoGrid master [{k_ProtoGridMaster}] not found"))
        { return nullptr; }

        auto Factory = Cast<UMaterialInstanceConstantFactoryNew>(NewObject(GetTransientPackage(), UMaterialInstanceConstantFactoryNew));
        auto Instance = Cast<UMaterialInstanceConstant>(
            AssetTools::CreateAsset(InName, k_MaterialFolder, UMaterialInstanceConstant, Factory));
        if (ck::EnsureIfNot(ck::IsValid(Instance), f"[Mars.Sandbox] Failed to create [{AssetPath}]"))
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

    void Spawn_Block(UStaticMesh InMesh, const FString& InLabel, FVector InLocation, FVector InScale)
    {
        auto Actor = Cast<AStaticMeshActor>(UEditorActorSubsystem::Get().SpawnActorFromClass(AStaticMeshActor, InLocation));
        if (ck::Is_NOT_Valid(Actor))
        { return; }

        Actor.StaticMeshComponent.SetStaticMesh(InMesh);
        Actor.SetActorScale3D(InScale);
        Actor.SetActorLabel(InLabel);
    }
}
#endif
