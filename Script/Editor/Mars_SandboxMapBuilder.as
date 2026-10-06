// Editor-only: generates the gameplay sandbox map into /Game/Mars/Maps/Sandbox_Mars_MAP. Open File > New Level > Empty
// Level, then run Mars.Sandbox.Build. The Mars.Sandbox.BuildRoomN / Place* / BuildGauntlets commands add one part to an
// already-built sandbox map, so a map built before that part existed can catch up without a rebuild.
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

UFUNCTION()
void Mars_PlaceSandboxSearingStationFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceSearingStation();
}

const FConsoleCommand Mars_PlaceSandboxSearingStationCommand("Mars.Sandbox.PlaceSearingStation", n"Mars_PlaceSandboxSearingStationFunc");

// One of the sandbox items PlaceItems places.
struct FMars_Sandbox_ItemPlacement
{
    TSubclassOf<UCk_EntityScript_UE> ScriptClass;
    FMars_MapBuilder_Placement Placement;

    FMars_Sandbox_ItemPlacement() {}

    FMars_Sandbox_ItemPlacement(TSubclassOf<UCk_EntityScript_UE> InScriptClass, const FMars_MapBuilder_Placement& InPlacement)
    {
        ScriptClass = InScriptClass;
        Placement = InPlacement;
    }
}

namespace utils_mars_sandbox
{
    const FString k_MapPath = "/Game/Mars/Maps/Sandbox_Mars_MAP";
    const FString k_Room2FloorLabel = "Room2_Floor";
    const FString k_Room2NorthWallLabel = "Room2_WallNorth";
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
    const FString k_SearingStationLabel = "Sandbox_SearingStation";
    const FString k_EyesDummyLabel = "EyesDummy";

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

        // Top face at Z=0.
        Spawn_Cube("Floor", FVector(0.0, 0.0, -10.0), FVector(40.0, 40.0, 0.2));

        // Jump/fall: a 60uu step (above MaxStepHeight, below jump apex) then a 120uu platform.
        Spawn_Cube("Ledge_Step", FVector(300.0, -600.0, 30.0), FVector(2.0, 2.0, 0.6));
        Spawn_Cube("Ledge_Platform", FVector(500.0, -600.0, 60.0), FVector(4.0, 4.0, 1.2));

        // Crouch tunnel: 130uu clearance - too low standing (176), fits crouched (~104).
        Spawn_Cube("Tunnel_WallLeft", FVector(500.0, 300.0, 65.0), FVector(4.0, 0.2, 1.3));
        Spawn_Cube("Tunnel_WallRight", FVector(500.0, 600.0, 65.0), FVector(4.0, 0.2, 1.3));
        Spawn_Cube("Tunnel_Roof", FVector(500.0, 450.0, 140.0), FVector(4.0, 3.2, 0.2));

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

        Spawn_Room2();
        Spawn_Room3();
        Spawn_Room4();
        Spawn_Room5();
        Spawn_Ladder();
        Spawn_Workbench();
        Spawn_DicingStation();
        Spawn_SearingStation();
        Spawn_Gauntlets();

        Apply_ProtoGridMaterials();

        const bool Saved = UEditorLoadingAndSavingUtils::SaveMap(World, k_MapPath);
        ck::Trace(f"[Mars.Sandbox.Build] [{k_MapPath}] built, saved={Saved}");
    }

    // The guard of every command that adds one part to an already-built sandbox map: the map is open and InLabel (the
    // part's marker actor) is not placed yet. InHint says what to delete to redo it.
    bool Get_CanAdd(const FString& InCommand, const FString& InLabel, const FString& InHint)
    {
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(InCommand, k_MapPath)))
        { return false; }

        return utils_mars_map_builder::Get_IsUnblocked(InCommand, utils_mars_map_builder::TryGet_LevelActor(InLabel), InHint);
    }

    void ApplyMaterials()
    {
        const FString Command = "Mars.Sandbox.ApplyMaterials";
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(Command, k_MapPath)))
        { return; }

        Apply_ProtoGridMaterials();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void BuildRoom2()
    {
        const FString Command = "Mars.Sandbox.BuildRoom2";
        if (Get_CanAdd(Command, k_Room2FloorLabel, "Delete the Room2_ and Mech_ actors first to rebuild.") == false)
        { return; }

        Spawn_Room2();
        Apply_ProtoGridMaterials();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void BuildRoom3()
    {
        const FString Command = "Mars.Sandbox.BuildRoom3";
        if (Get_CanAdd(Command, k_Room3FloorLabel, "Delete the Room3_ and Mech3_ actors first to rebuild.") == false)
        { return; }

        Spawn_Room3();
        Apply_ProtoGridMaterials();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void BuildRoom4()
    {
        const FString Command = "Mars.Sandbox.BuildRoom4";
        if (Get_CanAdd(Command, k_Room4FloorLabel, "Delete the Room4_ and Mech4_ actors first to rebuild.") == false)
        { return; }

        Spawn_Room4();
        Apply_ProtoGridMaterials();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void BuildRoom5()
    {
        const FString Command = "Mars.Sandbox.BuildRoom5";
        if (Get_CanAdd(Command, k_Room5FloorLabel, "Delete the Room5_, Mech5_ and Item_Cleaver/Item_Tenderizer actors first to rebuild.") == false)
        { return; }

        Spawn_Room5();
        Apply_ProtoGridMaterials();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Four World-mode items in front of the player starts, enough to fill three bag slots and the overflow slot; they drop
    // the 50uu onto the floor. Only their own labels block a re-place: Build (room 5's melee items) and PlaceBackpack also
    // place Item_ actors.
    void PlaceItems()
    {
        const FString Command = "Mars.Sandbox.PlaceItems";
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(Command, k_MapPath)))
        { return; }

        const float64 ItemX = -450.0;
        const float64 ItemZ = 50.0;
        TArray<FMars_Sandbox_ItemPlacement> Items;
        Items.Add(FMars_Sandbox_ItemPlacement(UMars_WorldItem_Rock_EntityScript,
            FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Rock_0", FVector(ItemX, -300.0, ItemZ))));
        Items.Add(FMars_Sandbox_ItemPlacement(UMars_WorldItem_Rock_EntityScript,
            FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Rock_1", FVector(ItemX, -100.0, ItemZ))));
        Items.Add(FMars_Sandbox_ItemPlacement(UMars_WorldItem_Ration_EntityScript,
            FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Ration", FVector(ItemX, 100.0, ItemZ))));
        Items.Add(FMars_Sandbox_ItemPlacement(UMars_WorldItem_Cog_EntityScript,
            FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Cog", FVector(ItemX, 300.0, ItemZ))));

        for (const auto& Item : Items)
        {
            auto Blocker = utils_mars_map_builder::TryGet_LevelActor(Item.Placement.Label);
            if (utils_mars_map_builder::Get_IsUnblocked(Command, Blocker, "Delete the four sandbox items first to re-place.") == false)
            { return; }
        }

        for (const auto& Item : Items)
        { Spawn_Mechanism(Item.ScriptClass, Item.Placement); }

        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Past the Cog on the item line; it drops the 60uu onto the floor.
    void PlaceBackpack()
    {
        const FString Command = "Mars.Sandbox.PlaceBackpack";
        const FString Label = f"{k_ItemLabelPrefix}Backpack";
        if (Get_CanAdd(Command, Label, "Delete it first to re-place.") == false)
        { return; }

        Spawn_Mechanism(UMars_WorldItem_Backpack_EntityScript, FMars_MapBuilder_Placement(Label, FVector(-450.0, 500.0, 60.0)));
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void PlaceBackpackPlate()
    {
        const FString Command = "Mars.Sandbox.PlaceBackpackPlate";
        if (Get_CanAdd(Command, k_Room3BackpackPlateLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_Room3BackpackPlate();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Between PlateF and room 3's south wall, on PlateF's channel: dropping the pack on it opens GateF.
    void Spawn_Room3BackpackPlate()
    {
        Spawn_Mechanism(UMars_Sandbox_BackpackPlateF_EntityScript, FMars_MapBuilder_Placement(k_Room3BackpackPlateLabel, FVector(2600.0, 950.0, 0.0)));
    }

    void PlaceLadder()
    {
        const FString Command = "Mars.Sandbox.PlaceLadder";
        if (Get_CanAdd(Command, k_LadderPlatformLabel, "Delete it and Sandbox_Ladder first to re-place.") == false)
        { return; }

        Spawn_Ladder();
        Apply_ProtoGridMaterials();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void PlaceWorkbench()
    {
        const FString Command = "Mars.Sandbox.PlaceWorkbench";
        if (Get_CanAdd(Command, k_WorkbenchLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_Workbench();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void PlaceCrawlers()
    {
        const FString Command = "Mars.Sandbox.PlaceCrawlers";
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(Command, k_MapPath)))
        { return; }

        auto Blocker = utils_mars_map_builder::TryGet_LevelActorWithPrefix(k_Room5CrawlerLabelPrefix);
        if (utils_mars_map_builder::Get_IsUnblocked(Command, Blocker, f"Delete the {k_Room5CrawlerLabelPrefix}* actors first to re-place.") == false)
        { return; }

        Spawn_Room5Crawlers();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void PlaceNavField()
    {
        const FString Command = "Mars.Sandbox.PlaceNavField";
        if (Get_CanAdd(Command, k_Room5NavFieldLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_Room5NavField();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // The preset's bounds are local to this placement, so placing it at the room's centre covers the room.
    void Spawn_Room5NavField()
    {
        Spawn_Mechanism(UMars_Sandbox_NavField_EntityScript, FMars_MapBuilder_Placement(k_Room5NavFieldLabel, FVector(-3000.0, 0.0, 0.0)));
    }

    // 80uu up so they settle onto their feet.
    void Spawn_Room5Crawlers()
    {
        Spawn_Mechanism(UMars_Sandbox_Crawler4_EntityScript, FMars_MapBuilder_Placement(f"{k_Room5CrawlerLabelPrefix}4", FVector(-3400.0, -300.0, 80.0)));
        Spawn_Mechanism(UMars_Sandbox_Crawler6_EntityScript, FMars_MapBuilder_Placement(f"{k_Room5CrawlerLabelPrefix}6", FVector(-3400.0, 300.0, 80.0)));
    }

    // Unrotated, it faces +X: the player walks up from -X.
    void Spawn_Workbench()
    {
        Spawn_Mechanism(UMars_WorkbenchStation_EntityScript, FMars_MapBuilder_Placement(k_WorkbenchLabel, FVector(-1200.0, -1200.0, 0.0)));
    }

    void PlaceDicingStation()
    {
        const FString Command = "Mars.Sandbox.PlaceDicingStation";
        if (Get_CanAdd(Command, k_DicingStationLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_DicingStation();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Beside the workbench; unrotated, it faces +X: the player walks up from -X.
    void Spawn_DicingStation()
    {
        Spawn_Mechanism(UMars_DicingStation_EntityScript, FMars_MapBuilder_Placement(k_DicingStationLabel, FVector(-1200.0, -1600.0, 0.0)));
    }

    void PlaceSearingStation()
    {
        const FString Command = "Mars.Sandbox.PlaceSearingStation";
        if (Get_CanAdd(Command, k_SearingStationLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_SearingStation();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Beside the dicing station, 400 uu toward +X; unrotated, it faces +X: the player walks up from -X.
    void Spawn_SearingStation()
    {
        Spawn_Mechanism(UMars_SearingStation_EntityScript, FMars_MapBuilder_Placement(k_SearingStationLabel, FVector(-800.0, -1600.0, 0.0)));
    }

    // The ladder stands at the middle of the platform's south face, yawed so its local +X points away from the platform;
    // its default 300uu height meets the platform's top.
    void Spawn_Ladder()
    {
        Spawn_Cube(k_LadderPlatformLabel, FVector(-1200.0, 1200.0, 150.0), FVector(4.0, 4.0, 3.0));
        Spawn_Mechanism(UMars_Ladder_EntityScript, FMars_MapBuilder_Placement("Sandbox_Ladder", FVector(-1200.0, 1000.0, 0.0), FRotator(0.0, -90.0, 0.0)));
    }

    // Yawed 180 so it faces the player starts.
    void PlaceEyesDummy()
    {
        const FString Command = "Mars.Sandbox.PlaceEyesDummy";
        if (Get_CanAdd(Command, k_EyesDummyLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_Mechanism(UMars_EyesDummy_EntityScript, FMars_MapBuilder_Placement(k_EyesDummyLabel, FVector(-150.0, 0.0, 0.0), FRotator(0.0, 180.0, 0.0)));
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // East of the main floor. The gated bays sit in a partition with an alcove behind each gate; controls stand 250uu in
    // front (-X) of their gate.
    void Spawn_Room2()
    {
        Spawn_Cube(k_Room2FloorLabel, FVector(3000.0, 0.0, -10.0), FVector(20.0, 14.0, 0.2));

        // West wall shared with the main floor, with a 300uu doorway centred on Y=0.
        Spawn_Cube("Room2_WallWest_South", FVector(2000.0, -425.0, 150.0), FVector(0.2, 5.5, 3.0));
        Spawn_Cube("Room2_WallWest_North", FVector(2000.0, 425.0, 150.0), FVector(0.2, 5.5, 3.0));
        Spawn_Cube("Room2_WallEast", FVector(4000.0, 0.0, 150.0), FVector(0.2, 14.2, 3.0));
        Spawn_Cube("Room2_WallSouth", FVector(3000.0, -700.0, 150.0), FVector(20.0, 0.2, 3.0));

        // Room 3's two south wall segments replace this wall around its doorway (Spawn_Room3 destroys it), so a room 2
        // rebuilt beside an existing room 3 must not bring it back.
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_LevelActor(k_Room3FloorLabel)))
        { Spawn_Cube(k_Room2NorthWallLabel, FVector(3000.0, 700.0, 150.0), FVector(20.0, 0.2, 3.0)); }

        // Partition around three 240uu gate frames; headers close the gap between each frame and the 300uu wall top.
        const float64 PartitionX = 3500.0;
        const float64 ControlX = PartitionX - 250.0;
        Spawn_Cube("Room2_Partition_0", FVector(PartitionX, -640.0, 150.0), FVector(0.2, 1.2, 3.0));
        Spawn_Cube("Room2_Partition_1", FVector(PartitionX, -230.0, 150.0), FVector(0.2, 2.2, 3.0));
        Spawn_Cube("Room2_Partition_2", FVector(PartitionX, 230.0, 150.0), FVector(0.2, 2.2, 3.0));
        Spawn_Cube("Room2_Partition_3", FVector(PartitionX, 640.0, 150.0), FVector(0.2, 1.2, 3.0));
        Spawn_Cube("Room2_AlcoveDivider_South", FVector(3750.0, -230.0, 150.0), FVector(5.0, 0.2, 3.0));
        Spawn_Cube("Room2_AlcoveDivider_North", FVector(3750.0, 230.0, 150.0), FVector(5.0, 0.2, 3.0));

        // Bay A: one lever opens the gate.
        Spawn_Cube("Room2_GateHeader_A", FVector(PartitionX, -460.0, 270.0), FVector(0.2, 2.4, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateA_EntityScript, FMars_MapBuilder_Placement("Mech_GateA", FVector(PartitionX, -460.0, 0.0)));
        Spawn_Mechanism(UMars_Sandbox_LeverA_EntityScript, FMars_MapBuilder_Placement("Mech_LeverA", FVector(ControlX, -460.0, 0.0)));

        // Bay B: both levers on the same channel must be pulled.
        Spawn_Cube("Room2_GateHeader_B", FVector(PartitionX, 0.0, 270.0), FVector(0.2, 2.4, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateB_EntityScript, FMars_MapBuilder_Placement("Mech_GateB", FVector(PartitionX, 0.0, 0.0)));
        Spawn_Mechanism(UMars_Sandbox_LeverB_EntityScript, FMars_MapBuilder_Placement("Mech_LeverB1", FVector(ControlX, -80.0, 0.0)));
        Spawn_Mechanism(UMars_Sandbox_LeverB_EntityScript, FMars_MapBuilder_Placement("Mech_LeverB2", FVector(ControlX, 80.0, 0.0)));

        // Bay C: a momentary switch on a 100uu pedestal holds the gate open for 4 seconds.
        Spawn_Cube("Room2_GateHeader_C", FVector(PartitionX, 460.0, 270.0), FVector(0.2, 2.4, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateC_EntityScript, FMars_MapBuilder_Placement("Mech_GateC", FVector(PartitionX, 460.0, 0.0)));
        Spawn_Cube("Room2_SwitchPedestal_C", FVector(ControlX, 460.0, 50.0), FVector(0.4, 0.4, 1.0));
        Spawn_Mechanism(UMars_Sandbox_SwitchC_EntityScript, FMars_MapBuilder_Placement("Mech_SwitchC", FVector(ControlX, 460.0, 100.0)));
    }

    // North of room 2, entered through a doorway in the shared wall (room 2's single north wall is replaced by two
    // segments). A 300uu aisle runs north from the doorway. West of it, a partition holds GateI and GateF with alcoves
    // behind; the seals sit on the west wall. East of it, three corridors run to the east wall: vent (330 wide, the jet's
    // reach), spikes (200, one tile), pendulum (300).
    void Spawn_Room3()
    {
        auto Actors = UEditorActorSubsystem::Get();
        for (auto Actor : Actors.GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_Room2NorthWallLabel)
            { Actors.DestroyActor(Actor); }
        }

        Spawn_Cube(k_Room3FloorLabel, FVector(3000.0, 1400.0, -10.0), FVector(20.0, 14.0, 0.2));

        Spawn_Cube("Room3_WallSouth_West", FVector(2425.0, 700.0, 150.0), FVector(8.5, 0.2, 3.0));
        Spawn_Cube("Room3_WallSouth_East", FVector(3575.0, 700.0, 150.0), FVector(8.5, 0.2, 3.0));
        Spawn_Cube("Room3_WallWest", FVector(2000.0, 1400.0, 150.0), FVector(0.2, 14.0, 3.0));
        Spawn_Cube("Room3_WallEast", FVector(4000.0, 1400.0, 150.0), FVector(0.2, 14.0, 3.0));
        Spawn_Cube("Room3_WallNorth", FVector(3000.0, 2100.0, 150.0), FVector(20.2, 0.2, 3.0));

        // West half. Gates are yawed 90 so their opening spans X.
        const float64 PartitionY = 1600.0;
        const auto GateRotation = FRotator(0.0, 90.0, 0.0);
        Spawn_Cube("Room3_Partition_0", FVector(2065.0, PartitionY, 150.0), FVector(1.3, 0.2, 3.0));
        Spawn_Cube("Room3_Partition_1", FVector(2425.0, PartitionY, 150.0), FVector(1.1, 0.2, 3.0));
        Spawn_Cube("Room3_Partition_2", FVector(2785.0, PartitionY, 150.0), FVector(1.3, 0.2, 3.0));
        Spawn_Cube("Room3_AlcoveDivider", FVector(2425.0, 1850.0, 150.0), FVector(0.2, 5.0, 3.0));
        Spawn_Cube("Room3_AlcoveWall_East", FVector(2850.0, 1850.0, 150.0), FVector(0.2, 5.0, 3.0));

        // Bay 1: standing on the plate opens GateF; it closes 1.5s after stepping off. The backpack plate south of it
        // holds GateF open while a dropped backpack lies on it.
        Spawn_Cube("Room3_GateHeader_F", FVector(2600.0, PartitionY, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateF_EntityScript, FMars_MapBuilder_Placement("Mech3_GateF", FVector(2600.0, PartitionY, 0.0), GateRotation));
        Spawn_Mechanism(UMars_Sandbox_PlateF_EntityScript, FMars_MapBuilder_Placement("Mech3_Plate", FVector(2600.0, 1250.0, 0.0)));
        Spawn_Room3BackpackPlate();

        // Bay 2: seals face +X off the west wall (pitch -90); pressing H then G completes the sequence and latches GateI.
        const auto SealRotation = FRotator(-90.0, 0.0, 0.0);
        Spawn_Mechanism(UMars_Sandbox_SealG_EntityScript, FMars_MapBuilder_Placement("Mech3_Seal1", FVector(2010.0, 1000.0, 120.0), SealRotation));
        Spawn_Mechanism(UMars_Sandbox_SealH_EntityScript, FMars_MapBuilder_Placement("Mech3_Seal2", FVector(2010.0, 1200.0, 120.0), SealRotation));
        Spawn_Mechanism(UMars_Sandbox_SequenceI_EntityScript, FMars_MapBuilder_Placement("Mech3_SeqNode", FVector(2100.0, 1400.0, 0.0)));
        Spawn_Cube("Room3_GateHeader_I", FVector(2250.0, PartitionY, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateI_EntityScript, FMars_MapBuilder_Placement("Mech3_GateI", FVector(2250.0, PartitionY, 0.0), GateRotation));

        // East half: corridor dividers from the aisle (X=3150) to the east wall.
        Spawn_Cube("Room3_CorridorWall_0", FVector(3575.0, 1050.0, 150.0), FVector(8.5, 0.2, 3.0));
        Spawn_Cube("Room3_CorridorWall_1", FVector(3575.0, 1270.0, 150.0), FVector(8.5, 0.2, 3.0));
        Spawn_Cube("Room3_CorridorWall_2", FVector(3575.0, 1590.0, 150.0), FVector(8.5, 0.2, 3.0));

        // Bay 3 (Y 710..1040): the vent on the south wall fires north across the corridor; holding the wheel for 2s
        // suppresses it for 8s. Both are yawed 90 so their local +X points north.
        const auto NorthRotation = FRotator(0.0, 90.0, 0.0);
        Spawn_Mechanism(UMars_Sandbox_WheelJ_EntityScript, FMars_MapBuilder_Placement("Mech3_Wheel", FVector(3300.0, 710.0, 110.0), NorthRotation));
        Spawn_Mechanism(UMars_Sandbox_VentJ_EntityScript, FMars_MapBuilder_Placement("Mech3_Vent", FVector(3600.0, 710.0, 0.0), NorthRotation));

        // Bay 4 (Y 1060..1260): two spike tiles in a row, suppressed while the lever before them is pulled.
        Spawn_Mechanism(UMars_Sandbox_LeverK_EntityScript, FMars_MapBuilder_Placement("Mech3_LeverK", FVector(3280.0, 1215.0, 0.0)));
        Spawn_Mechanism(UMars_Sandbox_SpikesK_EntityScript, FMars_MapBuilder_Placement("Mech3_Spikes1", FVector(3500.0, 1160.0, 0.0)));
        Spawn_Mechanism(UMars_Sandbox_SpikesK_EntityScript, FMars_MapBuilder_Placement("Mech3_Spikes2", FVector(3700.0, 1160.0, 0.0)));

        // Bay 5 (Y 1280..1580): the pendulum swings across the corridor (yawed so its swing plane is north-south).
        Spawn_Mechanism(UMars_Sandbox_Pendulum_EntityScript, FMars_MapBuilder_Placement("Mech3_Pendulum", FVector(3600.0, 1430.0, 0.0), NorthRotation));
    }

    // South of room 2 (room 2's south wall is its north wall), entered from the main floor through a doorway in its west
    // wall. A partition holds GateM, with the lamp bank on the header over it and a chain on each side of the partition.
    void Spawn_Room4()
    {
        Spawn_Cube(k_Room4FloorLabel, FVector(3000.0, -1400.0, -10.0), FVector(20.0, 14.0, 0.2));

        Spawn_Cube("Room4_WallWest_South", FVector(2000.0, -1825.0, 150.0), FVector(0.2, 5.5, 3.0));
        Spawn_Cube("Room4_WallWest_North", FVector(2000.0, -975.0, 150.0), FVector(0.2, 5.5, 3.0));
        Spawn_Cube("Room4_WallSouth", FVector(3000.0, -2100.0, 150.0), FVector(20.2, 0.2, 3.0));
        Spawn_Cube("Room4_WallEast", FVector(4000.0, -1400.0, 150.0), FVector(0.2, 14.0, 3.0));

        // Partition around a 240uu gate frame; the header closes the gap to the 300uu wall top.
        const float64 PartitionX = 3200.0;
        const float64 GateY = -1400.0;
        Spawn_Cube("Room4_Partition_South", FVector(PartitionX, -1810.0, 150.0), FVector(0.2, 5.8, 3.0));
        Spawn_Cube("Room4_Partition_North", FVector(PartitionX, -990.0, 150.0), FVector(0.2, 5.8, 3.0));
        Spawn_Cube("Room4_GateHeader_M", FVector(PartitionX, GateY, 270.0), FVector(0.2, 2.4, 0.6));
        Spawn_Mechanism(UMars_Sandbox_GateM_EntityScript, FMars_MapBuilder_Placement("Mech4_GateM", FVector(PartitionX, GateY, 0.0)));

        // Lamps on the header's west face, facing the player (yaw 180 turns their local +X to -X).
        const auto WestFacing = FRotator(0.0, 180.0, 0.0);
        Spawn_Mechanism(UMars_Sandbox_LampsL_EntityScript, FMars_MapBuilder_Placement("Mech4_Lamps", FVector(PartitionX - 10.0, GateY, 270.0), WestFacing));

        // A chain beside the gate on each face of the partition, grip bar at about chest height.
        Spawn_Mechanism(UMars_Sandbox_ChainL_EntityScript, FMars_MapBuilder_Placement("Mech4_ChainOutside", FVector(PartitionX - 10.0, -1650.0, 260.0), WestFacing));
        Spawn_Mechanism(UMars_Sandbox_ChainL_EntityScript, FMars_MapBuilder_Placement("Mech4_ChainInside", FVector(PartitionX + 10.0, -1150.0, 260.0)));

        // Something to run to.
        Spawn_Cube("Room4_Plinth", FVector(3700.0, GateY, 40.0), FVector(1.0, 1.0, 0.8));
    }

    // West of the main floor, entered through a doorway in its east wall. A pillar and a step break up the floor for the
    // crawlers; the target dummy and the melee items stand just inside the doorway.
    void Spawn_Room5()
    {
        Spawn_Cube(k_Room5FloorLabel, FVector(-3000.0, 0.0, -10.0), FVector(20.0, 14.0, 0.2));

        // East wall shared with the main floor, with a 300uu doorway centred on Y=0.
        Spawn_Cube("Room5_WallEast_South", FVector(-2000.0, -425.0, 150.0), FVector(0.2, 5.5, 3.0));
        Spawn_Cube("Room5_WallEast_North", FVector(-2000.0, 425.0, 150.0), FVector(0.2, 5.5, 3.0));
        Spawn_Cube("Room5_WallWest", FVector(-4000.0, 0.0, 150.0), FVector(0.2, 14.2, 3.0));
        Spawn_Cube("Room5_WallSouth", FVector(-3000.0, -700.0, 150.0), FVector(20.0, 0.2, 3.0));
        Spawn_Cube("Room5_WallNorth", FVector(-3000.0, 700.0, 150.0), FVector(20.0, 0.2, 3.0));

        Spawn_Cube("Room5_Pillar", FVector(-3300.0, 250.0, 150.0), FVector(0.6, 0.6, 3.0));
        Spawn_Cube("Room5_Step", FVector(-2700.0, -300.0, 20.0), FVector(2.0, 2.0, 0.4));

        Spawn_Mechanism(UMars_TargetDummy_EntityScript, FMars_MapBuilder_Placement("Mech5_Dummy", FVector(-2400.0, 0.0, 0.0)));

        // The melee items drop the 30uu onto the floor.
        Spawn_Mechanism(UMars_Sandbox_Cleaver_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Cleaver", FVector(-2250.0, -120.0, 30.0)));
        Spawn_Mechanism(UMars_Sandbox_Tenderizer_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Tenderizer", FVector(-2250.0, 120.0, 30.0)));

        Spawn_Room5Crawlers();
        Spawn_Room5NavField();
    }

    void Spawn_Cube(const FString& InLabel, FVector InLocation, FVector InScale)
    {
        utils_mars_map_builder::Spawn_Block(engine::load::Cube(), FMars_MapBuilder_Block(InLabel, InLocation, InScale));
    }

    // Goes through the spawner's actor factory (the Place Actors path): it instances the script class on a new
    // ACk_EntitySpawner_UE, and the spawner injects its actor transform into SpawnTransform at spawn.
    void Spawn_Mechanism(TSubclassOf<UCk_EntityScript_UE> InScriptClass, const FMars_MapBuilder_Placement& InPlacement)
    {
        auto Spawner = Cast<ACk_EntitySpawner_UE>(
            UEditorActorSubsystem::Get().SpawnActorFromObject(InScriptClass.Get(), InPlacement.Location, InPlacement.Rotation));
        if (ck::EnsureIfNot(ck::IsValid(Spawner), f"[Mars.Sandbox] Failed to place [{InPlacement.Label}] through the entity spawner factory"))
        { return; }

        Spawner.SetActorLabel(InPlacement.Label);
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
