namespace utils_held_item
{
    // What is held is pushed in by the player HFSM (UMars_SmTask_HotbarDrivesHeldItem); the feature never reads the
    // hotbar itself. The hand is the player's AttachPoint.Mars.Hand, so AttachPoints must be composed first.
    FCk_Handle_HeldItem Add(FCk_Handle& InPlayer)
    {
        const auto AttachPoints = InPlayer.As_AttachPoints(ECk_SanityCheck::UnChecked);
        const auto HasHand = ck::IsValid(AttachPoints) && AttachPoints.Has_AttachPoint(GameplayTags::AttachPoint_Mars_Hand);
        if (ck::EnsureIfNot(HasHand, f"[HeldItem] [{InPlayer.ToString()}] needs AttachPoints with AttachPoint.Mars.Hand before HeldItem"))
        { return FCk_Handle_HeldItem(); }

        InPlayer.Add_Fragment(FMars_Feature_HeldItem());
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

    // The held item of whoever uses it, from a held-item use state's context: the InteractTarget, whose
    // InteractionContext names the player as the interactable owner.
    FCk_Handle_HeldItem Get_UserHeldItem(FCk_Handle InContext)
    {
        if (ck::EnsureIfNot(InContext.Has_Fragment(FMars_Fragment_InteractionContext),
            f"[HeldItem] [{InContext.ToString()}] has no interaction context"))
        { return FCk_Handle_HeldItem(); }

        auto Player = InContext.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        return Player.As_HeldItem();
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

// Invalid when the held item has no Presentation trait. For a Persistent item it is the item's own world item.
mixin FCk_Handle Get_PresentationEntity(const FCk_Handle_HeldItem& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItem).PresentationEntity;
}

mixin FCk_Handle_Transform Get_HandAttachPoint(const FCk_Handle_HeldItem& Self)
{
    return Self.As_AttachPoints().Get_AttachPoint(GameplayTags::AttachPoint_Mars_Hand);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetSlot(FCk_Handle_HeldItem& Self, const FMars_Request_HeldItem_SetSlot& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItem_Requests);
    Requests.SetSlotRequests.Add(InRequest);
}

// The next held visual spawns at InRequest.WorldTransform and keeps that offset from the hand; consumed by that spawn.
// Clear it if no spawn follows.
mixin void Request_SetNextSpawnFrom(FCk_Handle_HeldItem& Self, const FMars_Request_HeldItem_SetNextSpawnFrom& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItem_Requests);
    Requests.SetNextSpawnFromRequests.Add(InRequest);
}

// Also drops a SetNextSpawnFrom queued before it, so the clear wins whatever the drain order.
mixin void Request_ClearNextSpawnFrom(FCk_Handle_HeldItem& Self, const FMars_Request_HeldItem_ClearNextSpawnFrom& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItem_Requests);
    Requests.SetNextSpawnFromRequests.Empty();
    Requests.ClearNextSpawnFromRequests.Add(InRequest);
}

// The next held visual of InRequest.Item starts at InRequest.World and lerps in, unless it spawns later than
// constants_world_item::k_ArriveFromMaxAgeSeconds.
mixin void Request_SetNextArrival(FCk_Handle_HeldItem& Self, const FMars_Request_HeldItem_SetNextArrival& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItem_Requests);
    Requests.SetNextArrivalRequests.Add(InRequest);
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
