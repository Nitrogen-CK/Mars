// Editor-only: Mars.Sandbox.PlaceFlames adds the flame fixtures to room 7 of the sandbox map (/Game/Mars/Maps/Sandbox_Mars_MAP,
// room built by Mars.Sandbox.BuildRoom7): a torch on a plinth by the doorway, two unlit candles at the foot of the south
// wall whose sources light one more ceiling lamp once both burn, an unlit torch on the west wall, a torch sconce beside it
// and an unlit brazier on the floor. Open the map, run the command, and it saves the level. It refuses to run twice;
// delete the Flame7_ actors to re-place.

#if EDITOR
UFUNCTION()
void Mars_PlaceSandboxFlamesFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox_flames::Place();
}

const FConsoleCommand Mars_PlaceSandboxFlamesCommand("Mars.Sandbox.PlaceFlames", n"Mars_PlaceSandboxFlamesFunc");

namespace utils_mars_sandbox_flames
{
    const FString k_PlinthLabel = "Flame7_Plinth";

    void Place()
    {
        const FString Command = "Mars.Sandbox.PlaceFlames";
        if (utils_mars_sandbox::Get_CanAdd(Command, k_PlinthLabel, "Delete the Flame7_ actors first to re-place.") == false)
        { return; }

        // Plinth top at Z 80; the torch drops the 10 uu onto it.
        auto Plinth = utils_mars_map_builder::Spawn_Block(engine::load::Cube(),
            FMars_MapBuilder_Block(k_PlinthLabel, FVector(-1750.0, -2130.0, 40.0), FVector(1.6, 0.8, 0.8)));
        if (ck::IsValid(Plinth))
        { Plinth.StaticMeshComponent.SetMaterial(0, utils_mars_map_builder::Get_ProtoGrid_Platform()); }

        utils_mars_map_builder::Spawn_EntityScript(UMars_WorldItem_Torch_EntityScript,
            FMars_MapBuilder_Placement("Flame7_Torch", FVector(-1750.0, -2130.0, 90.0)));

        // On the floor against the south wall's inner face (Y -3290).
        utils_mars_map_builder::Spawn_EntityScript(UMars_Sandbox_Candle_EntityScript,
            FMars_MapBuilder_Placement("Flame7_Candle_0", FVector(-2200.0, -3250.0, 0.0)));
        utils_mars_map_builder::Spawn_EntityScript(UMars_Sandbox_Candle_EntityScript,
            FMars_MapBuilder_Placement("Flame7_Candle_1", FVector(-1300.0, -3250.0, 0.0)));

        // On the west wall's inner face, its bracket (local +X) reaching into the room.
        utils_mars_map_builder::Spawn_EntityScript(UMars_WallTorch_EntityScript,
            FMars_MapBuilder_Placement("Flame7_WallTorch", FVector(-2490.0, -2650.0, 170.0)));

        // The real sconce mesh further along the same wall, at the same height and facing.
        utils_mars_map_builder::Spawn_EntityScript(UMars_TorchSconce_EntityScript,
            FMars_MapBuilder_Placement("Flame7_TorchSconce", FVector(-2490.0, -2950.0, 170.0)));

        // On the floor between the plinth and the candles: a torch held to its coals lights it.
        utils_mars_map_builder::Spawn_EntityScript(UMars_Brazier_EntityScript,
            FMars_MapBuilder_Placement("Flame7_Brazier", FVector(-1750.0, -2750.0, 0.0)));

        // Hung from the roof's underside; dark until both candles burn.
        utils_mars_map_builder::Spawn_EntityScript(UMars_Sandbox_FlameLight_EntityScript,
            FMars_MapBuilder_Placement("Flame7_Light", FVector(-1750.0, -3000.0, 295.0)));

        utils_mars_map_builder::SaveOpenLevel(Command);
    }
}
#endif
