// Records the requested start poses, then commits the new held item, replaces its presentation and broadcasts
// OnHeldItemChanged. An unchanged item only records the (possibly different, empty) selected slot.
//
// A Persistent item (one whose item carries FMars_Fragment_Item_PersistentWorldItem) is never respawned: its own World-mode
// world item is asked to Hold (onto the hand) when it becomes held and to Carry (back onto its carry point) when it stops
// being held while still in the hand. That world item is a Borrowed presentation, never destroyed here.
//
// Only the LAST queued SetSlot is applied: each one is a full snapshot of the selection, and applying the earlier ones
// would spawn and destroy an intermediate visual and broadcast a held item that was never current at a drain.
class UMars_Processor_HeldItem_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_HeldItem_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HeldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_HeldItem_Requests& InRequests,
                       FMars_Fragment_HeldItem& InState)
    {
        auto Self = InHandle.As_HeldItem();

        const auto ClearNextSpawnFrom = InRequests.ClearNextSpawnFromRequests.Num() > 0;
        TArray<FMars_Request_HeldItem_SetNextSpawnFrom> SetNextSpawnFromRequests = InRequests.SetNextSpawnFromRequests;
        TArray<FMars_Request_HeldItem_SetNextArrival> SetNextArrivalRequests = InRequests.SetNextArrivalRequests;
        TArray<FMars_Request_HeldItem_SetSlot> SetSlotRequests = InRequests.SetSlotRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_HeldItem_Requests);

        if (ClearNextSpawnFrom)
        { InState.NextSpawnFrom.Reset(); }

        if (SetNextSpawnFromRequests.Num() > 0)
        { InState.NextSpawnFrom = TOptional<FTransform>(SetNextSpawnFromRequests.Last().WorldTransform); }

        if (SetNextArrivalRequests.Num() > 0)
        {
            const auto& Request = SetNextArrivalRequests.Last();
            InState.NextArrival = TOptional<FMars_WorldItem_PendingArrival>(
                FMars_WorldItem_PendingArrival(Request.Item, Request.World, System::GetGameTimeInSeconds()));
        }

        if (SetSlotRequests.Num() > 0)
        { HandleSetSlotRequest(Self, InState, SetSlotRequests.Last()); }
    }

    private void HandleSetSlotRequest(FCk_Handle_HeldItem& InHeldItem, FMars_Fragment_HeldItem& InState, const FMars_Request_HeldItem_SetSlot& InRequest)
    {
        InState.CurrentInventory = InRequest.Inventory;

        const auto PrevItem = InState.CurrentItem;
        if (InRequest.Item == PrevItem)
        { return; }

        FCk_Handle Player = InHeldItem;

        ReleasePresentation(Player, InState);
        InState.CurrentItem = InRequest.Item;

        auto NewItem = InRequest.Item;
        if (ck::IsValid(NewItem) && NewItem.Has_PersistentWorldItem())
        {
            auto NewWorldItem = NewItem.Get_PersistentWorldItem();
            const auto HasWorldItem = ck::IsValid(NewWorldItem);
            ck::EnsureIfNot(HasWorldItem, f"[HeldItem] Persistent item [{NewItem.ToString()}] has lost its world item");

            if (HasWorldItem)
            {
                NewWorldItem.Request_Hold(FMars_Request_WorldItem_Hold(Player));
                InState.PresentationEntity = NewWorldItem;
                InState.PresentationOwnership = EMars_HeldItem_PresentationOwnership::Borrowed;
            }
        }
        else if (ck::IsValid(NewItem) && NewItem.Has_Presentation())
        {
            InState.PresentationEntity = SpawnVisual(InHeldItem, InState, NewItem);
            InState.PresentationOwnership = EMars_HeldItem_PresentationOwnership::Owned;
        }

        if (InHeldItem.Has_Fragment(FMars_Fragment_HeldItem_Signals))
        { InHeldItem.Get_Fragment(FMars_Fragment_HeldItem_Signals).OnHeldItemChanged.Broadcast(InHeldItem, PrevItem, NewItem); }
    }

    // Owned: destroyed. Borrowed: a world item still in the hand goes back onto its carry point; a released one (dropped
    // or thrown) already reads World and stays where it is.
    private void ReleasePresentation(FCk_Handle& InPlayer, FMars_Fragment_HeldItem& InState)
    {
        auto Presentation = InState.PresentationEntity;
        InState.PresentationEntity = FCk_Handle();

        if (ck::Is_NOT_Valid(Presentation))
        { return; }

        if (InState.PresentationOwnership == EMars_HeldItem_PresentationOwnership::Owned)
        {
            utils_entity_lifetime::Request_DestroyEntity(Presentation);
            return;
        }

        auto WorldItem = Presentation.As_WorldItem();
        if (WorldItem.Get_TargetMount() == EMars_WorldItem_Mount::Held)
        { WorldItem.Request_Carry(FMars_Request_WorldItem_Carry(InPlayer)); }
    }

    // Two one-shot start poses, exclusive: the gloves' NextSpawnFrom (a pickup riding in; the hold offset then carries
    // that pose) wins over this item's NextArrival (taken from a cargo slot; lerps to HeldOffset). Both are consumed
    // here either way, so neither animates a later spawn.
    private FCk_Handle SpawnVisual(FCk_Handle_HeldItem& InHeldItem, FMars_Fragment_HeldItem& InState, FCk_Handle_Item& InItem)
    {
        auto Hand = InHeldItem.Get_HandAttachPoint();
        if (ck::EnsureIfNot(ck::IsValid(Hand), f"[HeldItem] [{InHeldItem.ToString()}] has no hand attach point"))
        { return FCk_Handle(); }

        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();

        auto Arrival = FMars_WorldItem_Arrival();
        if (InState.NextArrival.IsSet() && InState.NextArrival.GetValue().Item == InItem)
        {
            Arrival = utils_world_item::Get_FreshArrival(InState.NextArrival.GetValue());
            InState.NextArrival.Reset();
        }

        auto Visual = FMars_WorldItem_VisualSpec(InItem, Hand, Presentation.Mounting.HeldOffset);
        if (InState.NextSpawnFrom.IsSet())
        {
            const auto HandWorld = utils_transform::Get_EntityCurrentTransform(Hand);
            Visual.AttachOffset = InState.NextSpawnFrom.GetValue().GetRelativeTransform(HandWorld);
            InState.NextSpawnFrom.Reset();
        }
        else
        { Visual.ArriveFrom = Arrival; }

        FCk_Handle Owner = InHeldItem;
        return utils_world_item::Request_SpawnVisual(Owner, Visual);
    }
}
