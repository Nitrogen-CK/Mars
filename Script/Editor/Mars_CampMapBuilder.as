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
// Kit camp: a kit-built camp replaces the blockout geometry and drops TargetPoints tagged Mise_Socket: camp_cam_<Station>,
// camp_board_<Station> (the front end's menu boards), camp_anchor_<Station> (world board anchors) and camp_start_<i>. On
// such a map Mars.Camp.Build places only the gameplay actors, and Mars.Camp.PlaceStations moves the station view points,
// menu board stations and board anchors already in the map onto those sockets (spawning any that are missing) and
// re-places the four starts.

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

// One world board anchor: its station, transform, scale and widget draw size.
struct FMars_CampBoardAnchorPlacement
{
    EMars_CampStation Station;
    FVector Location;
    FRotator Rotation;
    float32 Scale = 1.0f;
    FIntPoint DrawSize;

    FMars_CampBoardAnchorPlacement() {}

    FMars_CampBoardAnchorPlacement(EMars_CampStation InStation, FVector InLocation, FRotator InRotation, float32 InScale, FIntPoint InDrawSize)
    {
        Station = InStation;
        Location = InLocation;
        Rotation = InRotation;
        Scale = InScale;
        DrawSize = InDrawSize;
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

        // An untitled level, or the camp map itself open (empty, or a kit camp).
        if (utils_mars_map_builder::Get_IsUntitled(World))
        {
            if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_UntitledWorld(Command, k_MapPath)))
            { return; }
        }
        else
        {
            if (utils_mars_map_builder::Get_IsMap(World, k_MapPath) == false)
            {
                ck::Trace(f"[{Command}] The open level [{World.GetPathName()}] is neither untitled nor [{k_MapPath}]. Open File > New Level > Empty Level first.", NAME_None, 2.0f, FLinearColor::Yellow);
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
        auto Floor = FMars_MapBuilder_Block("Camp_Floor", FVector(0.0, 0.0, -10.0), FVector(20.0, 20.0, 0.2));
        Floor.PhysMat = utils_mars_map_builder::Get_PhysMat("Dirt");
        utils_mars_map_builder::Spawn_Block(Cylinder, Floor);
        utils_mars_map_builder::Spawn_Block(Cylinder, FMars_MapBuilder_Block("Camp_FirePit", FVector(0.0, 0.0, 15.0), FVector(3.0, 3.0, 0.3)));
        auto Cauldron = FMars_MapBuilder_Block("Camp_Cauldron", FVector(0.0, 0.0, 60.0), FVector(1.6, 1.6, 1.2));
        Cauldron.PhysMat = utils_mars_map_builder::Get_PhysMat("Metal");
        utils_mars_map_builder::Spawn_Block(Cylinder, Cauldron);

        Spawn_Walls(Cube);
        Spawn_Stations(Cube);
        Spawn_Bedrolls(Cube);

        // Title and menu share the entrance-side camera, with the board left of the hearth.
        Spawn_StationCamera(EMars_CampStation::Title, FVector(-1130.0, 0.0, 165.0), FRotator::ZeroRotator);
        Spawn_StationCamera(EMars_CampStation::Cauldron, FVector(-500.0, 0.0, 200.0), FRotator(-15.0, 0.0, 0.0));
        Spawn_BoardAnchor(FMars_CampBoardAnchorPlacement(EMars_CampStation::Title, FVector(-650.0, -175.0, 165.0),
            FRotator(0.0, 160.0, 0.0), 0.33f, FIntPoint(700, 900)));
        Spawn_MenuStand();
        Spawn_BoardAnchor(FMars_CampBoardAnchorPlacement(EMars_CampStation::Contracts, FVector(0.0, -895.0, 175.0),
            FRotator(0.0, 90.0, 0.0), 0.27f, FIntPoint(1000, 1000)));
        Spawn_BoardAnchor(FMars_CampBoardAnchorPlacement(EMars_CampStation::Departure, FVector(870.0, 210.0, 155.0),
            FRotator(0.0, 180.0, 0.0), 0.28f, FIntPoint(700, 650)));

        utils_mars_map_builder::Spawn_DaylightRig();
        Spawn_FireLight();

        Apply_ProtoGridMaterials();

        int32 CameraCount = 0;
        int32 StartCount = 0;
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (ck::IsValid(Cast<AMars_CampStationCamera>(Actor)))
            { ++CameraCount; }
            else if (ck::IsValid(Cast<APlayerStart>(Actor)))
            { ++StartCount; }
        }

        const bool Saved = utils_mars_map_builder::SaveWorld(World, k_MapPath);
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
            ck::Trace(f"[{Command}] No camp sockets (Mise_Socket TargetPoints) in this map: build the kit camp first.", NAME_None, 2.0f, FLinearColor::Yellow);
            return;
        }

        const int32 Placed = Place_FromSockets();
        ck::Trace(f"[{Command}] placed={Placed}");
        utils_mars_map_builder::SaveOpenLevel(Command);
    }

    // The kit builder's TargetPoints: tagged Mise_Socket plus their socket name (camp_<kind>_<Station>, camp_start_<i>).
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

    // Kit camp: moves every enabled station view point (plain cameras and the front end's menu board stations) and
    // every board anchor onto its kit socket, keeping the actor and whatever was authored on it, spawns the ones the
    // map lacks and re-places the four starts (only the builder's own Camp_PlayerStart_<i>, each once its socket is found). Sockets: camp_cam_<Station> (a camera; the pitch is the per-station
    // framing), camp_board_<Station> (a menu board: the board centre, +X out of its face), camp_anchor_<Station> (a
    // world board anchor), camp_start_<i>. Returns how many actors were placed or moved.
    int32 Place_FromSockets()
    {
        auto Actors = UEditorActorSubsystem::Get();
        auto Sockets = Get_CampSockets();

        TArray<AMars_CampStationCamera> Cameras;
        TArray<AMars_CampBoardAnchor> Anchors;
        for (auto Actor : Actors.GetAllLevelActors())
        {
            auto Camera = Cast<AMars_CampStationCamera>(Actor);
            auto Anchor = Cast<AMars_CampBoardAnchor>(Actor);
            if (ck::IsValid(Camera))
            { Cameras.Add(Camera); }
            else if (ck::IsValid(Anchor))
            { Anchors.Add(Anchor); }
        }

        TArray<EMars_CampStation> Stations;
        Stations.Add(EMars_CampStation::Title);
        Stations.Add(EMars_CampStation::Cauldron);
        Stations.Add(EMars_CampStation::Departure);
        Stations.Add(EMars_CampStation::Backpack);
        Stations.Add(EMars_CampStation::Wardrobe);
        Stations.Add(EMars_CampStation::Guests);
        Stations.Add(EMars_CampStation::Contracts);
        Stations.Add(EMars_CampStation::Workbench);
        Stations.Add(EMars_CampStation::FrontendHost);
        Stations.Add(EMars_CampStation::FrontendJoin);
        Stations.Add(EMars_CampStation::FrontendSettings);
        Stations.Add(EMars_CampStation::FrontendQuit);

        int32 Placed = 0;
        for (auto Station : Stations)
        {
            auto Existing = TryGet_EnabledCamera(Cameras, Station);
            auto BoardSocket = TryGet_CampSocket(Sockets, f"camp_board_{Station :n}");
            auto CameraSocket = TryGet_CampSocket(Sockets, f"camp_cam_{Station :n}");
            if (ck::IsValid(BoardSocket))
            {
                Place_MenuBoard(Station, Existing, BoardSocket);
                ++Placed;
            }
            else if (ck::IsValid(CameraSocket))
            {
                // A placed camera keeps the pitch authored on it; a new one gets the blockout's framing.
                const float64 DefaultPitch = Station == EMars_CampStation::Cauldron ? -15.0 : -12.0;
                const float64 Pitch = ck::IsValid(Existing) ? Existing.GetActorRotation().Pitch : DefaultPitch;
                const auto Rotation = FRotator(Pitch, CameraSocket.GetActorRotation().Yaw, 0.0);
                if (ck::IsValid(Existing))
                {
                    Existing.SetActorLocation(CameraSocket.GetActorLocation());
                    Existing.SetActorRotation(Rotation);
                }
                else
                { Spawn_StationCamera(Station, CameraSocket.GetActorLocation(), Rotation); }
                ++Placed;
            }
            else if (ck::IsValid(Existing))
            { ck::Trace(f"[Mars.Camp] no kit socket for station [{Station :n}]: its view point stays where it is", NAME_None, 2.0f, FLinearColor::Yellow); }
        }

        Placed += Place_BoardAnchors(Anchors, Sockets);

        for (int32 Index = 0; Index < 4; ++Index)
        {
            const FString StartLabel = f"{k_PlayerStartLabelPrefix}{Index}";
            auto Socket = TryGet_CampSocket(Sockets, f"camp_start_{Index}");
            if (ck::Is_NOT_Valid(Socket))
            {
                ck::Trace(f"[Mars.Camp] no camp_start_{Index} socket in the map: [{StartLabel}] stays where it is", NAME_None, 2.0f, FLinearColor::Yellow);
                continue;
            }

            for (auto Actor : Actors.GetAllLevelActors())
            {
                if (Actor.GetActorLabel() == StartLabel)
                { Actors.DestroyActor(Actor); }
            }

            auto Start = Actors.SpawnActorFromClass(APlayerStart, Socket.GetActorLocation(),
                FRotator(0.0, Socket.GetActorRotation().Yaw, 0.0));
            if (ck::EnsureIfNot(ck::IsValid(Start), f"[Mars.Camp] Failed to place [{StartLabel}]"))
            { continue; }

            Start.SetActorLabel(StartLabel);
            ++Placed;
        }

        return Placed;
    }

    // The enabled view point for a station; disabled ones are authoring backups and stay untouched.
    AMars_CampStationCamera TryGet_EnabledCamera(const TArray<AMars_CampStationCamera>& InCameras, EMars_CampStation InStation)
    {
        for (auto Camera : InCameras)
        {
            if (Camera.Station == InStation && Camera.bStationEnabled)
            { return Camera; }
        }

        return nullptr;
    }

    // A menu board station on its kit socket, the kit's frame and stand standing in for the blockout blocks. A plain
    // camera that held the station before is kept as a disabled backup beside the new board.
    void Place_MenuBoard(EMars_CampStation InStation, AMars_CampStationCamera InExisting, ATargetPoint InSocket)
    {
        const auto Rotation = FRotator(0.0, InSocket.GetActorRotation().Yaw, 0.0);
        auto Board = Cast<AMars_MenuBoardStation>(InExisting);
        if (ck::Is_NOT_Valid(Board))
        {
            if (ck::IsValid(InExisting))
            { InExisting.bStationEnabled = false; }

            Board = Cast<AMars_MenuBoardStation>(UEditorActorSubsystem::Get().SpawnActorFromClass(
                AMars_MenuBoardStation, InSocket.GetActorLocation(), Rotation));
            if (ck::EnsureIfNot(ck::IsValid(Board), f"[Mars.Camp] Failed to place the [{InStation :n}] menu board"))
            { return; }

            Board.Station = InStation;
            Board.SetActorLabel(f"Camp_Board_{InStation :n}");
        }

        Board.SetActorLocation(InSocket.GetActorLocation());
        Board.SetActorRotation(Rotation);
        Board.bShowBlockout = false;
        Board.RefreshAssembly();
    }

    // Every board anchor with a camp_anchor_<Station> socket moves onto it (its scale and draw size are the board's
    // authored size and stay); the Contracts and Departure anchors the camp controller requires are spawned at the
    // blockout's sizes when the map has none. Returns how many were placed or moved.
    int32 Place_BoardAnchors(const TArray<AMars_CampBoardAnchor>& InAnchors, const TArray<ATargetPoint>& InSockets)
    {
        int32 Placed = 0;
        bool HasContracts = false;
        bool HasDeparture = false;
        for (auto Anchor : InAnchors)
        {
            HasContracts = HasContracts || Anchor.Station == EMars_CampStation::Contracts;
            HasDeparture = HasDeparture || Anchor.Station == EMars_CampStation::Departure;
            auto Socket = TryGet_CampSocket(InSockets, f"camp_anchor_{Anchor.Station :n}");
            if (ck::Is_NOT_Valid(Socket))
            {
                ck::Trace(f"[Mars.Camp] no camp_anchor_{Anchor.Station :n} socket: that board anchor stays where it is", NAME_None, 2.0f, FLinearColor::Yellow);
                continue;
            }

            Anchor.SetActorLocation(Socket.GetActorLocation());
            Anchor.SetActorRotation(FRotator(0.0, Socket.GetActorRotation().Yaw, 0.0));
            ++Placed;
        }

        auto Contracts = TryGet_CampSocket(InSockets, "camp_anchor_Contracts");
        if (HasContracts == false && ck::IsValid(Contracts))
        {
            Spawn_BoardAnchor(FMars_CampBoardAnchorPlacement(EMars_CampStation::Contracts, Contracts.GetActorLocation(),
                FRotator(0.0, Contracts.GetActorRotation().Yaw, 0.0), 0.27f, FIntPoint(1000, 1000)));
            ++Placed;
        }

        auto Departure = TryGet_CampSocket(InSockets, "camp_anchor_Departure");
        if (HasDeparture == false && ck::IsValid(Departure))
        {
            Spawn_BoardAnchor(FMars_CampBoardAnchorPlacement(EMars_CampStation::Departure, Departure.GetActorLocation(),
                FRotator(0.0, Departure.GetActorRotation().Yaw, 0.0), 0.28f, FIntPoint(700, 650)));
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
                auto Table = FMars_MapBuilder_Block(f"Camp_Table_{Row.Label}",
                    Get_RingPoint(Row.AngleDeg, k_StationRadius, 45.0), FVector(2.0, 1.0, 0.9), FRotator(0.0, Row.AngleDeg + 180.0, 0.0));
                Table.PhysMat = utils_mars_map_builder::Get_PhysMat("Wood");
                utils_mars_map_builder::Spawn_Block(InCube, Table);
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
            auto Block = FMars_MapBuilder_Block(Prop.ActorLabel,
                Get_RingPoint(Prop.AngleDeg, Prop.Radius, Prop.Z), Prop.Scale, FRotator(0.0, Prop.AngleDeg + 180.0, 0.0));
            Block.PhysMat = utils_mars_map_builder::Get_PhysMat("Wood");
            utils_mars_map_builder::Spawn_Block(InCube, Block);
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
            auto Bedroll = FMars_MapBuilder_Block(f"Camp_Bedroll_{Index}",
                Get_RingPoint(AngleDeg, k_BedrollRadius, 10.0), FVector(1.8, 0.7, 0.2), FRotator(0.0, AngleDeg + 180.0, 0.0));
            Bedroll.PhysMat = utils_mars_map_builder::Get_PhysMat("Carpet");
            utils_mars_map_builder::Spawn_Block(InCube, Bedroll);
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
        if (InStation == EMars_CampStation::Title)
        { UCameraComponent::Get(Cam).SetFieldOfView(70.0f); }
        Cam.SetActorLabel(Label);
    }

    // Dressing around the Title board anchor; parts are authored around the anchor centre and rotated with it.
    void Spawn_MenuStand()
    {
        auto Material = System::LoadAsset_Blocking(TSoftObjectPtr<UMaterialInterface>(FSoftObjectPath(
            "/Game/Mars/Environment/Materials/Camp/CampMenuFrame_Mars_MI.CampMenuFrame_Mars_MI")));
        TArray<FMars_MapBuilder_Block> Parts;
        Parts.Add(FMars_MapBuilder_Block("Camp_MenuStand_Backing", FVector(-641, -175, 165), FVector(0.08, 2.40, 3.06)));
        Parts.Add(FMars_MapBuilder_Block("Camp_MenuStand_LeftPost", FVector(-650, -299, 168), FVector(0.14, 0.12, 3.32)));
        Parts.Add(FMars_MapBuilder_Block("Camp_MenuStand_RightPost", FVector(-650, -51, 168), FVector(0.14, 0.12, 3.32)));
        Parts.Add(FMars_MapBuilder_Block("Camp_MenuStand_Top", FVector(-650, -175, 323), FVector(0.14, 2.60, 0.12)));
        Parts.Add(FMars_MapBuilder_Block("Camp_MenuStand_Bottom", FVector(-650, -175, 12), FVector(0.14, 2.60, 0.12)));
        Parts.Add(FMars_MapBuilder_Block("Camp_MenuStand_LeftFoot", FVector(-628, -299, 6), FVector(0.70, 0.20, 0.12)));
        Parts.Add(FMars_MapBuilder_Block("Camp_MenuStand_RightFoot", FVector(-628, -51, 6), FVector(0.70, 0.20, 0.12)));
        for (auto Part : Parts)
        {
            auto Block = utils_mars_map_builder::Spawn_Block(engine::load::Cube(), Part);
            if (ck::Is_NOT_Valid(Block))
            { continue; }
            const auto Center = FVector(-650, -175, 165);
            const auto Angle = FRotator(0.0, -20.0, 0.0);
            Block.SetActorLocation(Center + Angle.RotateVector(Part.Location - Center));
            Block.SetActorRotation(Angle);
            Block.StaticMeshComponent.SetCollisionEnabled(ECollisionEnabled::NoCollision);
            if (ck::IsValid(Material))
            { Block.StaticMeshComponent.SetMaterial(0, Material); }
        }
        auto Fill = Cast<APointLight>(UEditorActorSubsystem::Get().SpawnActorFromClass(
            APointLight, FVector(-850, -250, 290)));
        if (ck::IsValid(Fill))
        {
            Fill.SetActorLabel("Camp_MenuStandFill");
            Fill.PointLightComponent.SetIntensity(12.0f);
            Fill.PointLightComponent.SetAttenuationRadius(520.0f);
            Fill.PointLightComponent.SetLightColor(FLinearColor(1.0, 0.74, 0.47));
            Fill.PointLightComponent.SourceRadius = 70.0f;
        }
    }

    void Spawn_BoardAnchor(const FMars_CampBoardAnchorPlacement& InPlacement)
    {
        const FString Label = f"Camp_BoardAnchor_{InPlacement.Station :n}";
        auto Anchor = Cast<AMars_CampBoardAnchor>(
            UEditorActorSubsystem::Get().SpawnActorFromClass(AMars_CampBoardAnchor, InPlacement.Location, InPlacement.Rotation));
        if (ck::EnsureIfNot(ck::IsValid(Anchor), f"[Mars.Camp] Failed to place [{Label}]"))
        { return; }

        Anchor.Station = InPlacement.Station;
        Anchor.DrawSize = InPlacement.DrawSize;
        Anchor.SetActorScale3D(FVector(InPlacement.Scale));
        Anchor.SetActorLabel(Label);
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
        const auto Grid = utils_mars_map_builder::Load_ProtoGridSet();

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            auto Block = Cast<AStaticMeshActor>(Actor);
            if (ck::Is_NOT_Valid(Block))
            { continue; }

            const FString Label = Block.GetActorLabel();
            if (Label == "Camp_Floor")
            { Block.StaticMeshComponent.SetMaterial(0, Grid.Floor); }
            else if (Label.StartsWith("Camp_Wall_") || Label.StartsWith("Camp_Gate_") || Label == "Camp_FirePit"
                  || Label.StartsWith("Camp_Board_") || Label == "Camp_Mirror" || Label == "Camp_Rack")
            { Block.StaticMeshComponent.SetMaterial(0, Grid.Wall); }
            else if (Label.StartsWith("Camp_Table_") || Label.StartsWith("Camp_Bedroll_"))
            { Block.StaticMeshComponent.SetMaterial(0, Grid.Platform); }
            else if (Label == "Camp_Cauldron")
            { Block.StaticMeshComponent.SetMaterial(0, Grid.Interactable); }
        }
    }
}
#endif
