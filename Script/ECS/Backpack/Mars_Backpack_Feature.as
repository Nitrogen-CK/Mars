// A backpack: lives on a Persistent world item (the pack's body) and owns its cargo slot child entities. The pack moves
// between World / Carried / Held as a world item; the cargo slots, their inventories and their visuals ride along.
//
// Stance: the pack replicates as a world item; nothing in this feature replicates itself. Each cargo slot is a replicated
// entity script of its own under the pack (UMars_CargoSlot_EntityScript), requested on every machine by
// UMars_Processor_Backpack_SpawnSlots (the authority builds it; a client's request is the placeholder it resolves to) and
// adopted into FMars_Fragment_Backpack on every machine by UMars_Processor_Backpack_AdoptSlots. The slot specs are local:
// every machine resolves them from the same definition.

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

// Resolved by UMars_Backpack_EntityScript from the item's UMars_ItemTrait_Backpack mounts (sockets already applied), the
// same on every machine.
struct FMars_Backpack_Spec
{
    UPROPERTY()
    TArray<FMars_CargoSlot_Spec> CargoSlots;
}

// 1..constants_cargo_slot::k_MaxCount cargo slots, every ProbeRadius > 0 and finite with a prompt input action, indices
// exactly 0..N-1 with none repeated.
mixin FMars_Validation Validate(const FMars_Backpack_Spec& Self)
{
    const auto Count = Self.CargoSlots.Num();
    if (Count < 1 || Count > constants_cargo_slot::k_MaxCount)
    { return FMars_Validation(f"[{Count}] cargo slots is outside [1, {constants_cargo_slot::k_MaxCount}] - Inventory.Mars.Cargo.N tags only go that far"); }

    const auto LastIndex = Count - 1;
    for (int32 Entry = 0; Entry < Count; ++Entry)
    {
        const auto& Slot = Self.CargoSlots[Entry];
        if (Slot.Index < 0 || Slot.Index > LastIndex)
        { return FMars_Validation(f"cargo slot entry [{Entry}] has index [{Slot.Index}] outside [0, {LastIndex}]"); }

        if (Math::IsFinite(Slot.ProbeRadius) == false || Slot.ProbeRadius <= 0.0f)
        { return FMars_Validation(f"cargo slot entry [{Entry}] has a non-positive ProbeRadius [{Slot.ProbeRadius}]"); }

        if (Slot.Prompt.InputAction.IsNull())
        { return FMars_Validation(f"cargo slot entry [{Entry}] has no prompt input action"); }

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

// Sized by utils_backpack::Add to the layout, one invalid entry per slot until UMars_Processor_Backpack_AdoptSlots fills
// it; the slots are the pack's child entities and die with it.
struct FMars_Fragment_Backpack
{
    UPROPERTY()
    TArray<FCk_Handle_CargoSlot> CargoSlots;
}

// Local, written once by utils_backpack::Add: each slot's spec by index, with Backpack filled in. A slot's own script
// reads its entry from its pack (utils_backpack::TryGet_SlotSpec).
struct FMars_Fragment_Backpack_SlotSpecs
{
    UPROPERTY()
    TArray<FMars_CargoSlot_Spec> Slots;
}

// Present until every slot is adopted (Get_IsReady), removed by UMars_Processor_Backpack_AdoptSlots.
struct FMars_Fragment_Backpack_AwaitingSlots
{
    UPROPERTY()
    bool Awaiting = true;
}

// Consumed by UMars_Processor_Backpack_SpawnSlots.
struct FMars_Tag_Backpack_NeedsSlots {}
