// A backpack: lives on a Persistent world item (the pack's body) and owns its cargo slot child entities. The pack moves
// between World / Carried / Held as a world item; the cargo slots, their inventories and their visuals ride along.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_BackpackHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Backpack";
    RequiredFragments.Add(FMars_Feature_Backpack);
    Description = "A backpack on a persistent world item: the list of its cargo slot child entities";
}
struct FMars_Feature_Backpack {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Resolved by UMars_Backpack_EntityScript from the item's UMars_ItemTrait_Backpack mounts (sockets already applied).
struct FMars_Backpack_Spec
{
    UPROPERTY()
    TArray<FMars_CargoSlot_Spec> CargoSlots;
}

// 1..8 cargo slots, every ProbeRadius > 0, indices exactly 0..N-1 with none repeated.
mixin FMars_Validation Validate(const FMars_Backpack_Spec& Self)
{
    const auto Count = Self.CargoSlots.Num();
    if (Count < 1 || Count > 8)
    { return FMars_Validation(f"[{Count}] cargo slots is outside [1, 8] - Inventory.Mars.Cargo.N tags only go that far"); }

    const auto LastIndex = Count - 1;
    for (int32 Entry = 0; Entry < Count; ++Entry)
    {
        const auto& Slot = Self.CargoSlots[Entry];
        if (Slot.Index < 0 || Slot.Index > LastIndex)
        { return FMars_Validation(f"cargo slot entry [{Entry}] has index [{Slot.Index}] outside [0, {LastIndex}]"); }

        if (Slot.ProbeRadius <= 0.0f)
        { return FMars_Validation(f"cargo slot entry [{Entry}] has a non-positive ProbeRadius [{Slot.ProbeRadius}]"); }

        for (int32 Earlier = 0; Earlier < Entry; ++Earlier)
        {
            if (Self.CargoSlots[Earlier].Index == Slot.Index)
            { return FMars_Validation(f"cargo slot entry [{Entry}] repeats the index [{Slot.Index}] of entry [{Earlier}]"); }
        }
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written once by utils_backpack::Add; the slots are the pack's child entities and die with it.
struct FMars_Fragment_Backpack
{
    UPROPERTY()
    TArray<FCk_Handle_CargoSlot> CargoSlots;
}
