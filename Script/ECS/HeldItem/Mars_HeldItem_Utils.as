namespace utils_held_item
{
    // What is held is pushed in by the player HFSM (UMars_SmTask_HotbarDrivesHeldItem); the feature never reads the
    // hotbar itself.
    FCk_Handle_HeldItem Add(FCk_Handle& InPlayer, FMars_HeldItem_Spec InSpec)
    {
        auto Params = FMars_Fragment_HeldItem_Params();
        Params.HandAttachPoint = InSpec.HandAttachPoint;

        InPlayer.Add_Fragment(FMars_Feature_HeldItem());
        InPlayer.Add_Fragment(Params);
        InPlayer.Add_Fragment(FMars_Fragment_HeldItem());
        return InPlayer.As_HeldItem();
    }

    // Item definitions are const through FCk_Handle_Item; the soft reference is built from the object's path.
    TSoftObjectPtr<UCk_InventoryItem_Definition> Make_DefinitionSoft(const UCk_InventoryItem_Definition InDefinition)
    {
        if (ck::Is_NOT_Valid(InDefinition))
        { return TSoftObjectPtr<UCk_InventoryItem_Definition>(); }

        return TSoftObjectPtr<UCk_InventoryItem_Definition>(FSoftObjectPath(InDefinition));
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// Invalid while hands are empty.
mixin FCk_Handle_Item Get_CurrentItem(const FCk_Handle_HeldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItem).CurrentItem;
}

// The selected slot; valid even when it is empty.
mixin FCk_Handle_Inventory_DataOnly Get_CurrentInventory(const FCk_Handle_HeldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItem).CurrentInventory;
}

// Invalid when the held item has no Presentation trait.
mixin FCk_Handle Get_PresentationEntity(const FCk_Handle_HeldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItem).PresentationEntity;
}

mixin FCk_Handle_Transform Get_HandAttachPoint(const FCk_Handle_HeldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItem_Params).HandAttachPoint;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// The next held visual spawns at InWorldTransform (consumed by that spawn). Clear it if no spawn follows.
mixin void Set_NextSpawnFrom(FCk_Handle_HeldItem& Self, const FTransform& InWorldTransform)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_HeldItem_SpawnFrom);
    Fragment.WorldTransform = InWorldTransform;
}

mixin void Clear_NextSpawnFrom(FCk_Handle_HeldItem& Self)
{
    Self.Request_TryRemove(FMars_Fragment_HeldItem_SpawnFrom);
}

mixin void Request_SetSlot(FCk_Handle_HeldItem& Self, const FMars_Request_HeldItem_SetSlot& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItem_Requests);
    Requests.SetSlotRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHeldItemChanged(FCk_Handle_HeldItem& Self, FMars_Delegate_HeldItem_OnHeldItemChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_HeldItem_Signals);
    Fragment.OnHeldItemChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHeldItemChanged(FCk_Handle_HeldItem& Self, FMars_Delegate_HeldItem_OnHeldItemChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_HeldItem_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_HeldItem_Signals).OnHeldItemChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
