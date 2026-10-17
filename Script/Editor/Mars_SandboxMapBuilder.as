// Editor-only: generates the gameplay sandbox map into /Game/Mars/Maps/Sandbox_Mars_MAP. Open File > New Level > Empty
// Level, then run Mars.Sandbox.Build. The Mars.Sandbox.BuildRoomN / Place* / Add* / BuildGauntlets commands add one part
// to an already-built sandbox map, so a map built before that part existed can catch up without a rebuild.
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
void Mars_BuildSandboxRoom6Func(const TArray<FString>& Args)
{
    utils_mars_sandbox::BuildRoom6();
}

const FConsoleCommand Mars_BuildSandboxRoom6Command("Mars.Sandbox.BuildRoom6", n"Mars_BuildSandboxRoom6Func");

UFUNCTION()
void Mars_BuildSandboxRoom7Func(const TArray<FString>& Args)
{
    utils_mars_sandbox::BuildRoom7();
}

const FConsoleCommand Mars_BuildSandboxRoom7Command("Mars.Sandbox.BuildRoom7", n"Mars_BuildSandboxRoom7Func");

UFUNCTION()
void Mars_PlaceSandboxCrawlersFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceCrawlers();
}

const FConsoleCommand Mars_PlaceSandboxCrawlersCommand("Mars.Sandbox.PlaceCrawlers", n"Mars_PlaceSandboxCrawlersFunc");

UFUNCTION()
void Mars_AddSandboxRoom5AggressionLeverFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::AddRoom5AggressionLever();
}

const FConsoleCommand Mars_AddSandboxRoom5AggressionLeverCommand("Mars.Sandbox.AddRoom5AggressionLever", n"Mars_AddSandboxRoom5AggressionLeverFunc");

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
void Mars_PlaceSandboxFailSwitchFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceFailSwitch();
}

const FConsoleCommand Mars_PlaceSandboxFailSwitchCommand("Mars.Sandbox.PlaceFailSwitch", n"Mars_PlaceSandboxFailSwitchFunc");

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
void Mars_PlaceSandboxCuttingStationFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceCuttingStation();
}

const FConsoleCommand Mars_PlaceSandboxCuttingStationCommand("Mars.Sandbox.PlaceCuttingStation", n"Mars_PlaceSandboxCuttingStationFunc");

UFUNCTION()
void Mars_PlaceSandboxSearingStationFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceSearingStation();
}

const FConsoleCommand Mars_PlaceSandboxSearingStationCommand("Mars.Sandbox.PlaceSearingStation", n"Mars_PlaceSandboxSearingStationFunc");

UFUNCTION()
void Mars_PlaceSandboxFryStationFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceFryStation();
}

const FConsoleCommand Mars_PlaceSandboxFryStationCommand("Mars.Sandbox.PlaceFryStation", n"Mars_PlaceSandboxFryStationFunc");

UFUNCTION()
void Mars_PlaceSandboxTumblerStationFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceTumblerStation();
}

const FConsoleCommand Mars_PlaceSandboxTumblerStationCommand("Mars.Sandbox.PlaceTumblerStation", n"Mars_PlaceSandboxTumblerStationFunc");

UFUNCTION()
void Mars_PlaceSandboxBatterStationFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceBatterStation();
}

const FConsoleCommand Mars_PlaceSandboxBatterStationCommand("Mars.Sandbox.PlaceBatterStation", n"Mars_PlaceSandboxBatterStationFunc");

UFUNCTION()
void Mars_PlaceSandboxMortarStationFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlaceMortarStation();
}

const FConsoleCommand Mars_PlaceSandboxMortarStationCommand("Mars.Sandbox.PlaceMortarStation", n"Mars_PlaceSandboxMortarStationFunc");

UFUNCTION()
void Mars_PlaceSandboxPlattersFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::PlacePlatters();
}

const FConsoleCommand Mars_PlaceSandboxPlattersCommand("Mars.Sandbox.PlacePlatters", n"Mars_PlaceSandboxPlattersFunc");

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
    const FString k_Room6FloorLabel = "Room6_Floor";
    const FString k_Room7FloorLabel = "Room7_Floor";
    const FString k_Room5CrawlerLabelPrefix = "Mech5_Crawler";
    const FString k_Room5NavFieldLabel = "Mech5_NavField";
    const FString k_Room5AggressionLeverLabel = "Mech5_AggressionLever";
    const FString k_Room3BackpackPlateLabel = "Mech3_BackpackPlate";
    const FString k_ItemLabelPrefix = "Item_";
    const FString k_LadderPlatformLabel = "Sandbox_LadderPlatform";
    const FString k_WorkbenchLabel = "Sandbox_Workbench";
    const FString k_CuttingStationLabel = "Sandbox_CuttingStation";
    const FString k_SearingStationLabel = "Sandbox_SearingStation";
    const FString k_FryStationLabel = "Sandbox_FryStation";
    const FString k_TumblerStationLabel = "Sandbox_TumblerStation";
    const FString k_BatterStationLabel = "Sandbox_BatterStation";
    const FString k_MortarStationLabel = "Sandbox_MortarStation";
    const FString k_PlatterLargeLabel = "Sandbox_Platter_Large";
    const FString k_PlatterSmallLabel = "Sandbox_Platter_Small";
    const FString k_FoodMeatSlabLabel = "Sandbox_Food_MeatSlab";
    const FString k_FoodMushroomSliceLabel = "Sandbox_Food_MushroomSlice";
    const FString k_EyesDummyLabel = "EyesDummy";
    const FString k_FailSwitchLabel = "Mech_FailSwitch";
    const FString k_FailSwitchPedestalLabel = "FailSwitch_Pedestal";

    void Build()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::EnsureIfNot(ck::IsValid(World), "[Mars.Sandbox.Build] No editor world"))
        { return; }

        if (EditorAsset::DoesAssetExist(k_MapPath))
        {
            ck::Trace(f"[Mars.Sandbox.Build] [{k_MapPath}] already exists. Delete it first to rebuild.", NAME_None, 2.0f, FLinearColor::Yellow);
            return;
        }

        const FString WorldPath = World.GetPathName();
        if (WorldPath.StartsWith("/Temp/") == false)
        {
            ck::Trace(f"[Mars.Sandbox.Build] The open level [{WorldPath}] is a saved map. Open File > New Level > Empty Level first.", NAME_None, 2.0f, FLinearColor::Yellow);
            return;
        }

        // Top face at Z=0.
        Spawn_Cube("Floor", FVector(0.0, 0.0, -10.0), FVector(40.0, 40.0, 0.2));

        // Jump/fall: a 60uu step (above MaxStepHeight, below jump apex) then a 120uu platform.
        Spawn_Cube("Ledge_Step", FVector(300.0, -600.0, 30.0), FVector(2.0, 2.0, 0.6));
        Spawn_Cube("Ledge_Platform", FVector(500.0, -600.0, 60.0), FVector(4.0, 4.0, 1.2));

        // Crouch tunnel: 130uu clearance - too low standing (150, Config.Body.CapsuleHalfHeight 75), fits crouched (105).
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
        Spawn_Room6();
        Spawn_Room7();
        Spawn_Ladder();
        Spawn_Workbench();
        Spawn_CuttingStation();
        Spawn_Food();
        Spawn_SearingStation();
        Spawn_FryStation();
        Spawn_TumblerStation();
        Spawn_BatterStation();
        Spawn_MortarStation();
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

    void BuildRoom6()
    {
        const FString Command = "Mars.Sandbox.BuildRoom6";
        if (Get_CanAdd(Command, k_Room6FloorLabel, "Delete the Room6_, Mech6_ and Item_Key actors first to rebuild.") == false)
        { return; }

        Spawn_Room6();
        Apply_ProtoGridMaterials();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    void BuildRoom7()
    {
        const FString Command = "Mars.Sandbox.BuildRoom7";
        if (Get_CanAdd(Command, k_Room7FloorLabel, "Delete the Room7_, Mech7_ and Item_Room7_ actors first to rebuild.") == false)
        { return; }

        Spawn_Room7();
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

    void AddRoom5AggressionLever()
    {
        const FString Command = "Mars.Sandbox.AddRoom5AggressionLever";
        if (Get_CanAdd(Command, k_Room5AggressionLeverLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_Room5AggressionLever();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // On the west wall's room face (X = -3990) at hand height, the base's 12 uu radius touching it. The lever's handle is
    // its local +Z and a pull leans it toward local -X; Pitch 90 then Yaw 180 turns local +Z to world +X (out of the wall,
    // into the room) and local +X to world +Z, so the handle rests level and a throw swings it down.
    void Spawn_Room5AggressionLever()
    {
        Spawn_Mechanism(UMars_Sandbox_AggressionLever_EntityScript,
            FMars_MapBuilder_Placement(k_Room5AggressionLeverLabel, FVector(-3978.0, 0.0, 110.0), FRotator(90.0, 180.0, 0.0)));
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

    void PlaceCuttingStation()
    {
        const FString Command = "Mars.Sandbox.PlaceCuttingStation";
        if (Get_CanAdd(Command, k_CuttingStationLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_CuttingStation();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Beside the workbench; unrotated, it faces +X: the player walks up from -X.
    void Spawn_CuttingStation()
    {
        Spawn_Mechanism(UMars_CuttingStation_EntityScript, FMars_MapBuilder_Placement(k_CuttingStationLabel, FVector(-1200.0, -1600.0, 0.0)));
    }

    void PlaceSearingStation()
    {
        const FString Command = "Mars.Sandbox.PlaceSearingStation";
        if (Get_CanAdd(Command, k_SearingStationLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_SearingStation();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Beside the cutting station, 400 uu toward +X; unrotated, it faces +X: the player walks up from -X.
    void Spawn_SearingStation()
    {
        Spawn_Mechanism(UMars_SearingStation_EntityScript, FMars_MapBuilder_Placement(k_SearingStationLabel, FVector(-800.0, -1600.0, 0.0)));
    }

    void PlaceFryStation()
    {
        const FString Command = "Mars.Sandbox.PlaceFryStation";
        if (Get_CanAdd(Command, k_FryStationLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_FryStation();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Beside the searing station, 400 uu toward +X; unrotated, it faces +X: the player walks up from -X.
    void Spawn_FryStation()
    {
        Spawn_Mechanism(UMars_FryStation_EntityScript, FMars_MapBuilder_Placement(k_FryStationLabel, FVector(-400.0, -1600.0, 0.0)));
    }

    void PlaceTumblerStation()
    {
        const FString Command = "Mars.Sandbox.PlaceTumblerStation";
        if (Get_CanAdd(Command, k_TumblerStationLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_TumblerStation();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Beside the fry station, 400 uu toward +X; unrotated, it faces +X: the player walks up from -X.
    void Spawn_TumblerStation()
    {
        Spawn_Mechanism(UMars_TumblerStation_EntityScript, FMars_MapBuilder_Placement(k_TumblerStationLabel, FVector(0.0, -1600.0, 0.0)));
    }

    void PlaceBatterStation()
    {
        const FString Command = "Mars.Sandbox.PlaceBatterStation";
        if (Get_CanAdd(Command, k_BatterStationLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_BatterStation();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // On the fry station's other side, 400 uu toward -X, so the batter bowl, the fryer and the tumbler line up along X.
    void Spawn_BatterStation()
    {
        Spawn_Mechanism(UMars_BatterStation_EntityScript, FMars_MapBuilder_Placement(k_BatterStationLabel, FVector(-800.0, -1600.0, 0.0)));
    }

    void PlaceMortarStation()
    {
        const FString Command = "Mars.Sandbox.PlaceMortarStation";
        if (Get_CanAdd(Command, k_MortarStationLabel, "Delete it first to re-place.") == false)
        { return; }

        Spawn_MortarStation();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Beside the tumbler station, 400 uu toward +X; unrotated, it faces +X: the player walks up from -X.
    void Spawn_MortarStation()
    {
        Spawn_Mechanism(UMars_MortarStation_EntityScript, FMars_MapBuilder_Placement(k_MortarStationLabel, FVector(400.0, -1600.0, 0.0)));
    }

    void PlacePlatters()
    {
        const FString Command = "Mars.Sandbox.PlacePlatters";
        const FString Hint = f"Delete {k_PlatterLargeLabel}, {k_PlatterSmallLabel}, {k_FoodMeatSlabLabel} and {k_FoodMushroomSliceLabel} first to re-place.";
        if (Get_CanAdd(Command, k_PlatterLargeLabel, Hint) == false || Get_CanAdd(Command, k_PlatterSmallLabel, Hint) == false
            || Get_CanAdd(Command, k_FoodMeatSlabLabel, Hint) == false || Get_CanAdd(Command, k_FoodMushroomSliceLabel, Hint) == false)
        { return; }

        Spawn_Food();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // On the cutting station's player side: an empty large and an empty small platter, a little above their rest height
    // (their bodies settle), and beyond them the meat slab and a mushroom slice lying loose, as items to pick up and place
    // on a platter by hand.
    void Spawn_Food()
    {
        Spawn_Mechanism(UMars_Platter_Large_EntityScript, FMars_MapBuilder_Placement(k_PlatterLargeLabel, FVector(-1320.0, -1700.0, 75.0)));
        Spawn_Mechanism(UMars_Platter_EntityScript, FMars_MapBuilder_Placement(k_PlatterSmallLabel, FVector(-1320.0, -1500.0, 75.0)));
        Spawn_Mechanism(UMars_FoodItem_MeatSlab_EntityScript, FMars_MapBuilder_Placement(k_FoodMeatSlabLabel, FVector(-1320.0, -1900.0, 20.0)));
        Spawn_Mechanism(UMars_FoodItem_MushroomSlice_EntityScript, FMars_MapBuilder_Placement(k_FoodMushroomSliceLabel, FVector(-1320.0, -2100.0, 20.0)));
    }

    // The ladder stands at the middle of the platform's south face, yawed so its local +X points away from the platform;
    // its default 300uu height meets the platform's top.
    void Spawn_Ladder()
    {
        Spawn_Cube(k_LadderPlatformLabel, FVector(-1200.0, 1200.0, 150.0), FVector(4.0, 4.0, 3.0));
        Spawn_Mechanism(UMars_Ladder_EntityScript, FMars_MapBuilder_Placement("Sandbox_Ladder", FVector(-1200.0, 1000.0, 0.0), FRotator(0.0, -90.0, 0.0)));
    }

    // On a 100uu pedestal 2 m in front of the placed steward (it stands at (-700, -309) facing -X) and 1.3 m to its
    // left, so whoever presses it stands in front of it.
    void PlaceFailSwitch()
    {
        const FString Command = "Mars.Sandbox.PlaceFailSwitch";
        if (Get_CanAdd(Command, k_FailSwitchLabel, "Delete it and its pedestal first to re-place.") == false)
        { return; }

        const auto Spot = FVector(-900.0, -180.0, 0.0);
        Spawn_Cube(k_FailSwitchPedestalLabel, Spot + FVector(0.0, 0.0, 50.0), FVector(0.4, 0.4, 1.0));
        Spawn_Mechanism(UMars_Sandbox_FailSwitch_EntityScript, FMars_MapBuilder_Placement(k_FailSwitchLabel, Spot + FVector(0.0, 0.0, 100.0)));
        utils_mars_map_builder::SaveOpenLevel(Command);
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
        Spawn_Room5AggressionLever();
    }

    // South of the main floor, entered through a doorway in its north wall at X=1000 (clear of the station row). A hall
    // along the north wall faces a partition of four doors, each with its locks on the hall side; dividers split the vaults
    // behind them. Every lock stands 200 uu beside its own door.
    //   K1 (X -550): the red key, in the hall, opens the barred red door (latched); the yellow key lies behind it.
    //   K2 (X 150): a blue lock AND a yellow lock either side of a solid door (AllChannels, latched); a plinth behind it.
    //   K3 (X 850): two green locks and two green keys in the hall (AllSources, latched); the blue key lies behind the bars.
    //   K4 (X 1550): a removable purple lock outside and another inside; the barred door is open only while either holds
    //   the purple key (AnyChannel, not latched) and waits for its doorway to clear before closing.
    void Spawn_Room6()
    {
        Spawn_Cube(k_Room6FloorLabel, FVector(500.0, -2700.0, -10.0), FVector(28.0, 14.0, 0.2));

        Spawn_Cube("Room6_WallNorth_West", FVector(-25.0, -2000.0, 150.0), FVector(17.5, 0.2, 3.0));
        Spawn_Cube("Room6_WallNorth_East", FVector(1525.0, -2000.0, 150.0), FVector(7.5, 0.2, 3.0));
        Spawn_Cube("Room6_WallWest", FVector(-900.0, -2700.0, 150.0), FVector(0.2, 14.0, 3.0));
        Spawn_Cube("Room6_WallEast", FVector(1900.0, -2700.0, 150.0), FVector(0.2, 14.0, 3.0));
        Spawn_Cube("Room6_WallSouth", FVector(500.0, -3400.0, 150.0), FVector(28.2, 0.2, 3.0));

        // Partition around four 240uu gate frames (X -550, 150, 850, 1550); headers close the gaps to the 300uu wall top.
        // Gates are yawed 90 so their opening spans X.
        const float64 PartitionY = -2500.0;
        const auto GateRotation = FRotator(0.0, 90.0, 0.0);
        Spawn_Cube("Room6_Partition_0", FVector(-785.0, PartitionY, 150.0), FVector(2.3, 0.2, 3.0));
        Spawn_Cube("Room6_Partition_1", FVector(-200.0, PartitionY, 150.0), FVector(4.6, 0.2, 3.0));
        Spawn_Cube("Room6_Partition_2", FVector(500.0, PartitionY, 150.0), FVector(4.6, 0.2, 3.0));
        Spawn_Cube("Room6_Partition_3", FVector(1200.0, PartitionY, 150.0), FVector(4.6, 0.2, 3.0));
        Spawn_Cube("Room6_Partition_4", FVector(1785.0, PartitionY, 150.0), FVector(2.3, 0.2, 3.0));
        Spawn_Cube("Room6_GateHeader_K1", FVector(-550.0, PartitionY, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Cube("Room6_GateHeader_K2", FVector(150.0, PartitionY, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Cube("Room6_GateHeader_K3", FVector(850.0, PartitionY, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Cube("Room6_GateHeader_K4", FVector(1550.0, PartitionY, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Cube("Room6_Divider_0", FVector(-200.0, -2950.0, 150.0), FVector(0.2, 9.0, 3.0));
        Spawn_Cube("Room6_Divider_1", FVector(500.0, -2950.0, 150.0), FVector(0.2, 9.0, 3.0));
        Spawn_Cube("Room6_Divider_2", FVector(1200.0, -2950.0, 150.0), FVector(0.2, 9.0, 3.0));

        Spawn_Mechanism(UMars_Sandbox_KeyDoor_Red_EntityScript, FMars_MapBuilder_Placement("Mech6_DoorRed", FVector(-550.0, PartitionY, 0.0), GateRotation));
        Spawn_Mechanism(UMars_Sandbox_KeyDoor_BlueYellow_EntityScript, FMars_MapBuilder_Placement("Mech6_DoorBlueYellow", FVector(150.0, PartitionY, 0.0), GateRotation));
        Spawn_Mechanism(UMars_Sandbox_KeyDoor_Green_EntityScript, FMars_MapBuilder_Placement("Mech6_DoorGreen", FVector(850.0, PartitionY, 0.0), GateRotation));
        Spawn_Mechanism(UMars_Sandbox_KeyDoor_Purple_EntityScript, FMars_MapBuilder_Placement("Mech6_DoorPurple", FVector(1550.0, PartitionY, 0.0), GateRotation));

        // Locks on the partition's faces, their keyholes (local +Z) turned out of the wall: pitch -90 takes +Z to +X, then
        // yaw 90 takes it to +Y (the hall), yaw -90 to -Y (a vault).
        const auto HallFacing = FRotator(-90.0, 90.0, 0.0);
        const auto VaultFacing = FRotator(-90.0, -90.0, 0.0);
        const float64 HallFaceY = PartitionY + 10.0;
        const float64 VaultFaceY = PartitionY - 10.0;
        const float64 LockZ = 120.0;
        Spawn_Mechanism(UMars_Sandbox_KeyLock_Red_EntityScript, FMars_MapBuilder_Placement("Mech6_LockRed", FVector(-350.0, HallFaceY, LockZ), HallFacing));
        Spawn_Mechanism(UMars_Sandbox_KeyLock_Blue_EntityScript, FMars_MapBuilder_Placement("Mech6_LockBlue", FVector(-50.0, HallFaceY, LockZ), HallFacing));
        Spawn_Mechanism(UMars_Sandbox_KeyLock_Yellow_EntityScript, FMars_MapBuilder_Placement("Mech6_LockYellow", FVector(350.0, HallFaceY, LockZ), HallFacing));
        Spawn_Mechanism(UMars_Sandbox_KeyLock_Green_EntityScript, FMars_MapBuilder_Placement("Mech6_LockGreen_West", FVector(650.0, HallFaceY, LockZ), HallFacing));
        Spawn_Mechanism(UMars_Sandbox_KeyLock_Green_EntityScript, FMars_MapBuilder_Placement("Mech6_LockGreen_East", FVector(1050.0, HallFaceY, LockZ), HallFacing));
        Spawn_Mechanism(UMars_Sandbox_KeyLock_Purple_EntityScript, FMars_MapBuilder_Placement("Mech6_LockPurple_Outside", FVector(1350.0, HallFaceY, LockZ), HallFacing));
        Spawn_Mechanism(UMars_Sandbox_KeyLock_Purple_EntityScript, FMars_MapBuilder_Placement("Mech6_LockPurple_Inside", FVector(1300.0, VaultFaceY, LockZ), VaultFacing));

        // The keys drop the 30uu onto the floor. The vault keys lie 500 uu behind their bars, beyond the interaction reach.
        Spawn_Mechanism(UMars_WorldItem_Key_Red_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Key_Red", FVector(-550.0, -2250.0, 30.0)));
        Spawn_Mechanism(UMars_WorldItem_Key_Green_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Key_Green_0", FVector(750.0, -2250.0, 30.0)));
        Spawn_Mechanism(UMars_WorldItem_Key_Green_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Key_Green_1", FVector(950.0, -2250.0, 30.0)));
        Spawn_Mechanism(UMars_WorldItem_Key_Purple_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Key_Purple", FVector(1550.0, -2250.0, 30.0)));
        Spawn_Mechanism(UMars_WorldItem_Key_Yellow_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Key_Yellow", FVector(-550.0, -3000.0, 30.0)));
        Spawn_Mechanism(UMars_WorldItem_Key_Blue_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Key_Blue", FVector(850.0, -3000.0, 30.0)));

        // Something to reach behind the two-key door and the purple door.
        Spawn_Cube("Room6_Plinth_K2", FVector(150.0, -3000.0, 40.0), FVector(1.0, 1.0, 0.8));
        Spawn_Cube("Room6_Plinth_K4", FVector(1550.0, -3100.0, 40.0), FVector(1.0, 1.0, 0.8));
    }

    // The dark room, south of the main floor and west of room 6 (X -2500..-1000, Y -3300..-2000): walled and roofed, so
    // only its own lights reach in. A baffle wall inside the north doorway keeps the daylight out. Between the doorway and
    // the baffle: the light switch (toggles the four ceiling lights, which start off), two lanterns on the west plinth and
    // three tallow cakes on the east plinth. The rest of the room is dark: a tallow cake, a ration and a cog lie in it.
    void Spawn_Room7()
    {
        Spawn_Cube(k_Room7FloorLabel, FVector(-1750.0, -2650.0, -10.0), FVector(15.0, 13.0, 0.2));

        Spawn_Cube("Room7_WallWest", FVector(-2500.0, -2650.0, 150.0), FVector(0.2, 13.0, 3.0));
        Spawn_Cube("Room7_WallEast", FVector(-1000.0, -2650.0, 150.0), FVector(0.2, 13.0, 3.0));
        Spawn_Cube("Room7_WallSouth", FVector(-1750.0, -3300.0, 150.0), FVector(15.2, 0.2, 3.0));
        // A 240 uu doorway at X -1870..-1630.
        Spawn_Cube("Room7_WallNorth_West", FVector(-2185.0, -2000.0, 150.0), FVector(6.3, 0.2, 3.0));
        Spawn_Cube("Room7_WallNorth_East", FVector(-1315.0, -2000.0, 150.0), FVector(6.3, 0.2, 3.0));
        Spawn_Cube("Room7_DoorHeader", FVector(-1750.0, -2000.0, 270.0), FVector(2.4, 0.2, 0.6));
        Spawn_Cube("Room7_Baffle", FVector(-1750.0, -2250.0, 150.0), FVector(4.0, 0.2, 3.0));
        // Underside at Z 300, on the wall tops.
        Spawn_Cube("Room7_Roof", FVector(-1750.0, -2650.0, 310.0), FVector(15.2, 13.2, 0.2));

        // The switch on the north wall's inner face east of the doorway, its button (local +Z) turned to face the room
        // (-Y): pitch -90 takes +Z to +X, yaw -90 takes it to -Y.
        Spawn_Mechanism(UMars_Sandbox_LightSwitch_EntityScript,
            FMars_MapBuilder_Placement("Mech7_LightSwitch", FVector(-1560.0, -2010.0, 120.0), FRotator(-90.0, -90.0, 0.0)));

        // Hung from the roof's underside.
        Spawn_Mechanism(UMars_Sandbox_CeilingLight_EntityScript, FMars_MapBuilder_Placement("Mech7_CeilingLight_0", FVector(-2125.0, -2550.0, 300.0)));
        Spawn_Mechanism(UMars_Sandbox_CeilingLight_EntityScript, FMars_MapBuilder_Placement("Mech7_CeilingLight_1", FVector(-1375.0, -2550.0, 300.0)));
        Spawn_Mechanism(UMars_Sandbox_CeilingLight_EntityScript, FMars_MapBuilder_Placement("Mech7_CeilingLight_2", FVector(-2125.0, -3000.0, 300.0)));
        Spawn_Mechanism(UMars_Sandbox_CeilingLight_EntityScript, FMars_MapBuilder_Placement("Mech7_CeilingLight_3", FVector(-1375.0, -3000.0, 300.0)));

        // Plinth tops at Z 80; the items drop the 10 uu onto them.
        Spawn_Cube("Room7_Plinth_Lanterns", FVector(-2300.0, -2130.0, 40.0), FVector(1.6, 0.8, 0.8));
        Spawn_Cube("Room7_Plinth_Tallow", FVector(-1200.0, -2130.0, 40.0), FVector(1.6, 0.8, 0.8));
        Spawn_Mechanism(UMars_WorldItem_Lantern_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Room7_Lantern_0", FVector(-2350.0, -2130.0, 90.0)));
        Spawn_Mechanism(UMars_WorldItem_Lantern_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Room7_Lantern_1", FVector(-2250.0, -2130.0, 90.0)));
        Spawn_Mechanism(UMars_WorldItem_Tallow_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Room7_Tallow_0", FVector(-1250.0, -2130.0, 90.0)));
        Spawn_Mechanism(UMars_WorldItem_Tallow_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Room7_Tallow_1", FVector(-1200.0, -2130.0, 90.0)));
        Spawn_Mechanism(UMars_WorldItem_Tallow_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Room7_Tallow_2", FVector(-1150.0, -2130.0, 90.0)));

        // Something to find in the dark.
        Spawn_Mechanism(UMars_WorldItem_Tallow_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Room7_Tallow_Back", FVector(-2400.0, -3200.0, 30.0)));
        Spawn_Mechanism(UMars_WorldItem_Ration_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Room7_Ration", FVector(-1100.0, -3200.0, 30.0)));
        Spawn_Mechanism(UMars_WorldItem_Cog_EntityScript, FMars_MapBuilder_Placement(f"{k_ItemLabelPrefix}Room7_Cog", FVector(-1750.0, -2900.0, 30.0)));
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
            else if (Label == k_Room6FloorLabel)
            { Block.StaticMeshComponent.SetMaterial(0, Floor); }
            else if (Label.StartsWith("Room6_Plinth"))
            { Block.StaticMeshComponent.SetMaterial(0, Platform); }
            else if (Label.StartsWith("Room6_"))
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
            else if (Label == k_Room7FloorLabel)
            { Block.StaticMeshComponent.SetMaterial(0, Floor); }
            else if (Label.StartsWith("Room7_Plinth"))
            { Block.StaticMeshComponent.SetMaterial(0, Platform); }
            else if (Label.StartsWith("Room7_"))
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
            else if (Label.StartsWith(k_GauntletLabelPrefix))
            { Apply_GauntletMaterial(Block, Label); }
        }
    }
}
#endif
