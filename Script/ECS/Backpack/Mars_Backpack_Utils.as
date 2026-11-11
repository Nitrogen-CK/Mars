namespace utils_backpack
{
    // Composes the backpack on a Persistent world item: its slot specs (each with Backpack filled in) and the layout its
    // slots are adopted into, and asks for one slot script per spec entry (UMars_Processor_Backpack_SpawnSlots); the pack
    // is ready once every slot is adopted. All-or-nothing: a Transient world item or a spec that fails Validate() adds
    // nothing. Runs on every machine.
    FCk_Handle_Backpack Add(FCk_Handle_WorldItem& InPack, FMars_Backpack_Spec InSpec)
    {
        const auto IsPersistent = InPack.Get_Persistence() == EMars_WorldItem_Persistence::Persistent;
        if (ck::EnsureIfNot(IsPersistent, f"[Backpack] [{InPack.ToString()}] is not a Persistent world item"))
        { return FCk_Handle_Backpack(); }

        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Backpack] [{InPack.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Backpack(); }

        FCk_Handle PackEntity = InPack;

        auto State = FMars_Fragment_Backpack();
        auto Specs = FMars_Fragment_Backpack_SlotSpecs();
        for (int32 Index = 0; Index < InSpec.CargoSlots.Num(); ++Index)
        {
            State.CargoSlots.Add(FCk_Handle_CargoSlot());
            Specs.Slots.Add(FMars_CargoSlot_Spec());
        }

        // Validate() guarantees the indices are exactly 0..N-1.
        for (const auto& Entry : InSpec.CargoSlots)
        {
            auto SlotSpec = Entry;
            SlotSpec.Backpack = InPack;
            Specs.Slots[Entry.Index] = SlotSpec;
        }

        PackEntity.Add_Fragment(FMars_Feature_Backpack());
        PackEntity.Add_Fragment(State);
        PackEntity.Add_Fragment(Specs);
        PackEntity.Add_Fragment(FMars_Fragment_Backpack_AwaitingSlots());
        PackEntity.Add_Fragment(FMars_Tag_Backpack_NeedsSlots());
        return PackEntity.As_Backpack();
    }

    // The pack's reach claim on one of its interactables: while the pack is Held (in its carrier's hands) nobody can reach
    // its cargo or its hook; every other mount releases the claim.
    void Request_ApplyHolderHeld(FCk_Handle_Interactable& InInteractable, EMars_WorldItem_Mount InPackMount)
    {
        if (ck::Is_NOT_Valid(InInteractable))
        { return; }

        if (InPackMount == EMars_WorldItem_Mount::Held)
        { InInteractable.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::HolderHeld)); }
        else
        { InInteractable.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::HolderHeld)); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// One entry per slot of the layout; an entry is invalid until that slot is adopted (Get_IsReady).
mixin TArray<FCk_Handle_CargoSlot> Get_CargoSlots(const FCk_Handle_Backpack& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Backpack).CargoSlots;
}

// The layout's slot count, adopted or not.
mixin int32 Get_CargoSlotCount(const FCk_Handle_Backpack& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Backpack).CargoSlots.Num();
}

// Invalid when InIndex is out of range, and until that slot is adopted.
mixin FCk_Handle_CargoSlot Get_CargoSlot(const FCk_Handle_Backpack& Self, int32 InIndex)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Backpack);
    if (State.CargoSlots.IsValidIndex(InIndex) == false)
    { return FCk_Handle_CargoSlot(); }

    return State.CargoSlots[InIndex];
}

// Every slot is adopted: until then Get_CargoSlot is invalid for the slots not yet found.
mixin bool Get_IsReady(const FCk_Handle_Backpack& Self)
{
    return Self.Has_Fragment(FMars_Fragment_Backpack_AwaitingSlots) == false;
}

// The spec of the slot at InIndex; unset when the layout has no such slot.
mixin TOptional<FMars_CargoSlot_Spec> TryGet_SlotSpec(const FCk_Handle_Backpack& Self, int32 InIndex)
{
    const auto& Specs = Self.Get_Fragment(FMars_Fragment_Backpack_SlotSpecs);
    if (Specs.Slots.IsValidIndex(InIndex) == false)
    { return TOptional<FMars_CargoSlot_Spec>(); }

    return TOptional<FMars_CargoSlot_Spec>(Specs.Slots[InIndex]);
}

// The pack's lantern hook, found among its lifetime dependents; invalid when the pack has none, or it has not composed
// here yet.
mixin FCk_Handle_LanternHook TryGet_LanternHook(const FCk_Handle_Backpack& Self)
{
    for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(Self))
    {
        auto Hook = Dependent.As_LanternHook(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Hook))
        { return Hook; }
    }

    return FCk_Handle_LanternHook();
}
