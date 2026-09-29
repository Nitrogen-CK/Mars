namespace utils_world_item
{
    // The entity script composes the holder, body, pickup and visual first and hands their handles in here.
    FCk_Handle_WorldItem Add(FCk_Handle& InHandle, FMars_Fragment_WorldItem_Params InParams, FMars_Fragment_WorldItem InState)
    {
        InHandle.Add_Fragment(FMars_Feature_WorldItem());
        InHandle.Add_Fragment(InParams);
        InHandle.Add_Fragment(InState);
        return InHandle.As_WorldItem();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_WorldItem_Mode Get_Mode(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem_Params).Mode;
}

// Null when the soft reference does not resolve.
mixin UCk_InventoryItem_Definition Get_Definition(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem_Params).Definition.Get();
}

// Invalid in HeldVisual mode.
mixin FCk_Handle_Inventory_DataOnly Get_Holder(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Holder;
}

// Invalid in HeldVisual mode, and while the holder is empty.
mixin FCk_Handle_Item Get_HeldItem(const FCk_Handle_WorldItem& Self)
{
    auto Holder = Self.Get_Holder();
    if (ck::Is_NOT_Valid(Holder) || Holder.Get_NumItems() == 0)
    { return FCk_Handle_Item(); }

    auto Items = Holder.Get_Items();
    return Items[0];
}

// Invalid in HeldVisual mode.
mixin FCk_Handle_Interactable Get_Pickup(const FCk_Handle_WorldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_WorldItem).Pickup;
}
