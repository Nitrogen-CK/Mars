// Editor-only: one-shot placements for the Catacomb Warrens map (/Game/Mars/Maps/Warrens_Mars_MAP). Open the map, run
// the command, and it saves the level.
//
// Mars.Warrens.PlaceLantern: the expedition starts with a lantern and two tallow cakes lying beside the starting
// backpack. Every entrance has its own backpack spawner (found by name) and a run picks one entrance, so each gets its own
// set; a spawner that already has a lantern beside it is skipped, so re-running only fills the missing ones. A set's labels
// end in its pack spawner's label suffix, which stays put across rebuilds, so a top-up never reuses a surviving set's
// label. Delete the Item_Warrens_Lantern* / Item_Warrens_Tallow_* actors to re-place.

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

    // How far to the backpack's right the lantern lies, and how far above the pack spawner's origin (itself above the
    // floor) it drops from.
    const float64 k_SideOffset = 90.0;
    const float64 k_DropHeight = 30.0;

    void PlaceLantern()
    {
        const FString Command = "Mars.Warrens.PlaceLantern";
        if (ck::Is_NOT_Valid(utils_mars_map_builder::TryGet_OpenMap(Command, k_MapPath)))
        { return; }

        auto Backpacks = Get_BackpackSpawners();
        if (Backpacks.Num() == 0)
        {
            ck::Trace(f"[{Command}] No backpack spawner (an entity spawner named *Backpack*) in the map; nothing placed.", NAME_None, 2.0f, FLinearColor::Yellow);
            return;
        }

        auto Placed = 0;
        for (auto Backpack : Backpacks)
        {
            const auto Origin = Backpack.GetActorLocation();
            if (Get_HasLanternNear(Origin))
            { continue; }

            const auto Right = Backpack.GetActorRightVector();
            const auto Forward = Backpack.GetActorForwardVector();
            const auto Lift = FVector(0.0, 0.0, k_DropHeight);
            const FString Suffix = Get_PackSuffix(Backpack);

            utils_mars_map_builder::Spawn_EntityScript(UMars_WorldItem_Lantern_EntityScript,
                FMars_MapBuilder_Placement(f"{k_LanternLabel}_{Suffix}", Origin + Right * k_SideOffset + Lift));
            utils_mars_map_builder::Spawn_EntityScript(UMars_WorldItem_Tallow_EntityScript,
                FMars_MapBuilder_Placement(f"{k_TallowLabelPrefix}{Suffix}_0", Origin + Right * (k_SideOffset + 40.0) + Forward * 20.0 + Lift));
            utils_mars_map_builder::Spawn_EntityScript(UMars_WorldItem_Tallow_EntityScript,
                FMars_MapBuilder_Placement(f"{k_TallowLabelPrefix}{Suffix}_1", Origin + Right * (k_SideOffset + 40.0) - Forward * 20.0 + Lift));
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

    // The text after the pack spawner label's last underscore (the map builder labels packs Warrens_<Class>_<i>), or the
    // whole label when it has none.
    FString Get_PackSuffix(ACk_EntitySpawner_UE InBackpack)
    {
        const FString Label = InBackpack.GetActorLabel();
        FString Head;
        FString Tail;
        if (Label.Split("_", Head, Tail, ESearchCase::IgnoreCase, ESearchDir::FromEnd) && Tail.IsEmpty() == false)
        { return Tail; }

        return Label;
    }
}
#endif
