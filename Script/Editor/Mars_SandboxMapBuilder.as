// Editor-only: generates the gameplay sandbox map into /Game/Mars/Maps/Sandbox_Mars_MAP.
//   1. File > New Level > Empty Level
//   2. Console: Mars.Sandbox.Build
// It populates the open untitled level (floor, lights, player starts, jump ledge, crouch tunnel, two test
// interactables, mechanisms rooms 2 and 3) and saves it to the map path.
//
// Room 2 (mechanisms) sits east of the main floor, entered through a gap in its west wall. Three gated bays:
// LeverA -> GateA, LeverB1 + LeverB2 -> GateB (all sources), SwitchC (4s hold) -> GateC. Each mechanism is an
// ACk_EntitySpawner_UE with its entity script instanced on it. To add room 2 to an already-built sandbox map,
// open it and run: Mars.Sandbox.BuildRoom2
//
// Room 3 (phase-2 mechanisms) sits north of room 2, entered through a doorway at X=3000 in their shared wall. West
// half: PlateF or the backpack plate (pressed only by a dropped backpack) -> GateF, SealH then SealG -> SequenceI -> GateI
// (latched). East half, three dead-end corridors: a vent suppressed while WheelJ is held on (8s), two spike tiles
// suppressed while LeverK is pulled, an unwired pendulum. To add room 3 to an already-built sandbox map, open it and run:
// Mars.Sandbox.BuildRoom3
// To place just the backpack plate in a map whose room 3 was built before it existed, run: Mars.Sandbox.PlaceBackpackPlate
//
// Room 4 (beat the lamps) sits south of room 2, entered from the main floor through a doorway in its west wall. Pulling
// either chain lights the lamp bank over GateM; the gate stays open while any lamp is lit, and the lamps go dark one at a
// time. A second chain past the gate lets the player back out. To add room 4 to an already-built sandbox map, open it
// and run: Mars.Sandbox.BuildRoom4
//
// Room 5 (the crawler room) sits west of the main floor, entered through a 300uu doorway centred on Y=0 in its east wall.
// It holds a pillar, a 40uu step, the target dummy, the two melee items (cleaver, tenderizer) just inside the doorway and
// two crawlers (4 and 6 legs) at the west end, and a ground-nav field over the whole room (the crawlers' paths). To add
// room 5 to an already-built sandbox map, open it and run: Mars.Sandbox.BuildRoom5
// To place just the two crawlers in a map whose room 5 was built before they existed, run: Mars.Sandbox.PlaceCrawlers
// To place just the nav field in a map whose room 5 was built before it existed, run: Mars.Sandbox.PlaceNavField
//
// Sandbox items (2x Rock, Ration, Cog - World-mode WorldItem presets) sit in front of the player starts. To place them in
// an already-built sandbox map, open it and run: Mars.Sandbox.PlaceItems
// The sandbox backpack (a World-mode Backpack preset with three cargo slots) sits beside them. To place it in an
// already-built sandbox map, open it and run: Mars.Sandbox.PlaceBackpack
// The eyes dummy faces the player starts. To place it in an already-built sandbox map, run: Mars.Sandbox.PlaceEyesDummy
// The sandbox ladder (a 400x400x300 platform block on the main floor with a ladder on its south face) sits north-west of
// the player starts. To place it in an already-built sandbox map, open it and run: Mars.Sandbox.PlaceLadder
// The sandbox workbench (a plain station: a table the player operates, standing in front of it) sits south-west of the
// player starts. To place it in an already-built sandbox map, open it and run: Mars.Sandbox.PlaceWorkbench
// The sandbox dicing station (a table with a cutting board, an herb pile and a cleaver the operator chops with) sits 400uu
// toward -Y of the workbench. To place it in an already-built sandbox map, open it and run: Mars.Sandbox.PlaceDicingStation
//
// The gauntlets (five cells combining several mechanisms each, off a hall along the main floor's north edge) are built by
// Script/Editor/Mars_SandboxGauntletBuilder.as. To add them to an already-built sandbox map, open it and run:
// Mars.Sandbox.BuildGauntlets
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

UFUNCTION()
void Mars_BuildSandboxRoom2Func(const TArray<FString>& Args)
{
    utils_mars_sandbox::BuildRoom2();
}

const FConsoleCommand Mars_BuildSandboxRoom2Command("Mars.Sandbox.BuildRoom2", n"Mars_BuildSandboxRoom2Func");

UFUNCTION()
void Mars_BuildSandboxRoom3Func(const TArray<FString>& Args)
{
    utils_mars_sandbox::BuildRoom3();
}

const FConsoleCommand Mars_BuildSandboxRoom3Command("Mars.Sandbox.BuildRoom3", n"Mars_BuildSandboxRoom3Func");

UFUNCTION()
void Mars_BuildSandboxRoom4Func(const TArray<FString>& Args)
{
    utils_mars_sandbox::BuildRoom4();
}

const FConsoleCommand Mars_BuildSandboxRoom4Command("Mars.Sandbox.BuildRoom4", n"Mars_BuildSandboxRoom4Func");

UFUNCTION()
void Mars_BuildSandboxRoom5Func(const TArray<FString>& Args)
{
    utils_mars_sandbox::BuildRoom5();
}

const FConsoleCommand Mars_BuildSandboxRoom5Command("Mars.Sandbox.BuildRoom5", n"Mars_BuildSandboxRoom5Func");

UFUNCTION()
void Mars_PlaceSandboxCrawlersFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceCrawlers();
}

const FConsoleCommand Mars_PlaceSandboxCrawlersCommand("Mars.Sandbox.PlaceCrawlers", n"Mars_PlaceSandboxCrawlersFunc");

UFUNCTION()
void Mars_PlaceSandboxNavFieldFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceNavField();
}

const FConsoleCommand Mars_PlaceSandboxNavFieldCommand("Mars.Sandbox.PlaceNavField", n"Mars_PlaceSandboxNavFieldFunc");

UFUNCTION()
void Mars_PlaceSandboxItemsFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceItems();
}

const FConsoleCommand Mars_PlaceSandboxItemsCommand("Mars.Sandbox.PlaceItems", n"Mars_PlaceSandboxItemsFunc");

UFUNCTION()
void Mars_PlaceSandboxBackpackFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceBackpack();
}

const FConsoleCommand Mars_PlaceSandboxBackpackCommand("Mars.Sandbox.PlaceBackpack", n"Mars_PlaceSandboxBackpackFunc");

UFUNCTION()
void Mars_PlaceSandboxBackpackPlateFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceBackpackPlate();
}

const FConsoleCommand Mars_PlaceSandboxBackpackPlateCommand("Mars.Sandbox.PlaceBackpackPlate", n"Mars_PlaceSandboxBackpackPlateFunc");

UFUNCTION()
void Mars_PlaceSandboxEyesDummyFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceEyesDummy();
}

const FConsoleCommand Mars_PlaceSandboxEyesDummyCommand("Mars.Sandbox.PlaceEyesDummy", n"Mars_PlaceSandboxEyesDummyFunc");

UFUNCTION()
void Mars_PlaceSandboxLadderFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceLadder();
}

const FConsoleCommand Mars_PlaceSandboxLadderCommand("Mars.Sandbox.PlaceLadder", n"Mars_PlaceSandboxLadderFunc");

UFUNCTION()
void Mars_PlaceSandboxWorkbenchFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceWorkbench();
}

const FConsoleCommand Mars_PlaceSandboxWorkbenchCommand("Mars.Sandbox.PlaceWorkbench", n"Mars_PlaceSandboxWorkbenchFunc");

UFUNCTION()
void Mars_PlaceSandboxDicingStationFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceDicingStation();
}

const FConsoleCommand Mars_PlaceSandboxDicingStationCommand("Mars.Sandbox.PlaceDicingStation", n"Mars_PlaceSandboxDicingStationFunc");

namespace utils_mars_sandbox
{
    const FString k_MapPath = "/Game/Mars/Maps/Sandbox_Mars_MAP";
    const FString k_Room2FloorLabel = "Room2_Floor";
    const FString k_Room3FloorLabel = "Room3_Floor";
    const FString k_Room4FloorLabel = "Room4_Floor";
    const FString k_Room5FloorLabel = "Room5_Floor";
    const FString k_Room5CrawlerLabelPrefix = "Mech5_Crawler";
    const FString k_Room5NavFieldLabel = "Mech5_NavField";
    const FString k_Room3BackpackPlateLabel = "Mech3_BackpackPlate";
    const FString k_ItemLabelPrefix = "Item_";
    const FString k_LadderPlatformLabel = "Sandbox_LadderPlatform";
    const FString k_WorkbenchLabel = "Sandbox_Workbench";
    const FString k_DicingStationLabel = "Sandbox_DicingStation";

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
        utils_mars_map_builder::Spawn_Block(Cube, "Floor", FVector(0.0, 0.0, -10.0), FVector(40.0, 40.0, 0.2));

        // Jump/fall: a 60uu step (above MaxStepHeight, below jump apex) then a 120uu platform.
        utils_mars_map_builder::Spawn_Block(Cube, "Ledge_Step", FVector(300.0, -600.0, 30.0), FVector(2.0, 2.0, 0.6));
        utils_mars_map_builder::Spawn_Block(Cube, "Ledge_Platform", FVector(500.0, -600.0, 60.0), FVector(4.0, 4.0, 1.2));

        // Crouch tunnel: 130uu clearance - too low standing (176), fits crouched (~104).
        utils_mars_map_builder::Spawn_Block(Cube, "Tunnel_WallLeft", FVector(500.0, 300.0, 65.0), FVector(4.0, 0.2, 1.3));
        utils_mars_map_builder::Spawn_Block(Cube, "Tunnel_WallRight", FVector(500.0, 600.0, 65.0), FVector(4.0, 0.2, 1.3));
        utils_mars_map_builder::Spawn_Block(Cube, "Tunnel_Roof", FVector(500.0, 450.0, 140.0), FVector(4.0, 3.2, 0.2));

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

        Spawn_Room2(Cube);
        Spawn_Room3(Cube);
        Spawn_Room4(Cube);
        Spawn_Room5(Cube);
        Spawn_Ladder(Cube);
        Spawn_Workbench();
        Spawn_DicingStation();
        Spawn_Gauntlets();

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

    void BuildRoom2()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.BuildRoom2] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_Room2FloorLabel)
            {
                ck::Warning(f"[Mars.Sandbox.BuildRoom2] [{k_Room2FloorLabel}] already exists. Delete the Room2_ and Mech_ actors first to rebuild.");
                return;
            }
        }

        Spawn_Room2(engine::load::Cube());
        Apply_ProtoGridMaterials();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.BuildRoom2] built, saved={Saved}");
    }

    void BuildRoom3()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.BuildRoom3] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_Room3FloorLabel)
            {
                ck::Warning(f"[Mars.Sandbox.BuildRoom3] [{k_Room3FloorLabel}] already exists. Delete the Room3_ and Mech3_ actors first to rebuild.");
                return;
            }
        }

        Spawn_Room3(engine::load::Cube());
        Apply_ProtoGridMaterials();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.BuildRoom3] built, saved={Saved}");
    }

    void BuildRoom4()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.BuildRoom4] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_Room4FloorLabel)
            {
                ck::Warning(f"[Mars.Sandbox.BuildRoom4] [{k_Room4FloorLabel}] already exists. Delete the Room4_ and Mech4_ actors first to rebuild.");
                return;
            }
        }

        Spawn_Room4(engine::load::Cube());
        Apply_ProtoGridMaterials();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.BuildRoom4] built, saved={Saved}");
    }

    void BuildRoom5()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.BuildRoom5] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_Room5FloorLabel)
            {
                ck::Warning(f"[Mars.Sandbox.BuildRoom5] [{k_Room5FloorLabel}] already exists. Delete the Room5_, Mech5_ and Item_Cleaver/Item_Tenderizer actors first to rebuild.");
                return;
            }
        }

        Spawn_Room5(engine::load::Cube());
        Apply_ProtoGridMaterials();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.BuildRoom5] built, saved={Saved}");
    }

    // Four World-mode items on a line 150uu in front of the room-1 player starts (X=-600, facing +X, Y -225..225):
    // enough to fill three bag slots and the overflow slot. They drop the 50uu onto the floor.
    void PlaceItems()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceItems] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel().StartsWith(k_ItemLabelPrefix))
            {
                ck::Warning(f"[Mars.Sandbox.PlaceItems] [{Actor.GetActorLabel()}] already exists. Delete the {k_ItemLabelPrefix} actors first to re-place.");
                return;
            }
        }

        const float64 ItemX = -450.0;
        const float64 ItemZ = 50.0;
        Spawn_Mechanism(UMars_WorldItem_Rock_EntityScript, f"{k_ItemLabelPrefix}Rock_0", FVector(ItemX, -300.0, ItemZ));
        Spawn_Mechanism(UMars_WorldItem_Rock_EntityScript, f"{k_ItemLabelPrefix}Rock_1", FVector(ItemX, -100.0, ItemZ));
        Spawn_Mechanism(UMars_WorldItem_Ration_EntityScript, f"{k_ItemLabelPrefix}Ration", FVector(ItemX, 100.0, ItemZ));
        Spawn_Mechanism(UMars_WorldItem_Cog_EntityScript, f"{k_ItemLabelPrefix}Cog", FVector(ItemX, 300.0, ItemZ));

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceItems] placed, saved={Saved}");
    }

    // The backpack sits past the Cog on the item line (Y=500) and drops the 60uu onto the floor.
    void PlaceBackpack()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceBackpack] Open [{k_MapPath}] first.");
            return;
        }

        const FString Label = f"{k_ItemLabelPrefix}Backpack";
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == Label)
            {
                ck::Warning(f"[Mars.Sandbox.PlaceBackpack] [{Label}] already exists. Delete it first to re-place.");
                return;
            }
        }

        Spawn_Mechanism(UMars_WorldItem_Backpack_EntityScript, Label, FVector(-450.0, 500.0, 60.0));

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceBackpack] placed, saved={Saved}");
    }

    void PlaceBackpackPlate()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceBackpackPlate] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_Room3BackpackPlateLabel)
            {
                ck::Warning(f"[Mars.Sandbox.PlaceBackpackPlate] [{k_Room3BackpackPlateLabel}] already exists. Delete it first to re-place.");
                return;
            }
        }

        Spawn_Room3BackpackPlate();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceBackpackPlate] placed, saved={Saved}");
    }

    // 300uu south of PlateF, between it and room 3's south wall, on the same channel: dropping the pack on it opens GateF.
    void Spawn_Room3BackpackPlate()
    {
        Spawn_Mechanism(UMars_Sandbox_BackpackPlateF_EntityScript, k_Room3BackpackPlateLabel, FVector(2600.0, 950.0, 0.0));
    }

    void PlaceLadder()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceLadder] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_LadderPlatformLabel)
            {
                ck::Warning(f"[Mars.Sandbox.PlaceLadder] [{k_LadderPlatformLabel}] already exists. Delete it and Sandbox_Ladder first to re-place.");
                return;
            }
        }

        Spawn_Ladder(engine::load::Cube());
        Apply_ProtoGridMaterials();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceLadder] placed, saved={Saved}");
    }

    void PlaceWorkbench()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceWorkbench] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_WorkbenchLabel)
            {
                ck::Warning(f"[Mars.Sandbox.PlaceWorkbench] [{k_WorkbenchLabel}] already exists. Delete it first to re-place.");
                return;
            }
        }

        Spawn_Workbench();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceWorkbench] placed, saved={Saved}");
    }

    void PlaceCrawlers()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceCrawlers] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel().StartsWith(k_Room5CrawlerLabelPrefix))
            {
                ck::Warning(f"[Mars.Sandbox.PlaceCrawlers] [{Actor.GetActorLabel()}] already exists. Delete the {k_Room5CrawlerLabelPrefix}* actors first to re-place.");
                return;
            }
        }

        Spawn_Room5Crawlers();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceCrawlers] placed, saved={Saved}");
    }

    void PlaceNavField()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceNavField] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_Room5NavFieldLabel)
            {
                ck::Warning(f"[Mars.Sandbox.PlaceNavField] [{k_Room5NavFieldLabel}] already exists. Delete it first to re-place.");
                return;
            }
        }

        Spawn_Room5NavField();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceNavField] placed, saved={Saved}");
    }

    // The room's ground-nav field: the preset's bounds are local to this placement, so (-3000, 0, 0) covers the room.
    void Spawn_Room5NavField()
    {
        Spawn_Mechanism(UMars_Sandbox_NavField_EntityScript, k_Room5NavFieldLabel, FVector(-3000.0, 0.0, 0.0));
    }

    // The two crawlers at the room's west end, either side of the centre line, 80uu up so they settle onto their feet.
    void Spawn_Room5Crawlers()
    {
        Spawn_Mechanism(UMars_Sandbox_Crawler4_EntityScript, f"{k_Room5CrawlerLabelPrefix}4", FVector(-3400.0, -300.0, 80.0));
        Spawn_Mechanism(UMars_Sandbox_Crawler6_EntityScript, f"{k_Room5CrawlerLabelPrefix}6", FVector(-3400.0, 300.0, 80.0));
    }

    // The workbench station at (-1200, -1200) on the main floor, facing +X: the player walks up from -X and stands 70uu in
    // front of the table.
    void Spawn_Workbench()
    {
        Spawn_Mechanism(UMars_WorkbenchStation_EntityScript, k_WorkbenchLabel, FVector(-1200.0, -1200.0, 0.0));
    }

    void PlaceDicingStation()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceDicingStation] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_DicingStationLabel)
            {
                ck::Warning(f"[Mars.Sandbox.PlaceDicingStation] [{k_DicingStationLabel}] already exists. Delete it first to re-place.");
                return;
            }
        }

        Spawn_DicingStation();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceDicingStation] placed, saved={Saved}");
    }

    // The dicing station at (-1200, -1600) on the main floor, next to the workbench, facing +X: the player walks up from -X
    // and stands 75uu in front of the table.
    void Spawn_DicingStation()
    {
        Spawn_Mechanism(UMars_DicingStation_EntityScript, k_DicingStationLabel, FVector(-1200.0, -1600.0, 0.0));
    }

    // A 400x400x300 platform centred on (-1200, 1200) (top at Z=300) with the ladder at the middle of its south face
    // (Y=1000), yawed so the ladder's local +X points -Y, away from the platform. Its default 300uu height meets the top.
    void Spawn_Ladder(UStaticMesh InCube)
    {
        utils_mars_map_builder::Spawn_Block(InCube, k_LadderPlatformLabel, FVector(-1200.0, 1200.0, 150.0), FVector(4.0, 4.0, 3.0));
        Spawn_Mechanism(UMars_Ladder_EntityScript, "Sandbox_Ladder", FVector(-1200.0, 1000.0, 0.0), FRotator(0.0, -90.0, 0.0));
    }

    // The eyes dummy stands on the floor 450uu in front of the room-1 player starts, past the item line, yawed 180 so it
    // faces them.
    void PlaceEyesDummy()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.PlaceEyesDummy] Open [{k_MapPath}] first.");
            return;
        }

        const FString Label = "EyesDummy";
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == Label)
            {
                ck::Warning(f"[Mars.Sandbox.PlaceEyesDummy] [{Label}] already exists. Delete it first to re-place.");
                return;
            }
        }

        Spawn_Mechanism(UMars_EyesDummy_EntityScript, Label, FVector(-150.0, 0.0, 0.0), FRotator(0.0, 180.0, 0.0));

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.PlaceEyesDummy] placed, saved={Saved}");
    }

    // Room 2 spans X 2000..4000, Y -700..700 (the main floor ends at X=2000). The gated bays sit in a partition at
    // X=3500 with an alcove behind each gate; controls stand 250uu in front (-X) of their gate.
    void Spawn_Room2(UStaticMesh InCube)
    {
        utils_mars_map_builder::Spawn_Block(InCube, k_Room2FloorLabel, FVector(3000.0, 0.0, -10.0), FVector(20.0, 14.0, 0.2));

        // West wall shared with the main floor, with a 300uu doorway centred on Y=0.
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_WallWest_South", FVector(2000.0, -425.0, 150.0), FVector(0.2, 5.5, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_WallWest_North", FVector(2000.0, 425.0, 150.0), FVector(0.2, 5.5, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_WallEast", FVector(4000.0, 0.0, 150.0), FVector(0.2, 14.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_WallSouth", FVector(3000.0, -700.0, 150.0), FVector(20.0, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_WallNorth", FVector(3000.0, 700.0, 150.0), FVector(20.0, 0.2, 3.0));

        // Partition at X=3500 around three 240uu gate frames centred on Y = -460, 0, 460; headers close the gap
        // between each 240uu frame and the 300uu wall top.
        const float64 PartitionX = 3500.0;
        const float64 ControlX = PartitionX - 250.0;
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_Partition_0", FVector(PartitionX, -640.0, 150.0), FVector(0.2, 1.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_Partition_1", FVector(PartitionX, -230.0, 150.0), FVector(0.2, 2.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_Partition_2", FVector(PartitionX, 230.0, 150.0), FVector(0.2, 2.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_Partition_3", FVector(PartitionX, 640.0, 150.0), FVector(0.2, 1.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_AlcoveDivider_South", FVector(3750.0, -230.0, 150.0), FVector(5.0, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_AlcoveDivider_North", FVector(3750.0, 230.0, 150.0), FVector(5.0, 0.2, 3.0));

        // Bay A: one lever opens the gate.
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_GateHeader_A", FVector(PartitionX, -460.0, 270.0), FVector(0.2, 2.4, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateA_EntityScript, "Mech_GateA", FVector(PartitionX, -460.0, 0.0));
        Spawn_Mechanism(UMars_Sandbox_LeverA_EntityScript, "Mech_LeverA", FVector(ControlX, -460.0, 0.0));

        // Bay B: both levers on the same channel must be pulled.
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_GateHeader_B", FVector(PartitionX, 0.0, 270.0), FVector(0.2, 2.4, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateB_EntityScript, "Mech_GateB", FVector(PartitionX, 0.0, 0.0));
        Spawn_Mechanism(UMars_Sandbox_LeverB_EntityScript, "Mech_LeverB1", FVector(ControlX, -80.0, 0.0));
        Spawn_Mechanism(UMars_Sandbox_LeverB_EntityScript, "Mech_LeverB2", FVector(ControlX, 80.0, 0.0));

        // Bay C: a momentary switch on a 100uu pedestal holds the gate open for 4 seconds.
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_GateHeader_C", FVector(PartitionX, 460.0, 270.0), FVector(0.2, 2.4, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateC_EntityScript, "Mech_GateC", FVector(PartitionX, 460.0, 0.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room2_SwitchPedestal_C", FVector(ControlX, 460.0, 50.0), FVector(0.4, 0.4, 1.0));
        Spawn_Mechanism(UMars_Sandbox_SwitchC_EntityScript, "Mech_SwitchC", FVector(ControlX, 460.0, 100.0));
    }

    // Room 3 spans X 2000..4000, Y 700..2100, entered from room 2 through a 300uu doorway at X=3000 in the shared wall
    // (room 2's single north wall is replaced by two segments). A 300uu aisle runs north from the doorway. West of it,
    // a partition at Y=1600 holds GateI and GateF with alcoves behind; the seals sit on the west wall. East of it,
    // three corridors run to the east wall: vent (330 wide, the jet's reach), spikes (200, one tile), pendulum (300).
    void Spawn_Room3(UStaticMesh InCube)
    {
        auto Actors = UEditorActorSubsystem::Get();
        for (auto Actor : Actors.GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == "Room2_WallNorth")
            { Actors.DestroyActor(Actor); }
        }

        utils_mars_map_builder::Spawn_Block(InCube, k_Room3FloorLabel, FVector(3000.0, 1400.0, -10.0), FVector(20.0, 14.0, 0.2));

        utils_mars_map_builder::Spawn_Block(InCube, "Room3_WallSouth_West", FVector(2425.0, 700.0, 150.0), FVector(8.5, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_WallSouth_East", FVector(3575.0, 700.0, 150.0), FVector(8.5, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_WallWest", FVector(2000.0, 1400.0, 150.0), FVector(0.2, 14.0, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_WallEast", FVector(4000.0, 1400.0, 150.0), FVector(0.2, 14.0, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_WallNorth", FVector(3000.0, 2100.0, 150.0), FVector(20.2, 0.2, 3.0));

        // West half. Gates are yawed 90 so their opening spans X; frames are 240uu wide, centred on X = 2250 and 2600.
        const float64 PartitionY = 1600.0;
        const auto GateRotation = FRotator(0.0, 90.0, 0.0);
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_Partition_0", FVector(2065.0, PartitionY, 150.0), FVector(1.3, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_Partition_1", FVector(2425.0, PartitionY, 150.0), FVector(1.1, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_Partition_2", FVector(2785.0, PartitionY, 150.0), FVector(1.3, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_AlcoveDivider", FVector(2425.0, 1850.0, 150.0), FVector(0.2, 5.0, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_AlcoveWall_East", FVector(2850.0, 1850.0, 150.0), FVector(0.2, 5.0, 3.0));

        // Bay 1: standing on the plate opens GateF; it closes 1.5s after stepping off. The backpack plate south of it
        // holds GateF open while a dropped backpack lies on it.
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_GateHeader_F", FVector(2600.0, PartitionY, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateF_EntityScript, "Mech3_GateF", FVector(2600.0, PartitionY, 0.0), GateRotation);
        Spawn_Mechanism(UMars_Sandbox_PlateF_EntityScript, "Mech3_Plate", FVector(2600.0, 1250.0, 0.0));
        Spawn_Room3BackpackPlate();

        // Bay 2: seals face +X off the west wall (pitch -90); pressing H then G completes the sequence and latches GateI.
        const auto SealRotation = FRotator(-90.0, 0.0, 0.0);
        Spawn_Mechanism(UMars_Sandbox_SealG_EntityScript, "Mech3_Seal1", FVector(2010.0, 1000.0, 120.0), SealRotation);
        Spawn_Mechanism(UMars_Sandbox_SealH_EntityScript, "Mech3_Seal2", FVector(2010.0, 1200.0, 120.0), SealRotation);
        Spawn_Mechanism(UMars_Sandbox_SequenceI_EntityScript, "Mech3_SeqNode", FVector(2100.0, 1400.0, 0.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_GateHeader_I", FVector(2250.0, PartitionY, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateI_EntityScript, "Mech3_GateI", FVector(2250.0, PartitionY, 0.0), GateRotation);

        // East half: corridor dividers from the aisle (X=3150) to the east wall.
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_CorridorWall_0", FVector(3575.0, 1050.0, 150.0), FVector(8.5, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_CorridorWall_1", FVector(3575.0, 1270.0, 150.0), FVector(8.5, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room3_CorridorWall_2", FVector(3575.0, 1590.0, 150.0), FVector(8.5, 0.2, 3.0));

        // Bay 3 (Y 710..1040): the vent on the south wall fires north across the corridor; holding the wheel for 2s
        // suppresses it for 8s. Both are yawed 90 so their local +X points north.
        const auto NorthRotation = FRotator(0.0, 90.0, 0.0);
        Spawn_Mechanism(UMars_Sandbox_WheelJ_EntityScript, "Mech3_Wheel", FVector(3300.0, 710.0, 110.0), NorthRotation);
        Spawn_Mechanism(UMars_Sandbox_VentJ_EntityScript, "Mech3_Vent", FVector(3600.0, 710.0, 0.0), NorthRotation);

        // Bay 4 (Y 1060..1260): two spike tiles in a row, suppressed while the lever before them is pulled.
        Spawn_Mechanism(UMars_Sandbox_LeverK_EntityScript, "Mech3_LeverK", FVector(3280.0, 1215.0, 0.0));
        Spawn_Mechanism(UMars_Sandbox_SpikesK_EntityScript, "Mech3_Spikes1", FVector(3500.0, 1160.0, 0.0));
        Spawn_Mechanism(UMars_Sandbox_SpikesK_EntityScript, "Mech3_Spikes2", FVector(3700.0, 1160.0, 0.0));

        // Bay 5 (Y 1280..1580): the pendulum swings across the corridor (yawed so its swing plane is north-south).
        Spawn_Mechanism(UMars_Sandbox_Pendulum_EntityScript, "Mech3_Pendulum", FVector(3600.0, 1430.0, 0.0), NorthRotation);
    }

    // Room 4 spans X 2000..4000, Y -2100..-700 (room 2's south wall is its north wall), entered from the main floor through
    // a 300uu doorway centred on Y=-1400 in its west wall. A partition at X=3200 holds GateM, with the lamp bank on the
    // header over it and a chain on each side of the partition.
    void Spawn_Room4(UStaticMesh InCube)
    {
        utils_mars_map_builder::Spawn_Block(InCube, k_Room4FloorLabel, FVector(3000.0, -1400.0, -10.0), FVector(20.0, 14.0, 0.2));

        utils_mars_map_builder::Spawn_Block(InCube, "Room4_WallWest_South", FVector(2000.0, -1825.0, 150.0), FVector(0.2, 5.5, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room4_WallWest_North", FVector(2000.0, -975.0, 150.0), FVector(0.2, 5.5, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room4_WallSouth", FVector(3000.0, -2100.0, 150.0), FVector(20.2, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room4_WallEast", FVector(4000.0, -1400.0, 150.0), FVector(0.2, 14.0, 3.0));

        // Partition around a 240uu gate frame centred on Y=-1400; the header closes the gap to the 300uu wall top.
        const float64 PartitionX = 3200.0;
        const float64 GateY = -1400.0;
        utils_mars_map_builder::Spawn_Block(InCube, "Room4_Partition_South", FVector(PartitionX, -1810.0, 150.0), FVector(0.2, 5.8, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room4_Partition_North", FVector(PartitionX, -990.0, 150.0), FVector(0.2, 5.8, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room4_GateHeader_M", FVector(PartitionX, GateY, 270.0), FVector(0.2, 2.4, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateM_EntityScript, "Mech4_GateM", FVector(PartitionX, GateY, 0.0));

        // Lamps on the header's west face, facing the player (yaw 180 turns their local +X to -X).
        const auto WestFacing = FRotator(0.0, 180.0, 0.0);
        Spawn_Mechanism(UMars_Sandbox_LampsL_EntityScript, "Mech4_Lamps", FVector(PartitionX - 10.0, GateY, 270.0), WestFacing);

        // A chain beside the gate on each face of the partition, grip bar at about chest height.
        Spawn_Mechanism(UMars_Sandbox_ChainL_EntityScript, "Mech4_ChainOutside", FVector(PartitionX - 10.0, -1650.0, 260.0), WestFacing);
        Spawn_Mechanism(UMars_Sandbox_ChainL_EntityScript, "Mech4_ChainInside", FVector(PartitionX + 10.0, -1150.0, 260.0));

        // Something to run to.
        utils_mars_map_builder::Spawn_Block(InCube, "Room4_Plinth", FVector(3700.0, GateY, 40.0), FVector(1.0, 1.0, 0.8));
    }

    // Room 5 spans X -4000..-2000, Y -700..700 (the main floor ends at X=-2000), entered from the main floor through a
    // 300uu doorway centred on Y=0 in its east wall. A pillar and a 40uu step break up the floor for the crawlers; the
    // target dummy stands 400uu in from the doorway, and the cleaver and tenderizer lie just inside it. A ground-nav field
    // covers the room.
    void Spawn_Room5(UStaticMesh InCube)
    {
        utils_mars_map_builder::Spawn_Block(InCube, k_Room5FloorLabel, FVector(-3000.0, 0.0, -10.0), FVector(20.0, 14.0, 0.2));

        // East wall shared with the main floor, with a 300uu doorway centred on Y=0.
        utils_mars_map_builder::Spawn_Block(InCube, "Room5_WallEast_South", FVector(-2000.0, -425.0, 150.0), FVector(0.2, 5.5, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room5_WallEast_North", FVector(-2000.0, 425.0, 150.0), FVector(0.2, 5.5, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room5_WallWest", FVector(-4000.0, 0.0, 150.0), FVector(0.2, 14.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room5_WallSouth", FVector(-3000.0, -700.0, 150.0), FVector(20.0, 0.2, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room5_WallNorth", FVector(-3000.0, 700.0, 150.0), FVector(20.0, 0.2, 3.0));

        // A 60x60x300 pillar and a 200x200x40 step.
        utils_mars_map_builder::Spawn_Block(InCube, "Room5_Pillar", FVector(-3300.0, 250.0, 150.0), FVector(0.6, 0.6, 3.0));
        utils_mars_map_builder::Spawn_Block(InCube, "Room5_Step", FVector(-2700.0, -300.0, 20.0), FVector(2.0, 2.0, 0.4));

        Spawn_Mechanism(UMars_TargetDummy_EntityScript, "Mech5_Dummy", FVector(-2400.0, 0.0, 0.0));

        // The melee items drop the 30uu onto the floor.
        Spawn_Mechanism(UMars_Sandbox_Cleaver_EntityScript, f"{k_ItemLabelPrefix}Cleaver", FVector(-2250.0, -120.0, 30.0));
        Spawn_Mechanism(UMars_Sandbox_Tenderizer_EntityScript, f"{k_ItemLabelPrefix}Tenderizer", FVector(-2250.0, 120.0, 30.0));

        Spawn_Room5Crawlers();
        Spawn_Room5NavField();
    }

    // Goes through the spawner's actor factory (the Place Actors path): it instances the script class on a new
    // ACk_EntitySpawner_UE, and the spawner injects its actor transform into SpawnTransform at spawn.
    void Spawn_Mechanism(TSubclassOf<UCk_EntityScript_UE> InScriptClass, const FString& InLabel, FVector InLocation,
                         FRotator InRotation = FRotator::ZeroRotator)
    {
        auto Spawner = Cast<ACk_EntitySpawner_UE>(
            UEditorActorSubsystem::Get().SpawnActorFromObject(InScriptClass.Get(), InLocation, InRotation));
        if (ck::EnsureIfNot(ck::IsValid(Spawner), f"[Mars.Sandbox] Failed to place [{InLabel}] through the entity spawner factory"))
        { return; }

        Spawner.SetActorLabel(InLabel);
    }

    // Matches blocks by the labels Build gives them.
    void Apply_ProtoGridMaterials()
    {
        auto Floor = utils_mars_map_builder::Get_ProtoGrid_Floor();
        auto Wall = utils_mars_map_builder::Get_ProtoGrid_Wall();
        auto Platform = utils_mars_map_builder::Get_ProtoGrid_Platform();
        auto Interactable = utils_mars_map_builder::Get_ProtoGrid_Interactable();

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
            else if (Label == k_LadderPlatformLabel)
            { Block.StaticMeshComponent.SetMaterial(0, Platform); }
            else if (Label.StartsWith("Ledge_"))
            { Block.StaticMeshComponent.SetMaterial(0, Platform); }
            else if (Label.StartsWith("Tunnel_"))
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
            else if (Label == k_Room2FloorLabel)
            { Block.StaticMeshComponent.SetMaterial(0, Floor); }
            else if (Label.StartsWith("Room2_"))
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
            else if (Label == k_Room3FloorLabel)
            { Block.StaticMeshComponent.SetMaterial(0, Floor); }
            else if (Label.StartsWith("Room3_"))
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
            else if (Label == k_Room4FloorLabel)
            { Block.StaticMeshComponent.SetMaterial(0, Floor); }
            else if (Label == "Room4_Plinth")
            { Block.StaticMeshComponent.SetMaterial(0, Platform); }
            else if (Label.StartsWith("Room4_"))
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
            else if (Label == k_Room5FloorLabel)
            { Block.StaticMeshComponent.SetMaterial(0, Floor); }
            else if (Label == "Room5_Pillar" || Label == "Room5_Step")
            { Block.StaticMeshComponent.SetMaterial(0, Platform); }
            else if (Label.StartsWith("Room5_"))
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
            else if (Label.StartsWith(k_GauntletLabelPrefix))
            { Apply_GauntletMaterial(Block, Label); }
        }
    }
}
#endif
