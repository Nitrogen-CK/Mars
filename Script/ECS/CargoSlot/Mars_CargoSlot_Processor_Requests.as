// Drains Stow, then Take (each kind in queue order). Both are plain inventory transfers; the slot never touches its
// visual here - UMars_Processor_CargoSlot_Sync reacts to what lands, like the hotbar's sync pass.
//   Stow: Item.Get_ParentInventory() -> this slot's inventory.
//   Take: this slot's inventory -> Target.
// A refused transfer (here, or by the inventory) ensures - the caller bypassed Get_ActionFor, or raced another change to
// the slot - and broadcasts OnTransferFailed so whoever waits on the slot can stop waiting.
class UMars_Processor_CargoSlot_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_CargoSlot_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CargoSlot);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_CargoSlot_Requests& InRequests,
                       FMars_Fragment_CargoSlot& InState)
    {
        auto Self = InHandle.As_CargoSlot();

        TArray<FMars_Request_CargoSlot_Stow> StowRequests = InRequests.StowRequests;
        TArray<FMars_Request_CargoSlot_Take> TakeRequests = InRequests.TakeRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_CargoSlot_Requests);

        for (const auto& Request : StowRequests)
        { HandleStowRequest(Self, InState, Request); }

        for (const auto& Request : TakeRequests)
        { HandleTakeRequest(Self, InState, Request); }
    }

    private void HandleStowRequest(FCk_Handle_CargoSlot& InSlot,
                                   FMars_Fragment_CargoSlot& InState,
                                   const FMars_Request_CargoSlot_Stow& InRequest)
    {
        auto Item = InRequest.Item;
        auto Source = ck::IsValid(Item) ? Item.Get_ParentInventory() : FCk_Handle_Inventory();
        if (ck::EnsureIfNot(ck::IsValid(Source),
            f"[CargoSlot] Stow into [{InSlot.ToString()}]: item [{Item.ToString()}] is invalid or in no inventory - skipped"))
        {
            Broadcast_TransferFailed(InSlot, Item);
            return;
        }

        if (InRequest.ArriveFrom.IsSet())
        {
            InState.PendingArrival = TOptional<FMars_WorldItem_PendingArrival>(
                FMars_WorldItem_PendingArrival(Item, InRequest.ArriveFrom.GetValue(), System::GetGameTimeInSeconds()));
        }

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Item, InState.Inventory),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));
    }

    private void HandleTakeRequest(FCk_Handle_CargoSlot& InSlot,
                                   FMars_Fragment_CargoSlot& InState,
                                   const FMars_Request_CargoSlot_Take& InRequest)
    {
        const auto CanTake = ck::IsValid(InRequest.Item) && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanTake,
            f"[CargoSlot] Take out of [{InSlot.ToString()}]: invalid item [{InRequest.Item.ToString()}] or target [{InRequest.Target.ToString()}] - skipped"))
        {
            Broadcast_TransferFailed(InSlot, InRequest.Item);
            return;
        }

        auto Inventory = InState.Inventory;
        Inventory.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InRequest.Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));
    }

    // The slot is whichever end of the transfer a cargo slot owns: the target of a Stow, the source of a Take.
    UFUNCTION()
    private void OnTransferComplete(FCk_Handle_Inventory InSource,
                                    FCk_Handle_Item InItem,
                                    FCk_Handle_Inventory InTarget,
                                    int32 InCount,
                                    FCk_Handle_Item InNewItemInTarget,
                                    ECk_Inventory_OperationResult_Transfer InResult)
    {
        const auto Succeeded = InResult == ECk_Inventory_OperationResult_Transfer::Success;
        ck::EnsureIfNot(Succeeded,
            f"[CargoSlot] Moving [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]");

        if (Succeeded)
        { return; }

        auto TargetSlot = utils_entity_lifetime::Get_LifetimeOwner(InTarget).As_CargoSlot(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(TargetSlot))
        { Broadcast_TransferFailed(TargetSlot, InItem); }

        auto SourceSlot = utils_entity_lifetime::Get_LifetimeOwner(InSource).As_CargoSlot(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(SourceSlot))
        { Broadcast_TransferFailed(SourceSlot, InItem); }
    }

    private void Broadcast_TransferFailed(FCk_Handle_CargoSlot& InSlot, const FCk_Handle_Item& InItem)
    {
        if (InSlot.Has_Fragment(FMars_Fragment_CargoSlot_Signals))
        { InSlot.Get_Fragment(FMars_Fragment_CargoSlot_Signals).OnTransferFailed.Broadcast(InSlot, InItem); }
    }
}
