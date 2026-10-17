// Editor-only: one-shot placements for the Catacomb Warrens map (/Game/Mars/Maps/Warrens_Mars_MAP). Open the map, run
// the command, and it saves the level.
//
// Mars.Warrens.PlaceLantern: the expedition starts with a lantern and two tallow cakes lying beside the starting
// backpack. Every entrance has its own backpack spawner (found by name) and a run picks one entrance, so each gets its own
// set; a spawner that already has a lantern beside it is skipped, so re-running only fills the missing ones. Delete the
// Item_Warrens_Lantern* / Item_Warrens_Tallow_* actors to re-place.

#if EDITOR
UFUNCTION()
void Mars_PlaceWarrensLanternFunc(const TArray<FString>& Args)
{
    utils_mars_warrens::PlaceLantern();
}

const FConsoleCommand Mars_PlaceWarrensLanternCommand("Mars.Warrens.PlaceLantern", n"Mars_PlaceWarrensLanternFunc");

namespace utils_mars_warrens
{
    const FString k_MapPath = "/Game/Mars/Maps/Warrens_Mars_MAP";
    const FString k_LanternLabel = "Item_Warrens_Lantern";
    const FString k_TallowLabelPrefix = "Item_Warrens_Tallow_";

    // How far to the backpack's right the lantern lies, and how far above the floor under the pack it drops from.
    const float64 k_SideOffset = 90.0;
    const float64 k_DropHeight = 30.0;

    void PlaceLantern()
    {
        const FString Command = "Mars.Warrens.PlaceLantern";
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(Command, k_MapPath)))
        { return; }

        const auto Backpacks = Get_BackpackSpawners();
        if (Backpacks.Num() == 0)
        {
            ck::Trace(f"[{Command}] No backpack spawner (an entity spawner named *Backpack*) in the map; nothing placed.", NAME_None, 2.0f, FLinearColor::Yellow);
            return;
        }

        auto Placed = 0;
        for (int32 Index = 0; Index < Backpacks.Num(); ++Index)
        {
            const auto Backpack = Backpacks[Index];
            const auto Origin = Backpack.GetActorLocation();
            if (Get_HasLanternNear(Origin))
            { continue; }

            const auto Right = Backpack.GetActorRightVector();
            const auto Forward = Backpack.GetActorForwardVector();
            const auto Lift = FVector(0.0, 0.0, k_DropHeight);

            Spawn_Item(UMars_WorldItem_Lantern_EntityScript,
                FMars_MapBuilder_Placement(f"{k_LanternLabel}_{Index}", Origin + Right * k_SideOffset + Lift));
            Spawn_Item(UMars_WorldItem_Tallow_EntityScript,
                FMars_MapBuilder_Placement(f"{k_TallowLabelPrefix}{Index}_0", Origin + Right * (k_SideOffset + 40.0) + Forward * 20.0 + Lift));
            Spawn_Item(UMars_WorldItem_Tallow_EntityScript,
                FMars_MapBuilder_Placement(f"{k_TallowLabelPrefix}{Index}_1", Origin + Right * (k_SideOffset + 40.0) - Forward * 20.0 + Lift));
            ++Placed;
        }

        ck::Trace(f"[{Command}] placed a lantern and two tallow beside {Placed} of {Backpacks.Num()} backpack spawner(s)", NAME_None, 4.0f, FLinearColor::Green);
        if (Placed > 0)
        { utils_mars_map_builder::SaveOpenLevel(Command); }
    }

    // The spawner's entity script is not readable from script, so the packs are found by name: the spawner the Place
    // Actors factory made for UMars_WorldItem_Backpack_EntityScript carries the class name in its label and object name.
    TArray<ACk_EntitySpawner_UE> Get_BackpackSpawners()
    {
        auto Spawners = TArray<ACk_EntitySpawner_UE>();
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            auto Spawner = Cast<ACk_EntitySpawner_UE>(Actor);
            if (ck::Is_NOT_Valid(Spawner))
            { continue; }

            if (Spawner.GetActorLabel().Contains("Backpack") || Spawner.GetName().ToString().Contains("Backpack"))
            { Spawners.Add(Spawner); }
        }

        return Spawners;
    }

    // A placed lantern (any Item_Warrens_Lantern* actor) already lies within 300 cm of InOrigin.
    bool Get_HasLanternNear(FVector InOrigin)
    {
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (ck::IsValid(Actor) && Actor.GetActorLabel().StartsWith(k_LanternLabel)
                && (Actor.GetActorLocation() - InOrigin).Size() < 300.0)
            { return true; }
        }

        return false;
    }

    // The spawner's actor factory (the Place Actors path), as utils_mars_sandbox::Spawn_Mechanism.
    void Spawn_Item(TSubclassOf<UCk_EntityScript_UE> InScriptClass, const FMars_MapBuilder_Placement& InPlacement)
    {
        auto Spawner = Cast<ACk_EntitySpawner_UE>(
            UEditorActorSubsystem::Get().SpawnActorFromObject(InScriptClass.Get(), InPlacement.Location, InPlacement.Rotation));
        if (ck::EnsureIfNot(ck::IsValid(Spawner), f"[Mars.Warrens] Failed to place [{InPlacement.Label}] through the entity spawner factory"))
        { return; }

        Spawner.SetActorLabel(InPlacement.Label);
    }
}
#endif
