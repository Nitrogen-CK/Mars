// Drains Dock, then Undock (each kind in queue order). Both are plain inventory transfers; the dock never writes what it
// holds here - UMars_Processor_PlatterDock_Sync reacts to what lands, like the cargo slot's sync pass.
//   Dock:   Item.Get_ParentInventory() -> this dock's inventory, refused when the dock is taken or the policy says no;
//           once the transfer succeeds, the platter's world item is asked to Carry onto the dock's node.
//   Undock: this dock's inventory -> Target; the taker's hotbar arrival then holds it (Carried -> Held).
// The Carry waits for the transfer so a refused transfer never leaves a platter mounted on an empty dock. It still drains
// before the hotbar's sync empties the hand, so the HeldItem's re-carry on deselect finds the item already headed for the
// dock and leaves it alone.
class UMars_Processor_PlatterDock_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_PlatterDock_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PlatterDock);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_PlatterDock_Requests& InRequests,
                       FMars_Fragment_PlatterDock& InState)
    {
        auto Self = InHandle.As_PlatterDock();

        TArray<FMars_Request_PlatterDock_Dock> DockRequests = InRequests.DockRequests;
        TArray<FMars_Request_PlatterDock_Undock> UndockRequests = InRequests.UndockRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_PlatterDock_Requests);

        for (const auto& Request : DockRequests)
        { HandleDockRequest(Self, InState, Request); }

        for (const auto& Request : UndockRequests)
        { HandleUndockRequest(Self, InState, Request); }
    }

    private void HandleDockRequest(FCk_Handle_PlatterDock& InDock,
                                   FMars_Fragment_PlatterDock& InState,
                                   const FMars_Request_PlatterDock_Dock& InRequest)
    {
        auto Item = InRequest.Item;
        auto Source = ck::IsValid(Item) ? Item.Get_ParentInventory() : FCk_Handle_Inventory();
        if (ck::EnsureIfNot(ck::IsValid(Source),
            f"[PlatterDock] Dock onto [{InDock.ToString()}]: item [{Item.ToString()}] is invalid or in no inventory - refused"))
        {
            Broadcast_DockRefused(InDock, Item, EMars_PlatterDock_Refusal::TransferFailed);
            return;
        }

        const auto Refusal = Get_DockRefusal(InDock, Item);
        if (Refusal.IsSet())
        {
            ck::Trace(f"[PlatterDock] [{InDock.ToString()}] refused [{Item.ToString()}]: {Refusal.GetValue() :n}");
            Broadcast_DockRefused(InDock, Item, Refusal.GetValue());
            return;
        }

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Item, InState.Inventory),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnDockTransferComplete"));
    }

    private void HandleUndockRequest(FCk_Handle_PlatterDock& InDock,
                                     FMars_Fragment_PlatterDock& InState,
                                     const FMars_Request_PlatterDock_Undock& InRequest)
    {
        const auto CanUndock = ck::IsValid(InRequest.Item) && InRequest.Item == InDock.Get_Item() && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanUndock,
            f"[PlatterDock] Undock from [{InDock.ToString()}]: item [{InRequest.Item.ToString()}] is not the docked one, or target [{InRequest.Target.ToString()}] is invalid - skipped"))
        { return; }

        auto Inventory = InState.Inventory;
        Inventory.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InRequest.Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnUndockTransferComplete"));
    }

    // NotAPlatter, Occupied, then the policy's own order (utils_platter_dock::Get_Refusal).
    private TOptional<EMars_PlatterDock_Refusal> Get_DockRefusal(const FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem) const
    {
        const auto Platter = utils_platter_dock::TryGet_PlatterOf(InItem);
        if (ck::Is_NOT_Valid(Platter))
        { return TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::NotAPlatter); }

        if (InDock.Get_IsOccupied())
        { return TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::Occupied); }

        return utils_platter_dock::Get_Refusal(InDock.Get_Spec().Policy, Platter);
    }

    // The dock is the target's owner. The Carry names the dock's point and no offset: the platter root sits on the node.
    UFUNCTION()
    private void OnDockTransferComplete(FCk_Handle_Inventory InSource,
                                        FCk_Handle_Item InItem,
                                        FCk_Handle_Inventory InTarget,
                                        int32 InCount,
                                        FCk_Handle_Item InNewItemInTarget,
                                        ECk_Inventory_OperationResult_Transfer InResult)
    {
        auto Dock = utils_entity_lifetime::Get_LifetimeOwner(InTarget).As_PlatterDock(ECk_SanityCheck::UnChecked);
        const auto Succeeded = InResult == ECk_Inventory_OperationResult_Transfer::Success;
        if (ck::EnsureIfNot(Succeeded,
            f"[PlatterDock] Docking [{InItem.ToString()}] from [{InSource.ToString()}] onto [{Dock.ToString()}] failed with [{InResult :n}]"))
        {
            if (ck::IsValid(Dock))
            { Broadcast_DockRefused(Dock, InItem, EMars_PlatterDock_Refusal::TransferFailed); }

            return;
        }

        const auto Item = ck::IsValid(InNewItemInTarget) ? InNewItemInTarget : InItem;
        auto WorldItem = Item.Get_PersistentWorldItem();
        if (ck::EnsureIfNot(ck::IsValid(Dock) && ck::IsValid(WorldItem),
            f"[PlatterDock] Docked [{Item.ToString()}] into [{InTarget.ToString()}], but the dock or the item's world item is gone"))
        { return; }

        WorldItem.Request_Carry(FMars_Request_WorldItem_Carry(Dock, GameplayTags::AttachPoint_Mars_Dock, FTransform::Identity));
        ck::Trace(f"[PlatterDock] [{Dock.ToString()}] took [{Item.ToString()}]: its world item [{WorldItem.ToString()}] carries onto the dock");
    }

    // A refused undock leaves the platter docked.
    UFUNCTION()
    private void OnUndockTransferComplete(FCk_Handle_Inventory InSource,
                                          FCk_Handle_Item InItem,
                                          FCk_Handle_Inventory InTarget,
                                          int32 InCount,
                                          FCk_Handle_Item InNewItemInTarget,
                                          ECk_Inventory_OperationResult_Transfer InResult)
    {
        ck::EnsureIfNot(InResult == ECk_Inventory_OperationResult_Transfer::Success,
            f"[PlatterDock] Undocking [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]");
    }

    private void Broadcast_DockRefused(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        if (InDock.Has_Fragment(FMars_Fragment_PlatterDock_Signals))
        { InDock.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnDockRefused.Broadcast(InDock, InItem, InRefusal); }
    }
}
