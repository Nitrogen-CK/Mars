// Drains Dock, then Undock (each kind in queue order). Both are plain inventory transfers; the dock never writes what it
// holds here - UMars_Processor_PlatterDock_Sync reacts to what lands, like the cargo slot's sync pass - and the platter's
// world item mounts from where its item lands (UMars_Processor_WorldItem_Reconcile), so a refused transfer moves nothing.
//   Dock:   Item.Get_ParentInventory() -> this dock's inventory, refused when the dock is taken or the policy says no.
//   Undock: this dock's inventory -> Target. A refused undock (not the docked item, no target, or the inventory refused)
//           broadcasts OnUndockRefused, so a taker waiting on OnUndocked ends.
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
        const auto IsDocked = ck::IsValid(InRequest.Item) && InRequest.Item == InDock.Get_Item();
        const auto CanUndock = IsDocked && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanUndock,
            f"[PlatterDock] Undock from [{InDock.ToString()}]: item [{InRequest.Item.ToString()}] is not the docked one, or target [{InRequest.Target.ToString()}] is invalid - refused"))
        {
            Broadcast_UndockRefused(InDock, InRequest.Item, IsDocked ? EMars_PlatterDock_Refusal::TransferFailed : EMars_PlatterDock_Refusal::NotDocked);
            return;
        }

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

        return utils_platter_dock::Get_Refusal(InDock.Get_Spec(), Platter);
    }

    // The dock is the target's owner.
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
        }
    }

    // A refused undock leaves the platter docked. The dock is the source's owner.
    UFUNCTION()
    private void OnUndockTransferComplete(FCk_Handle_Inventory InSource,
                                          FCk_Handle_Item InItem,
                                          FCk_Handle_Inventory InTarget,
                                          int32 InCount,
                                          FCk_Handle_Item InNewItemInTarget,
                                          ECk_Inventory_OperationResult_Transfer InResult)
    {
        const auto Succeeded = InResult == ECk_Inventory_OperationResult_Transfer::Success;
        if (ck::EnsureIfNot(Succeeded,
            f"[PlatterDock] Undocking [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]"))
        {
            auto Dock = utils_entity_lifetime::Get_LifetimeOwner(InSource).As_PlatterDock(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Dock))
            { Broadcast_UndockRefused(Dock, InItem, EMars_PlatterDock_Refusal::TransferFailed); }
        }
    }

    private void Broadcast_DockRefused(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        if (InDock.Has_Fragment(FMars_Fragment_PlatterDock_Signals))
        { InDock.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnDockRefused.Broadcast(InDock, InItem, InRefusal); }
    }

    private void Broadcast_UndockRefused(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        if (InDock.Has_Fragment(FMars_Fragment_PlatterDock_Signals))
        { InDock.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnUndockRefused.Broadcast(InDock, InItem, InRefusal); }
    }
}
