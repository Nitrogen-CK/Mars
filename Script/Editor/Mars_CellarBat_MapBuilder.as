// Editor-only: Mars.CellarBat.BuildReviewMap builds the cellar bat's isolated review room into the owned map
// /Game/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP and saves only that map. Run it by hand from the
// editor's console with that map open (or, the first time, an untitled empty level, which it saves as the map); it never
// loads a level itself. For automation use Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py through
// run_python instead. It deletes every actor it placed before (labels starting CellarBatReview_) and places, round
// the origin: a 2000 x 2000 floor (top at Z 0), four walls and a ceiling at Z 600 (BlockAll statics, so the Jolt
// LiveExtract static world and the flight volume's bake see them), a perch beam along X at (-600, 0) under the ceiling
// with the roost under it, a pillar between the perch and the dummy, the review target dummy at (600, 0), the flight volume
// over the room, the review bat at its hang point, a player start, and a neutral sun + sky with an amber and a teal point
// light (the Pale Crawler review rig's values). Refuses while PIE runs.

#if EDITOR
UFUNCTION()
void Mars_BuildCellarBatReviewMapFunc(const TArray<FString>& Args)
{
    utils_mars_cellar_bat_review::Build();
}

const FConsoleCommand Mars_BuildCellarBatReviewMapCommand("Mars.CellarBat.BuildReviewMap", n"Mars_BuildCellarBatReviewMapFunc");

namespace utils_mars_cellar_bat_review
{
    const FString k_Command = "Mars.CellarBat.BuildReviewMap";
    const FString k_MapPath = "/Game/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP";
    const FString k_Prefix = "CellarBatReview_";

    const float64 k_RoomHalf = 1000.0;
    const float64 k_RoomHeight = 600.0;
    const float64 k_WallThickness = 40.0;

    // AMBER / TEAL in Tools/Blender/mars_monsters/pale_crawler_r01/pale_crawler_ue.py: colour, candela, offset.
    const FLinearColor k_AmberColour = FLinearColor(1.0, 0.55, 0.2, 1.0);
    const float32 k_AmberCandela = 8000.0f;
    const FLinearColor k_TealColour = FLinearColor(0.2, 0.7, 0.8, 1.0);
    const float32 k_TealCandela = 2500.0f;
    const float32 k_SunLux = 3.0f;
    const float32 k_SkyIntensity = 0.5f;

    void Build()
    {
        if (UUnrealEditorSubsystem::Get().GetGameWorld() != nullptr)
        {
            ck::Trace(f"[{k_Command}] Stop PIE first.", NAME_None, 2.0f, FLinearColor::Yellow);
            return;
        }

        if (OpenOrCreate() == false)
        { return; }

        ClearPrevious();
        PlaceGeometry();
        PlaceEntities();
        PlaceLights();

        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        const bool Saved = ck::IsValid(World) && utils_mars_map_builder::SaveWorld(World, k_MapPath);
        ck::Trace(f"[{k_Command}] done, saved={Saved}");
    }

    // The owned map is open, or an untitled level is open and the map does not exist yet. This command never loads or
    // creates a level itself: a level load inside a console command issued through the MCP bridge hung the editor
    // (2026-11-05). Open the map (or File > New Level > Empty Level) by hand first.
    bool OpenOrCreate()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::IsValid(World) && utils_mars_map_builder::Get_IsMap(World, k_MapPath))
        { return true; }

        if (EditorAsset::DoesAssetExist(k_MapPath))
        {
            ck::Trace(f"[{k_Command}] Open [{k_MapPath}] first.", NAME_None, 2.0f, FLinearColor::Yellow);
            return false;
        }

        return ck::IsValid(utils_mars_map_builder::TryGet_UntitledWorld(k_Command, k_MapPath));
    }

    void ClearPrevious()
    {
        auto Actors = UEditorActorSubsystem::Get();
        for (auto Actor : Actors.GetAllLevelActors())
        {
            if (ck::IsValid(Actor) && Actor.GetActorLabel().StartsWith(k_Prefix))
            { Actors.DestroyActor(Actor); }
        }
    }

    AStaticMeshActor Block(const FString& InName, FVector InCentre, FVector InSize, UMaterialInstanceConstant InMaterial)
    {
        auto Actor = utils_mars_map_builder::Spawn_Block(engine::load::Cube(),
            FMars_MapBuilder_Block(k_Prefix + InName, InCentre, InSize * 0.01));
        if (ck::Is_NOT_Valid(Actor))
        { return nullptr; }

        Actor.StaticMeshComponent.SetCollisionProfileName(n"BlockAll");
        Actor.StaticMeshComponent.SetMaterial(0, InMaterial);
        return Actor;
    }

    void PlaceGeometry()
    {
        auto Floor = utils_mars_map_builder::Get_ProtoGrid_Floor();
        auto Wall = utils_mars_map_builder::Get_ProtoGrid_Wall();
        auto Platform = utils_mars_map_builder::Get_ProtoGrid_Platform();

        const auto Span = k_RoomHalf * 2.0 + k_WallThickness * 2.0;
        Block("Floor", FVector(0.0, 0.0, -10.0), FVector(Span, Span, 20.0), Floor);
        Block("Ceiling", FVector(0.0, 0.0, k_RoomHeight + 10.0), FVector(Span, Span, 20.0), Wall);

        const auto WallZ = k_RoomHeight * 0.5;
        const auto WallOffset = k_RoomHalf + k_WallThickness * 0.5;
        Block("WallNorth", FVector(0.0, WallOffset, WallZ), FVector(Span, k_WallThickness, k_RoomHeight), Wall);
        Block("WallSouth", FVector(0.0, -WallOffset, WallZ), FVector(Span, k_WallThickness, k_RoomHeight), Wall);
        Block("WallEast", FVector(WallOffset, 0.0, WallZ), FVector(k_WallThickness, Span, k_RoomHeight), Wall);
        Block("WallWest", FVector(-WallOffset, 0.0, WallZ), FVector(k_WallThickness, Span, k_RoomHeight), Wall);

        // The beam the roost hangs under: its underside at the perch anchor's Z, hung from the ceiling by a post.
        const auto Anchor = utils_bat::ReviewPerchAnchor;
        Block("PerchBeam", Anchor + FVector(0.0, 0.0, 10.0), FVector(300.0, 20.0, 20.0), Platform);
        Block("PerchPost", FVector(Anchor.X, 0.0, (Anchor.Z + 20.0 + k_RoomHeight) * 0.5), FVector(20.0, 20.0, k_RoomHeight - Anchor.Z - 20.0), Platform);

        // Between the perch and the dummy, floor to ceiling: every swoop route bends round it.
        Block("Pillar", FVector(0.0, 0.0, WallZ), FVector(120.0, 120.0, k_RoomHeight), Wall);
    }

    void PlaceEntities()
    {
        const auto Anchor = utils_bat::ReviewPerchAnchor;
        utils_mars_map_builder::Spawn_EntityScript(UMars_BatRoost_EntityScript,
            FMars_MapBuilder_Placement(k_Prefix + "Roost", Anchor));

        utils_mars_map_builder::Spawn_EntityScript(UMars_CellarBatReview_FlightVolume_EntityScript,
            FMars_MapBuilder_Placement(k_Prefix + "FlightVolume", utils_bat::ReviewVolumeCentre));

        // At the hang point (the bat spec's default HangOffset under the anchor), facing the dummy.
        utils_mars_map_builder::Spawn_EntityScript(UMars_CellarBatReview_Bat_EntityScript,
            FMars_MapBuilder_Placement(k_Prefix + "Bat", Anchor + FMars_Bat_Roost().HangOffset));

        utils_mars_map_builder::Spawn_EntityScript(UMars_CellarBatReview_TargetDummy_EntityScript,
            FMars_MapBuilder_Placement(k_Prefix + "TargetDummy", FVector(600.0, 0.0, 0.0), FRotator(0.0, 180.0, 0.0)));

        auto Start = UEditorActorSubsystem::Get().SpawnActorFromClass(APlayerStart, FVector(850.0, -820.0, 100.0), FRotator(-5.0, 150.0, 0.0));
        if (ck::IsValid(Start))
        { Start.SetActorLabel(k_Prefix + "PlayerStart"); }
    }

    void PlaceLights()
    {
        auto Actors = UEditorActorSubsystem::Get();
        auto Sun = Cast<ADirectionalLight>(Actors.SpawnActorFromClass(ADirectionalLight, FVector(0.0, 0.0, 500.0), FRotator(-45.0, -150.0, 0.0)));
        if (ck::IsValid(Sun))
        {
            Sun.SetActorLabel(k_Prefix + "NeutralSun");
            Sun.LightComponent.SetIntensity(k_SunLux);
            Sun.LightComponent.SetLightColor(FLinearColor::White);
        }

        auto Sky = Cast<ASkyLight>(Actors.SpawnActorFromClass(ASkyLight, FVector(0.0, 0.0, 300.0)));
        if (ck::IsValid(Sky))
        {
            Sky.SetActorLabel(k_Prefix + "NeutralSky");
            Sky.LightComponent.SetIntensity(k_SkyIntensity);
        }

        // Over the dummy (amber) and behind the perch (teal), the dungeon-light comparison.
        PointLight("AmberLight", FVector(600.0, 0.0, 0.0) + FVector(150.0, 0.0, 300.0), k_AmberColour, k_AmberCandela);
        PointLight("TealLight", utils_bat::ReviewPerchAnchor + FVector(-200.0, -200.0, -380.0), k_TealColour, k_TealCandela);
    }

    void PointLight(const FString& InName, FVector InLocation, FLinearColor InColour, float32 InCandela)
    {
        auto Light = Cast<APointLight>(UEditorActorSubsystem::Get().SpawnActorFromClass(APointLight, InLocation));
        if (ck::Is_NOT_Valid(Light))
        { return; }

        Light.SetActorLabel(k_Prefix + InName);
        Light.PointLightComponent.SetIntensityUnits(ELightUnits::Candelas);
        Light.PointLightComponent.SetIntensity(InCandela);
        Light.PointLightComponent.SetLightColor(InColour);
        Light.PointLightComponent.SetAttenuationRadius(1500.0f);
    }
}
#endif
