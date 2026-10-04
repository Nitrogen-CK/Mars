// Editor-only: generates the camp front-end blockout into /Game/Mars/Maps/Camp_Mars_MAP (+X = north, cauldron at the
// origin). Open File > New Level > Empty Level (or an empty Camp_Mars_MAP), then run Mars.Camp.Build. It refuses any other
// open level, and an already-built camp (an actor labelled Camp_*): delete the Camp_ actors first to rebuild.
// Mars.Camp.ApplyMaterials re-applies the ProtoGrid materials; Mars.Camp.PlaceStarts re-places the four player starts
// (e.g. after k_PlayerStartRadius changes).
//
// It must NOT create/load a level itself: swapping the editor world from inside a script call GCs the world the
// calling script context holds, and the next nested script call (Ck processor Configure during the new world's
// subsystem init) restores that dangling context -> access violation in FAngelscriptManager::AssignWorldContext.
//
// Game mode: the map picks up AMars_Camp_GameMode through the "Camp_Mars_" entry in Config/DefaultEngine.ini
// [GameMapsSettings] GameModeMapPrefixes.
//
// Kit camp (v2.2): the crypt kit's camp planner (vns_trim_sheet crypt_camp.plan_camp -> mise_mars_ue.build_camp_map
// over Monolith) replaces the blockout geometry with the Sunken Chapel and drops TargetPoints tagged Mise_Socket
// named camp_cam_<Station> / camp_start_<i>. On such a map Mars.Camp.Build places only the gameplay actors, and
// Mars.Camp.PlaceStations re-places the station cameras and the four starts from those sockets.

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

UFUNCTION()
void Mars_PlaceCampStationsFunc(const TArray<FString>& Args)
{
    utils_mars_camp::PlaceStations();
}

const FConsoleCommand Mars_PlaceCampStationsCommand("Mars.Camp.PlaceStations", n"Mars_PlaceCampStationsFunc");

enum EMars_CampStationFurniture
{
    None,
    Table
}

// One ring station: its angle on the ring (degrees from +X), the text on its label, and its furniture.
struct FMars_CampStationRow
{
    EMars_CampStation Station;
    float64 AngleDeg;
    FString Label;
    EMars_CampStationFurniture Furniture;

    FMars_CampStationRow() {}

    FMars_CampStationRow(EMars_CampStation InStation, float64 InAngleDeg, const FString& InLabel, EMars_CampStationFurniture InFurniture)
    {
        Station = InStation;
        AngleDeg = InAngleDeg;
        Label = InLabel;
        Furniture = InFurniture;
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
    const FString k_CameraLabelPrefix = "Camp_Cam_";
    const FName k_SocketTag = n"Mise_Socket";

    void Build()
    {
        const FString Command = "Mars.Camp.Build";
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::EnsureIfNot(ck::IsValid(World), f"[{Command}] No editor world"))
        { return; }

        const FString WorldPath = World.GetPathName();
        const bool IsUntitled = WorldPath.StartsWith("/Temp/");
        if (IsUntitled)
        {
            if (EditorAsset::DoesAssetExist(k_MapPath))
            {
                ck::Warning(f"[{Command}] [{k_MapPath}] already exists. Open it (empty) or delete it first to rebuild.");
                return;
            }
        }
        else
        {
            if (utils_mars_map_builder::Get_IsMap(World, k_MapPath) == false)
            {
                ck::Warning(f"[{Command}] The open level [{WorldPath}] is neither untitled nor [{k_MapPath}]. Open File > New Level > Empty Level first.");
                return;
            }

            // A kit camp: the chapel geometry is already there, only the gameplay actors are (re)placed.
            if (Get_CampSockets().Num() > 0)
            {
                const int32 Placed = Place_FromSockets();
                ck::Trace(f"[{Command}] kit camp: placed {Placed} gameplay actors from the camp sockets");
                utils_mars_map_builder::SaveOpenLevel(Command);
                return;
            }

            auto Blocker = utils_mars_map_builder::TryGet_LevelActorWithPrefix(k_LabelPrefix);
            if (utils_mars_map_builder::Get_IsUnblocked(Command, Blocker, f"Delete the {k_LabelPrefix} actors first to rebuild.") == false)
            { return; }
        }

        auto Cube = engine::load::Cube();
        auto Cylinder = engine::load::Cylinder();

        // Top face at Z=0. The fire pit and the cauldron sit on it at the origin.
        utils_mars_map_builder::Spawn_Block(Cylinder, FMars_MapBuilder_Block("Camp_Floor", FVector(0.0, 0.0, -10.0), FVector(20.0, 20.0, 0.2)));
        utils_mars_map_builder::Spawn_Block(Cylinder, FMars_MapBuilder_Block("Camp_FirePit", FVector(0.0, 0.0, 15.0), FVector(3.0, 3.0, 0.3)));
        utils_mars_map_builder::Spawn_Block(Cylinder, FMars_MapBuilder_Block("Camp_Cauldron", FVector(0.0, 0.0, 60.0), FVector(1.6, 1.6, 1.2)));

        Spawn_Walls(Cube);
        Spawn_Stations(Cube);
        Spawn_Bedrolls(Cube);

        // Camera-only stations: Title looks north from outside the entry, Cauldron from the entry side at the cauldron.
        Spawn_StationCamera(EMars_CampStation::Title, FVector(-1300.0, 0.0, 220.0), FRotator(-8.0, 0.0, 0.0));
        Spawn_StationCamera(EMars_CampStation::Cauldron, FVector(-500.0, 0.0, 200.0), FRotator(-15.0, 0.0, 0.0));

        auto Actors = UEditorActorSubsystem::Get();

        auto Sun = Actors.SpawnActorFromClass(ADirectionalLight, FVector(0.0, 0.0, 800.0), FRotator(-50.0, 35.0, 0.0));
        Sun.SetActorLabel("Sun");
        Actors.SpawnActorFromClass(ASkyLight, FVector(0.0, 0.0, 900.0)).SetActorLabel("SkyLight");
        Actors.SpawnActorFromClass(ASkyAtmosphere, FVector::ZeroVector).SetActorLabel("SkyAtmosphere");
        Spawn_FireLight();

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

        ck::Trace(f"[{Command}] cameras={CameraCount} starts={StartCount} saved={Saved}");
    }

    void ApplyMaterials()
    {
        const FString Command = "Mars.Camp.ApplyMaterials";
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(Command, k_MapPath)))
        { return; }

        Apply_ProtoGridMaterials();
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Replaces every Camp_PlayerStart_* actor. On a kit camp the starts come from the camp_start_<i> sockets
    // (PlaceStations).
    void PlaceStarts()
    {
        const FString Command = "Mars.Camp.PlaceStarts";
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(Command, k_MapPath)))
        { return; }

        if (Get_CampSockets().Num() > 0)
        {
            PlaceStations();
            return;
        }

        auto Actors = UEditorActorSubsystem::Get();
        for (auto Actor : Actors.GetAllLevelActors())
        {
            if (Actor.GetActorLabel().StartsWith(k_PlayerStartLabelPrefix))
            { Actors.DestroyActor(Actor); }
        }

        const int32 Count = Spawn_PlayerStarts();
        ck::Trace(f"[{Command}] starts={Count}");
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // Kit camp: re-places every station camera (one per EMars_CampStation) and the four starts from the Mise_Socket
    // TargetPoints the kit builder dropped, then saves the level.
    void PlaceStations()
    {
        const FString Command = "Mars.Camp.PlaceStations";
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(Command, k_MapPath)))
        { return; }

        if (Get_CampSockets().Num() == 0)
        {
            ck::Warning(f"[{Command}] No camp sockets (Mise_Socket TargetPoints) in this map: build the kit camp first.");
            return;
        }

        const int32 Placed = Place_FromSockets();
        ck::Trace(f"[{Command}] placed={Placed}");
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // The kit builder's TargetPoints: tagged Mise_Socket plus their socket name (camp_cam_<Station>, camp_start_<i>).
    TArray<ATargetPoint> Get_CampSockets()
    {
        TArray<ATargetPoint> Sockets;
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            auto Point = Cast<ATargetPoint>(Actor);
            if (ck::Is_NOT_Valid(Point) || Point.Tags.Contains(k_SocketTag) == false)
            { continue; }

            for (auto Tag : Point.Tags)
            {
                if (Tag.ToString().StartsWith("camp_"))
                {
                    Sockets.Add(Point);
                    break;
                }
            }
        }

        return Sockets;
    }

    ATargetPoint TryGet_CampSocket(const TArray<ATargetPoint>& InSockets, const FString& InName)
    {
        for (auto Point : InSockets)
        {
            if (Point.Tags.Contains(FName(InName)))
            { return Point; }
        }

        return nullptr;
    }

    // Drops the existing Camp_Cam_* and Camp_PlayerStart_* actors and spawns them again on their sockets. The sockets
    // carry the yaw; the pitch is the camp design's per-station framing. Returns how many actors were placed.
    int32 Place_FromSockets()
    {
        auto Actors = UEditorActorSubsystem::Get();
        for (auto Actor : Actors.GetAllLevelActors())
        {
            const FString Label = Actor.GetActorLabel();
            if (Label.StartsWith(k_CameraLabelPrefix) || Label.StartsWith(k_PlayerStartLabelPrefix))
            { Actors.DestroyActor(Actor); }
        }

        auto Sockets = Get_CampSockets();
        int32 Placed = 0;

        TArray<EMars_CampStation> Stations;
        Stations.Add(EMars_CampStation::Title);
        Stations.Add(EMars_CampStation::Cauldron);
        Stations.Add(EMars_CampStation::Departure);
        Stations.Add(EMars_CampStation::Backpack);
        Stations.Add(EMars_CampStation::Wardrobe);
        Stations.Add(EMars_CampStation::Guests);
        Stations.Add(EMars_CampStation::Contracts);
        Stations.Add(EMars_CampStation::Workbench);

        for (auto Station : Stations)
        {
            auto Socket = TryGet_CampSocket(Sockets, f"camp_cam_{Station :n}");
            if (ck::Is_NOT_Valid(Socket))
            {
                ck::Warning(f"[Mars.Camp] no camp_cam_{Station :n} socket in the map");
                continue;
            }

            const float64 Pitch = Station == EMars_CampStation::Title ? -8.0 : (Station == EMars_CampStation::Cauldron ? -15.0 : -12.0);
            Spawn_StationCamera(Station, Socket.GetActorLocation(), FRotator(Pitch, Socket.GetActorRotation().Yaw, 0.0));
            ++Placed;
        }

        for (int32 Index = 0; Index < 4; ++Index)
        {
            auto Socket = TryGet_CampSocket(Sockets, f"camp_start_{Index}");
            if (ck::Is_NOT_Valid(Socket))
            {
                ck::Warning(f"[Mars.Camp] no camp_start_{Index} socket in the map");
                continue;
            }

            auto Start = Actors.SpawnActorFromClass(APlayerStart, Socket.GetActorLocation(),
                FRotator(0.0, Socket.GetActorRotation().Yaw, 0.0));
            if (ck::Is_NOT_Valid(Start))
            { continue; }

            Start.SetActorLabel(f"{k_PlayerStartLabelPrefix}{Index}");
            ++Placed;
        }

        return Placed;
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
            utils_mars_map_builder::Spawn_Block(InCube, FMars_MapBuilder_Block(f"Camp_Wall_{Angle}",
                Get_RingPoint(AngleDeg, k_WallRadius, 150.0), FVector(8.0, 0.2, 3.0), FRotator(0.0, AngleDeg + 90.0, 0.0)));
        }

        const float64 GateDeg = 0.0;
        const float64 GateRad = Math::DegreesToRadians(GateDeg);
        const FVector GateCentre = Get_RingPoint(GateDeg, k_WallRadius, 150.0);
        const FVector Along = FVector(-Math::Sin(GateRad), Math::Cos(GateRad), 0.0);
        const FRotator GateRotation = FRotator(0.0, GateDeg + 90.0, 0.0);
        utils_mars_map_builder::Spawn_Block(InCube,
            FMars_MapBuilder_Block("Camp_Gate_Left", GateCentre + Along * 275.0, FVector(2.5, 0.2, 3.0), GateRotation));
        utils_mars_map_builder::Spawn_Block(InCube,
            FMars_MapBuilder_Block("Camp_Gate_Right", GateCentre - Along * 275.0, FVector(2.5, 0.2, 3.0), GateRotation));
        utils_mars_map_builder::Spawn_Block(InCube,
            FMars_MapBuilder_Block("Camp_Gate_Header", Get_RingPoint(GateDeg, k_WallRadius, 270.0), FVector(3.0, 0.2, 0.6), GateRotation));
    }

    // Per station: a table (top at Z=90) and a label at the ring radius, both facing the centre, and the station's
    // camera halfway in, looking outward at it. Props stand behind their station, facing the centre.
    void Spawn_Stations(UStaticMesh InCube)
    {
        TArray<FMars_CampStationRow> Rows;
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Departure, 0.0, "Departure Gate", EMars_CampStationFurniture::None));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Backpack, 45.0, "Expedition Backpack", EMars_CampStationFurniture::Table));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Wardrobe, 90.0, "Wardrobe", EMars_CampStationFurniture::Table));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Guests, 135.0, "Guests", EMars_CampStationFurniture::Table));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Contracts, 270.0, "Contract Board", EMars_CampStationFurniture::Table));
        Rows.Add(FMars_CampStationRow(EMars_CampStation::Workbench, 315.0, "Workbench", EMars_CampStationFurniture::Table));

        for (auto Row : Rows)
        {
            if (Row.Furniture == EMars_CampStationFurniture::Table)
            {
                utils_mars_map_builder::Spawn_Block(InCube, FMars_MapBuilder_Block(f"Camp_Table_{Row.Label}",
                    Get_RingPoint(Row.AngleDeg, k_StationRadius, 45.0), FVector(2.0, 1.0, 0.9), FRotator(0.0, Row.AngleDeg + 180.0, 0.0)));
            }

            Spawn_StationLabel(Row);
            Spawn_StationCamera(Row.Station, Get_RingPoint(Row.AngleDeg, k_CameraRadius, 170.0), FRotator(-12.0, Row.AngleDeg, 0.0));
        }

        // The mirror stands 120uu behind the wardrobe table; boards and the rack are flush against the wall's inner face.
        TArray<FMars_CampPropRow> Props;
        Props.Add(FMars_CampPropRow("Camp_Mirror", 90.0, 820.0, 110.0, FVector(0.1, 1.2, 2.2)));
        Props.Add(FMars_CampPropRow("Camp_Board_Guests", 135.0, 1030.0, 150.0, FVector(0.2, 2.0, 1.4)));
        Props.Add(FMars_CampPropRow("Camp_Board_Contracts", 270.0, 1030.0, 150.0, FVector(0.2, 2.4, 1.6)));
        Props.Add(FMars_CampPropRow("Camp_Rack", 315.0, 1030.0, 150.0, FVector(0.2, 1.6, 1.2)));

        for (auto Prop : Props)
        {
            utils_mars_map_builder::Spawn_Block(InCube, FMars_MapBuilder_Block(Prop.ActorLabel,
                Get_RingPoint(Prop.AngleDeg, Prop.Radius, Prop.Z), Prop.Scale, FRotator(0.0, Prop.AngleDeg + 180.0, 0.0)));
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

    // Four bedrolls in the south-west quarter, each with a player start toward the centre.
    void Spawn_Bedrolls(UStaticMesh InCube)
    {
        auto Angles = Get_BedrollAngles();
        for (int32 Index = 0; Index < Angles.Num(); ++Index)
        {
            const float64 AngleDeg = Angles[Index];
            utils_mars_map_builder::Spawn_Block(InCube, FMars_MapBuilder_Block(f"Camp_Bedroll_{Index}",
                Get_RingPoint(AngleDeg, k_BedrollRadius, 10.0), FVector(1.8, 0.7, 0.2), FRotator(0.0, AngleDeg + 180.0, 0.0)));
        }

        Spawn_PlayerStarts();
    }

    // One player start per bedroll, facing the centre. Returns how many were spawned.
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
            if (ck::EnsureIfNot(ck::IsValid(Start), f"[Mars.Camp] Failed to place [{k_PlayerStartLabelPrefix}{Index}]"))
            { continue; }

            Start.SetActorLabel(f"{k_PlayerStartLabelPrefix}{Index}");
            ++Count;
        }

        return Count;
    }

    void Spawn_StationCamera(EMars_CampStation InStation, FVector InLocation, FRotator InRotation)
    {
        const FString Label = f"{k_CameraLabelPrefix}{InStation :n}";
        auto Cam = Cast<AMars_CampStationCamera>(
            UEditorActorSubsystem::Get().SpawnActorFromClass(AMars_CampStationCamera, InLocation, InRotation));
        if (ck::EnsureIfNot(ck::IsValid(Cam), f"[Mars.Camp] Failed to place [{Label}]"))
        { return; }

        Cam.Station = InStation;
        Cam.SetActorLabel(Label);
    }

    // The station's name at the ring radius, facing the centre.
    void Spawn_StationLabel(const FMars_CampStationRow& InRow)
    {
        const FString Label = f"Camp_Label_{InRow.Station :n}";
        auto Actor = Cast<ATextRenderActor>(UEditorActorSubsystem::Get().SpawnActorFromClass(ATextRenderActor,
            Get_RingPoint(InRow.AngleDeg, k_StationRadius, 200.0), FRotator(0.0, InRow.AngleDeg + 180.0, 0.0)));
        if (ck::EnsureIfNot(ck::IsValid(Actor), f"[Mars.Camp] Failed to place [{Label}]"))
        { return; }

        Actor.TextRender.SetText(FText::FromString(InRow.Label));
        Actor.TextRender.SetWorldSize(40.0f);
        Actor.TextRender.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Actor.TextRender.SetTextRenderColor(FColor(255, 238, 0, 255));
        Actor.SetActorLabel(Label);
    }

    void Spawn_FireLight()
    {
        auto FireLight = Cast<APointLight>(UEditorActorSubsystem::Get().SpawnActorFromClass(APointLight, FVector(0.0, 0.0, 220.0)));
        if (ck::EnsureIfNot(ck::IsValid(FireLight), "[Mars.Camp] Failed to place [Camp_FireLight]"))
        { return; }

        FireLight.PointLightComponent.SetIntensity(8000.0f);
        FireLight.PointLightComponent.SetLightColor(FLinearColor(1.0, 0.6, 0.3));
        FireLight.SetActorLabel("Camp_FireLight");
    }

    // Matches blocks by the labels Build gives them.
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
