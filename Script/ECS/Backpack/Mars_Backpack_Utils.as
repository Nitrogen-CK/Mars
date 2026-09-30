namespace utils_backpack
{
    // Composes the backpack on a Persistent world item and creates one cargo slot child per spec entry, parented to the
    // pack root. All-or-nothing: a Transient world item or a spec that fails Validate() adds nothing.
    FCk_Handle_Backpack Add(FCk_Handle_WorldItem& InPack, FMars_Backpack_Spec InSpec)
    {
        const auto IsPersistent = InPack.Get_Persistence() == EMars_WorldItem_Persistence::Persistent;
        if (ck::EnsureIfNot(IsPersistent, f"[Backpack] [{InPack.ToString()}] is not a Persistent world item"))
        { return FCk_Handle_Backpack(); }

        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Backpack] [{InPack.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Backpack(); }

        FCk_Handle PackEntity = InPack;
        auto PackRoot = PackEntity.As_Transform();

        auto State = FMars_Fragment_Backpack();
        for (const auto& SlotSpec : InSpec.CargoSlots)
        { State.CargoSlots.Add(utils_cargo_slot::Create(PackRoot, SlotSpec, InPack)); }

        PackEntity.Add_Fragment(FMars_Feature_Backpack());
        PackEntity.Add_Fragment(State);
        return PackEntity.As_Backpack();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_WorldItem Get_WorldItem(const FCk_Handle_Backpack& Self)
{
    return FCk_Handle(Self).As_WorldItem();
}

mixin TArray<FCk_Handle_CargoSlot> Get_CargoSlots(const FCk_Handle_Backpack& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Backpack).CargoSlots;
}

mixin int32 Get_CargoSlotCount(const FCk_Handle_Backpack& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Backpack).CargoSlots.Num();
}

// Invalid when InIndex is out of range.
mixin FCk_Handle_CargoSlot Get_CargoSlot(const FCk_Handle_Backpack& Self, int32 InIndex)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Backpack);
    if (State.CargoSlots.IsValidIndex(InIndex) == false)
    { return FCk_Handle_CargoSlot(); }

    return State.CargoSlots[InIndex];
}

// Invalid when every cargo slot holds an item.
mixin FCk_Handle_CargoSlot TryGet_FirstEmptyCargoSlot(const FCk_Handle_Backpack& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Backpack);
    for (const auto& Slot : State.CargoSlots)
    {
        if (ck::IsValid(Slot) && Slot.Get_IsOccupied() == false)
        { return Slot; }
    }

    return FCk_Handle_CargoSlot();
}

mixin bool Get_IsCargoFull(const FCk_Handle_Backpack& Self)
{
    return ck::Is_NOT_Valid(Self.TryGet_FirstEmptyCargoSlot());
}
