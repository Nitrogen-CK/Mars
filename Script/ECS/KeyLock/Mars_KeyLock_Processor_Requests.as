// Drains Insert, then Take (each kind in queue order). Both are plain inventory transfers; the lock never touches its
// visual or its source here - UMars_Processor_KeyLock_Sync reacts to what lands.
//   Insert: Item.Get_ParentInventory() -> this lock's inventory. Refused unless Item is the lock's key.
//   Take: this lock's inventory -> Target. Refused by a Kept lock.
// A refused request (here, or by the inventory) ensures - the caller bypassed Get_ActionFor, or raced another change to
// the lock - and broadcasts OnTransferFailed so whoever waits on the lock can stop waiting.
class UMars_Processor_KeyLock_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_KeyLock_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_KeyLock);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_KeyLock_Requests& InRequests,
                       FMars_Fragment_KeyLock& InState)
    {
        auto Self = InHandle.As_KeyLock();

        TArray<FMars_Request_KeyLock_Insert> InsertRequests = InRequests.InsertRequests;
        TArray<FMars_Request_KeyLock_Take> TakeRequests = InRequests.TakeRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_KeyLock_Requests);

        for (const auto& Request : InsertRequests)
        { HandleInsertRequest(Self, InState, Request); }

        for (const auto& Request : TakeRequests)
        { HandleTakeRequest(Self, InState, Request); }
    }

    private void HandleInsertRequest(FCk_Handle_KeyLock& InLock,
                                     FMars_Fragment_KeyLock& InState,
                                     const FMars_Request_KeyLock_Insert& InRequest)
    {
        auto Item = InRequest.Item;
        if (ck::EnsureIfNot(InLock.Get_Accepts(Item),
            f"[KeyLock] Insert into [{InLock.ToString()}]: item [{Item.ToString()}] is not its key [{InLock.Get_AcceptedKey()}] - skipped"))
        {
            Broadcast_TransferFailed(InLock, Item);
            return;
        }

        auto Source = Item.Get_ParentInventory();
        if (ck::EnsureIfNot(ck::IsValid(Source),
            f"[KeyLock] Insert into [{InLock.ToString()}]: key [{Item.ToString()}] is in no inventory - skipped"))
        {
            Broadcast_TransferFailed(InLock, Item);
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

    private void HandleTakeRequest(FCk_Handle_KeyLock& InLock,
                                     FMars_Fragment_KeyLock& InState,
                                     const FMars_Request_KeyLock_Take& InRequest)
    {
        if (ck::EnsureIfNot(InLock.Get_Release() == EMars_KeyLock_Release::Removable,
            f"[KeyLock] Take out of [{InLock.ToString()}]: the lock keeps its key - skipped"))
        {
            Broadcast_TransferFailed(InLock, InRequest.Item);
            return;
        }

        const auto CanTake = ck::IsValid(InRequest.Item) && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanTake,
            f"[KeyLock] Take out of [{InLock.ToString()}]: invalid item [{InRequest.Item.ToString()}] or target [{InRequest.Target.ToString()}] - skipped"))
        {
            Broadcast_TransferFailed(InLock, InRequest.Item);
            return;
        }

        auto Inventory = InState.Inventory;
        Inventory.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InRequest.Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));
    }

    // The lock is whichever end of the transfer a lock owns: the target of an Insert, the source of a Take.
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
            f"[KeyLock] Moving [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]");

        if (Succeeded)
        { return; }

        auto TargetLock = utils_entity_lifetime::Get_LifetimeOwner(InTarget).As_KeyLock(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(TargetLock))
        { Broadcast_TransferFailed(TargetLock, InItem); }

        auto SourceLock = utils_entity_lifetime::Get_LifetimeOwner(InSource).As_KeyLock(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(SourceLock))
        { Broadcast_TransferFailed(SourceLock, InItem); }
    }

    private void Broadcast_TransferFailed(FCk_Handle_KeyLock& InLock, const FCk_Handle_Item& InItem)
    {
        if (InLock.Has_Fragment(FMars_Fragment_KeyLock_Signals))
        { InLock.Get_Fragment(FMars_Fragment_KeyLock_Signals).OnTransferFailed.Broadcast(InLock, InItem); }
    }
}
