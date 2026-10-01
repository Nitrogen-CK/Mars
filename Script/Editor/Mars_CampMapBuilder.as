// Editor-only: generates the camp front-end blockout into /Game/Mars/Maps/Camp_Mars_MAP (geometry: design
// docs/design/mars-camp-frontend.md section 6; +X = north, cauldron at the origin).
//   1. File > New Level > Empty Level (or open an empty /Game/Mars/Maps/Camp_Mars_MAP created by Monolith)
//   2. Console: Mars.Camp.Build
// It populates the open level (floor disc, octagon wall with the north departure gate and the south entry left open,
// fire pit + cauldron, six ring stations with a table, a text label and their props, four bedrolls with a player start
// each, one AMars_CampStationCamera per EMars_CampStation, lights) and saves it to the map path. It refuses any other
// open level, and an already-built camp (an actor labelled Camp_*): delete the Camp_ actors first to rebuild.
//
// Surfaces use the shared CkUsf ProtoGrid MaterialInstanceConstants (utils_mars_map_builder). To (re)apply them to an
// existing camp map, open it and run: Mars.Camp.ApplyMaterials
// To re-place the four player starts on an existing camp map (e.g. after k_PlayerStartRadius changes), open it and
// run: Mars.Camp.PlaceStarts
//
// It must NOT create/load a level itself: swapping the editor world from inside a script call GCs the world the
// calling script context holds, and the next nested script call (Ck processor Configure during the new world's
// subsystem init) restores that dangling context -> access violation in FAngelscriptManager::AssignWorldContext.
//
// Game mode: the map picks up AMars_Camp_GameMode through the "Camp_Mars_" entry in Config/DefaultEngine.ini
// [GameMapsSettings] GameModeMapPrefixes.

#if EDITOR
UFUNCTION()
void Mars_BuildCampFunc(const TArray<FString>& Args)
{
    utils_mars_camp::Build();
}

const FConsoleCommand Mars_BuildCampCommand("Mars.Camp.Build", n"Mars_BuildCampFunc");

UFUNCTION()
void Mars_ApplyCampMaterialsFunc(const TArray<FString>& Args)
{
    utils_mars_camp::ApplyMaterials();
}

const FConsoleCommand Mars_ApplyCampMaterialsCommand("Mars.Camp.ApplyMaterials", n"Mars_ApplyCampMaterialsFunc");

UFUNCTION()
void Mars_PlaceCampStartsFunc(const TArray<FString>& Args)
{
    utils_mars_camp::PlaceStarts();
}

const FConsoleCommand Mars_PlaceCampStartsCommand("Mars.Camp.PlaceStarts", n"Mars_PlaceCampStartsFunc");

// One ring station: its angle on the ring (degrees from +X), the text on its label, and whether it gets a table.
struct FMars_CampStationRow
{
    EMars_CampStation Station;
    float64 AngleDeg;
    FString Label;      // text on the ATextRenderActor
    bool HasTable;

    FMars_CampStationRow() {}

    FMars_CampStationRow(EMars_CampStation InStation, float64 InAngleDeg, const FString& InLabel, bool InHasTable)
    {
        Station = InStation;
        AngleDeg = InAngleDeg;
        Label = InLabel;
        HasTable = InHasTable;
    }
}

// One station prop block (mirror, board, rack) on its station's angle, facing the centre.
struct FMars_CampPropRow
{
    FString ActorLabel;
    float64 AngleDeg;
    float64 Radius;
    float64 Z;
    FVector Scale;

    FMars_CampPropRow() {}

    FMars_CampPropRow(const FString& InActorLabel, float64 InAngleDeg, float64 InRadius, float64 InZ, FVector InScale)
    {
        ActorLabel = InActorLabel;
        AngleDeg = InAngleDeg;
        Radius = InRadius;
        Z = InZ;
        Scale = InScale;
    }
}

namespace utils_mars_camp
{
    const FString k_MapPath = "/Game/Mars/Maps/Camp_Mars_MAP";
    const FString k_LabelPrefix = "Camp_";

    const float64 k_StationRadius = 700.0;
    const float64 k_CameraRadius = 350.0;
    const float64 k_WallRadius = 1050.0;
    const float64 k_BedrollRadius = 850.0;
    // The chef capsule (radius 34) at 650 spans 616-684, clear of the bedroll block (760-940); at 750 it overlapped
    // the bedroll and the spawn was refused.
    const float64 k_PlayerStartRadius = 650.0;
    const FString k_PlayerStartLabelPrefix = "Camp_PlayerStart_";

    void Build()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::EnsureIfNot(ck::IsValid(World), "[Mars.Camp.Build] No editor world"))
        { return; }

        const FString WorldPath = World.GetPathName();
        const bool IsUntitled = WorldPath.StartsWith("/Temp/");
        if (IsUntitled)
        {
            if (EditorAsset::DoesAssetExist(k_MapPath))
            {
                ck::Warning(f"[Mars.Camp.Build] [{k_MapPath}] already exists. Open it (empty) or delete it first to rebuild.");
                return;
            }
        }
        else
        {
            if (Get_IsCampMap(World) == false)
            {
                ck::Warning(f"[Mars.Camp.Build] The open level [{WorldPath}] is neither untitled nor [{k_MapPath}]. Open File > New Level > Empty Level first.");
                return;
            }

            for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
            {
                if (Actor.GetActorLabel().StartsWith(k_LabelPrefix))
                {
                    ck::Warning(f"[Mars.Camp.Build] [{Actor.GetActorLabel()}] already exists. Delete the {k_LabelPrefix} actors first to rebuild.");
                    return;
                }
            }
        }

        auto Cube = engine::load::Cube();
        auto Cylinder = engine::load::Cylinder();

        // Floor: 10m radius disc, top face at Z=0. The fire pit and the cauldron sit on it at the origin.
        utils_mars_map_builder::Spawn_Block(Cylinder, "Camp_Floor", FVector(0.0, 0.0, -10.0), FVector(20.0, 20.0, 0.2));
        utils_mars_map_builder::Spawn_Block(Cylinder, "Camp_FirePit", FVector(0.0, 0.0, 15.0), FVector(3.0, 3.0, 0.3));
        utils_mars_map_builder::Spawn_Block(Cylinder, "Camp_Cauldron", FVector(0.0, 0.0, 60.0), FVector(1.6, 1.6, 1.2));

        Spawn_Walls(Cube);
        Spawn_Stations(Cube);
        Spawn_Bedrolls(Cube);

        // Camera-only stations: Title looks north from outside the entry, Cauldron from the entry side at the cauldron.
        Spawn_StationCamera(EMars_CampStation::Title, FVector(-1300.0, 0.0, 220.0), FRotator(-8.0, 0.0, 0.0), "Camp_Cam_Title");
        Spawn_StationCamera(EMars_CampStation::Cauldron, FVector(-500.0, 0.0, 200.0), FRotator(-15.0, 0.0, 0.0), "Camp_Cam_Cauldron");

        auto Actors = UEditorActorSubsystem::Get();

        auto Sun = Actors.SpawnActorFromClass(ADirectionalLight, FVector(0.0, 0.0, 800.0), FRotator(-50.0, 35.0, 0.0));
        Sun.SetActorLabel("Sun");
        Actors.SpawnActorFromClass(ASkyLight, FVector(0.0, 0.0, 900.0)).SetActorLabel("SkyLight");
        Actors.SpawnActorFromClass(ASkyAtmosphere, FVector::ZeroVector).SetActorLabel("SkyAtmosphere");

        auto FireLight = Cast<APointLight>(Actors.SpawnActorFromClass(APointLight, FVector(0.0, 0.0, 220.0)));
        if (ck::IsValid(FireLight))
        {
            FireLight.PointLightComponent.SetIntensity(8000.0f);
            FireLight.PointLightComponent.SetLightColor(FLinearColor(1.0, 0.6, 0.3));
            FireLight.SetActorLabel("Camp_FireLight");
        }

        Apply_ProtoGridMaterials();

        int32 CameraCount = 0;
        int32 StartCount = 0;
        for (auto Actor : Actors.GetAllLevelActors())
        {
            if (ck::IsValid(Cast<AMars_CampStationCamera>(Actor)))
            { ++CameraCount; }
            else if (ck::IsValid(Cast<APlayerStart>(Actor)))
            { ++StartCount; }
        }

        bool Saved = false;
        if (IsUntitled)
        { Saved = UEditorLoadingAndSavingUtils::SaveMap(World, k_MapPath); }
        else
        { Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel(); }

        ck::Trace(f"[Mars.Camp.Build] cameras={CameraCount} starts={StartCount} saved={Saved}");
    }

    void ApplyMaterials()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || Get_IsCampMap(World) == false)
        {
            ck::Warning(f"[Mars.Camp.ApplyMaterials] Open [{k_MapPath}] first.");
            return;
        }

        Apply_ProtoGridMaterials();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Camp.ApplyMaterials] applied, saved={Saved}");
    }

    // Destroys every Camp_PlayerStart_* actor in the open camp map, re-spawns the four starts and saves the level.
    void PlaceStarts()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || Get_IsCampMap(World) == false)
        {
            ck::Warning(f"[Mars.Camp.PlaceStarts] Open [{k_MapPath}] first.");
            return;
        }

        auto Actors = UEditorActorSubsystem::Get();
        for (auto Actor : Actors.GetAllLevelActors())
        {
            if (Actor.GetActorLabel().StartsWith(k_PlayerStartLabelPrefix))
            { Actors.DestroyActor(Actor); }
        }

        const int32 Count = Spawn_PlayerStarts();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Camp.PlaceStarts] starts={Count} saved={Saved}");
    }

    bool Get_IsCampMap(UWorld InWorld)
    {
        return InWorld.GetPathName().StartsWith(f"{k_MapPath}.");
    }

    // A point on a ring around the cauldron; the angle is in degrees from +X (north) toward +Y.
    FVector Get_RingPoint(float64 InAngleDeg, float64 InRadius, float64 InZ)
    {
        const float64 Rad = Math::DegreesToRadians(InAngleDeg);
        return FVector(InRadius * Math::Cos(Rad), InRadius * Math::Sin(Rad), InZ);
    }

    // Octagon of 300uu-tall segments at the station angles. 180 (south) is the open entry; 0 (north) is the departure
    // gate: two flanking walls 275uu either side of the segment centre and a header across the 300uu opening.
    void Spawn_Walls(UStaticMesh InCube)
    {
        for (int32 Index = 1; Index < 8; ++Index)
        {
            if (Index == 4)
            { continue; }

            const int32 Angle = 45 * Index;
            const float64 AngleDeg = float64(Angle);
            utils_mars_map_builder::Spawn_Block(InCube, f"Camp_Wall_{Angle}", Get_RingPoint(AngleDeg, k_WallRadius, 150.0),
                FVector(8.0, 0.2, 3.0), FRotator(0.0, AngleDeg + 90.0, 0.0));
        }

        const float64 GateDeg = 0.0;
        const float64 GateRad = Math::DegreesToRadians(GateDeg);
        const FVector GateCentre = Get_RingPoint(GateDeg, k_WallRadius, 150.0);
        const FVector Along = FVector(-Math::Sin(GateRad), Math::Cos(GateRad), 0.0);
        const FRotator GateRotation = FRotator(0.0, GateDeg + 90.0, 0.0);
        utils_mars_map_builder::Spawn_Block(InCube, "Camp_Gate_Left", GateCentre + Along * 275.0, FVector(2.5, 0.2, 3.0), GateRotation);
        utils_mars_map_builder::Spawn_Block(InCube, "Camp_Gate_Right", GateCentre - Along * 275.0, FVector(2.5, 0.2, 3.0), GateRotation);
        utils_mars_map_builder::Spawn_Block(InCube, "Camp_Gate_Header", Get_RingPoint(GateDeg, k_WallRadius, 270.0),
            FVector(3.0, 0.2, 0.6), GateRotation);
    }

    // Per station: a table (top at Z=90) and a label at the ring radius, both facing the centre, and the station's
    // camera halfway in, looking outward at it. Props stand behind their station, facing the centre.
    void Spawn_Stations(UStaticMesh InCube)
    {
        TArray<FMars_CampStationRow> Rows;
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Departure, 0.0, "Departure Gate", false));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Backpack, 45.0, "Expedition Backpack", true));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Wardrobe, 90.0, "Wardrobe", true));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Guests, 135.0, "Guests", true));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Contracts, 270.0, "Contract Board", true));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Workbench, 315.0, "Workbench", true));

        for (auto Row : Rows)
        {
            const FRotator FacingCentre = FRotator(0.0, Row.AngleDeg + 180.0, 0.0);
            if (Row.HasTable)
            {
                utils_mars_map_builder::Spawn_Block(InCube, f"Camp_Table_{Row.Label}", Get_RingPoint(Row.AngleDeg, k_StationRadius, 45.0),
                    FVector(2.0, 1.0, 0.9), FacingCentre);
            }

            Spawn_Label(Row.Label, Get_RingPoint(Row.AngleDeg, k_StationRadius, 200.0), FacingCentre, f"Camp_Label_{Row.Station :n}");
            Spawn_StationCamera(Row.Station, Get_RingPoint(Row.AngleDeg, k_CameraRadius, 170.0), FRotator(-12.0, Row.AngleDeg, 0.0),
                f"Camp_Cam_{Row.Station :n}");
        }

        // The mirror stands 120uu behind the wardrobe table; boards and the rack are flush against the wall's inner face.
        TArray<FMars_CampPropRow> Props;
        Props.Add(FMars_CampPropRow("Camp_Mirror", 90.0, 820.0, 110.0, FVector(0.1, 1.2, 2.2)));
        Props.Add(FMars_CampPropRow("Camp_Board_Guests", 135.0, 1030.0, 150.0, FVector(0.2, 2.0, 1.4)));
        Props.Add(FMars_CampPropRow("Camp_Board_Contracts", 270.0, 1030.0, 150.0, FVector(0.2, 2.4, 1.6)));
        Props.Add(FMars_CampPropRow("Camp_Rack", 315.0, 1030.0, 150.0, FVector(0.2, 1.6, 1.2)));

        for (auto Prop : Props)
        {
            utils_mars_map_builder::Spawn_Block(InCube, Prop.ActorLabel, Get_RingPoint(Prop.AngleDeg, Prop.Radius, Prop.Z), Prop.Scale,
                FRotator(0.0, Prop.AngleDeg + 180.0, 0.0));
        }
    }

    TArray<float64> Get_BedrollAngles()
    {
        TArray<float64> Angles;
        Angles.Add(200.0);
        Angles.Add(215.0);
        Angles.Add(245.0);
        Angles.Add(260.0);
        return Angles;
    }

    // Four bedrolls in the south-west quarter, each with a player start toward the centre (Spawn_PlayerStarts).
    void Spawn_Bedrolls(UStaticMesh InCube)
    {
        auto Angles = Get_BedrollAngles();
        for (int32 Index = 0; Index < Angles.Num(); ++Index)
        {
            const float64 AngleDeg = Angles[Index];
            const FRotator FacingCentre = FRotator(0.0, AngleDeg + 180.0, 0.0);
            utils_mars_map_builder::Spawn_Block(InCube, f"Camp_Bedroll_{Index}", Get_RingPoint(AngleDeg, k_BedrollRadius, 10.0),
                FVector(1.8, 0.7, 0.2), FacingCentre);
        }

        Spawn_PlayerStarts();
    }

    // One player start per bedroll at k_PlayerStartRadius, facing the centre. Returns how many were spawned.
    int32 Spawn_PlayerStarts()
    {
        auto Angles = Get_BedrollAngles();
        auto Actors = UEditorActorSubsystem::Get();
        int32 Count = 0;
        for (int32 Index = 0; Index < Angles.Num(); ++Index)
        {
            const float64 AngleDeg = Angles[Index];
            const FRotator FacingCentre = FRotator(0.0, AngleDeg + 180.0, 0.0);
            auto Start = Actors.SpawnActorFromClass(APlayerStart, Get_RingPoint(AngleDeg, k_PlayerStartRadius, 100.0), FacingCentre);
            if (ck::Is_NOT_Valid(Start))
            { continue; }

            Start.SetActorLabel(f"{k_PlayerStartLabelPrefix}{Index}");
            ++Count;
        }

        return Count;
    }

    void Spawn_StationCamera(EMars_CampStation InStation, FVector InLocation, FRotator InRotation, const FString& InLabel)
    {
        auto Cam = Cast<AMars_CampStationCamera>(
            UEditorActorSubsystem::Get().SpawnActorFromClass(AMars_CampStationCamera, InLocation, InRotation));
        if (ck::EnsureIfNot(ck::IsValid(Cam), f"[Mars.Camp.Build] Failed to place [{InLabel}]"))
        { return; }

        Cam.Station = InStation;
        Cam.SetActorLabel(InLabel);
    }

    void Spawn_Label(const FString& InText, FVector InLocation, FRotator InRotation, const FString& InLabel)
    {
        auto Actor = Cast<ATextRenderActor>(UEditorActorSubsystem::Get().SpawnActorFromClass(ATextRenderActor, InLocation, InRotation));
        if (ck::EnsureIfNot(ck::IsValid(Actor), f"[Mars.Camp.Build] Failed to place [{InLabel}]"))
        { return; }

        Actor.TextRender.SetText(FText::FromString(InText));
        Actor.TextRender.SetWorldSize(40.0f);
        Actor.TextRender.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Actor.TextRender.SetTextRenderColor(FColor(255, 238, 0, 255));
        Actor.SetActorLabel(InLabel);
    }

    // Matches blocks by the labels Build gives them (design section 6).
    void Apply_ProtoGridMaterials()
    {
        auto Floor = utils_mars_map_builder::Get_ProtoGrid_Floor();
        auto Wall = utils_mars_map_builder::Get_ProtoGrid_Wall();
        auto Platform = utils_mars_map_builder::Get_ProtoGrid_Platform();
        auto Interactable = utils_mars_map_builder::Get_ProtoGrid_Interactable();

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            auto Block = Cast<AStaticMeshActor>(Actor);
            if (ck::Is_NOT_Valid(Block))
            { continue; }

            const FString Label = Block.GetActorLabel();
            if (Label == "Camp_Floor")
            { Block.StaticMeshComponent.SetMaterial(0, Floor); }
            else if (Label.StartsWith("Camp_Wall_") || Label.StartsWith("Camp_Gate_") || Label == "Camp_FirePit"
                  || Label.StartsWith("Camp_Board_") || Label == "Camp_Mirror" || Label == "Camp_Rack")
            { Block.StaticMeshComponent.SetMaterial(0, Wall); }
            else if (Label.StartsWith("Camp_Table_") || Label.StartsWith("Camp_Bedroll_"))
            { Block.StaticMeshComponent.SetMaterial(0, Platform); }
            else if (Label == "Camp_Cauldron")
            { Block.StaticMeshComponent.SetMaterial(0, Interactable); }
        }
    }
}
#endif
