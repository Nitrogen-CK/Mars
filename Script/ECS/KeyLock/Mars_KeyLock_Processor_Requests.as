// Drains ExpectArrival (latest per item wins), then Insert, Take and Act (each kind in queue order). ExpectArrival is
// presentation and applies on every machine; Insert, Take and Act move a key, so a machine without authority drops them
// (its transfers would be refused, and the move replicates from the authority). Insert and Take are plain inventory
// transfers; the lock never touches its visual or its source here - UMars_Processor_KeyLock_Sync reacts to what lands.
//   Insert: Item.Get_ParentInventory() -> this lock's inventory. Refused unless Item is the lock's key.
//   Take: this lock's inventory -> Target. Refused by a Kept lock.
//   Act: Get_ActionFor(Initiator) is asked again here. Unless it is still the action the request names, the Act is refused
//        (ActionBlocked): two machines racing for one lock is legitimate, so it does not ensure. Otherwise it runs as the
//        Insert of the initiator's held key, or the Take of the lock's key into the initiator's hotbar take target.
// A refused Insert or Take (here, or by the inventory) ensures - the caller bypassed Get_ActionFor, or raced another
// change to the lock - and broadcasts OnTransferFailed so whoever waits on the lock can stop waiting. A refused Act, or an
// Act whose transfer the inventory refuses (TransferRefused), advances FMars_Fragment_KeyLock_Net naming the initiator.
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

        TArray<FMars_Request_KeyLock_ExpectArrival> ExpectArrivalRequests = InRequests.ExpectArrivalRequests;
        TArray<FMars_Request_KeyLock_Insert> InsertRequests = InRequests.InsertRequests;
        TArray<FMars_Request_KeyLock_Take> TakeRequests = InRequests.TakeRequests;
        TArray<FMars_Request_KeyLock_Act> ActRequests = InRequests.ActRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_KeyLock_Requests);

        for (const auto& Request : ExpectArrivalRequests)
        {
            InState.PendingArrival = TOptional<FMars_WorldItem_PendingArrival>(
                FMars_WorldItem_PendingArrival(Request.Item, Request.From, System::GetGameTimeInSeconds()));
        }

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : InsertRequests)
        { HandleInsertRequest(Self, InState, Request); }

        for (const auto& Request : TakeRequests)
        { HandleTakeRequest(Self, InState, Request); }

        for (const auto& Request : ActRequests)
        { HandleActRequest(Self, InState, Request); }
    }

    // True when the transfer was requested; false when the request was refused before it.
    private bool HandleInsertRequest(FCk_Handle_KeyLock& InLock,
                                     FMars_Fragment_KeyLock& InState,
                                     const FMars_Request_KeyLock_Insert& InRequest)
    {
        auto Item = InRequest.Item;
        if (ck::EnsureIfNot(InLock.Get_Accepts(Item),
            f"[KeyLock] Insert into [{InLock.ToString()}]: item [{Item.ToString()}] is not its key [{InLock.Get_AcceptedKey()}] - skipped"))
        {
            Broadcast_TransferFailed(InLock, Item);
            return false;
        }

        auto Source = Item.Get_ParentInventory();
        if (ck::EnsureIfNot(ck::IsValid(Source),
            f"[KeyLock] Insert into [{InLock.ToString()}]: key [{Item.ToString()}] is in no inventory - skipped"))
        {
            Broadcast_TransferFailed(InLock, Item);
            return false;
        }

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Item, InState.Inventory),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));

        return true;
    }

    // True when the transfer was requested; false when the request was refused before it.
    private bool HandleTakeRequest(FCk_Handle_KeyLock& InLock,
                                     FMars_Fragment_KeyLock& InState,
                                     const FMars_Request_KeyLock_Take& InRequest)
    {
        if (ck::EnsureIfNot(InLock.Get_Release() == EMars_KeyLock_Release::Removable,
            f"[KeyLock] Take out of [{InLock.ToString()}]: the lock keeps its key - skipped"))
        {
            Broadcast_TransferFailed(InLock, InRequest.Item);
            return false;
        }

        const auto CanTake = ck::IsValid(InRequest.Item) && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanTake,
            f"[KeyLock] Take out of [{InLock.ToString()}]: invalid item [{InRequest.Item.ToString()}] or target [{InRequest.Target.ToString()}] - skipped"))
        {
            Broadcast_TransferFailed(InLock, InRequest.Item);
            return false;
        }

        auto Inventory = InState.Inventory;
        Inventory.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InRequest.Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));

        return true;
    }

    // The lock is asked here, on the authority: the initiator's machine asked its own replicated copy before the cue, which
    // may be a round trip stale. One Act transfers at a time; a second while the first is in flight is refused.
    private void HandleActRequest(FCk_Handle_KeyLock& InLock,
                                  FMars_Fragment_KeyLock& InState,
                                  const FMars_Request_KeyLock_Act& InRequest)
    {
        const auto Initiator = InRequest.Initiator;
        if (InLock.Has_Fragment(FMars_Fragment_KeyLock_PendingAct))
        {
            Refuse_Act(InLock, Initiator, EMars_Interaction_FailReason::TransferRefused);
            return;
        }

        const auto Action = InLock.Get_ActionFor(Initiator);
        if (Action != InRequest.Action)
        {
            Refuse_Act(InLock, Initiator, EMars_Interaction_FailReason::ActionBlocked);
            return;
        }

        if (Action == EMars_KeyLock_Action::Insert)
        {
            auto Item = Initiator.As_HeldItem().Get_CurrentItem();
            InLock.Add_Fragment(FMars_Fragment_KeyLock_PendingAct(Initiator, Item));
            if (HandleInsertRequest(InLock, InState, FMars_Request_KeyLock_Insert(Item)) == false)
            { DoEnd_UnstartedAct(InLock, Initiator); }

            return;
        }

        if (Action == EMars_KeyLock_Action::Take)
        {
            auto Item = InLock.Get_Key();
            const auto Target = Initiator.As_Hotbar().TryGet_TakeTarget(Item);
            InLock.Add_Fragment(FMars_Fragment_KeyLock_PendingAct(Initiator, Item));
            if (HandleTakeRequest(InLock, InState, FMars_Request_KeyLock_Take(Item, Target)) == false)
            { DoEnd_UnstartedAct(InLock, Initiator); }

            return;
        }

        Refuse_Act(InLock, Initiator, EMars_Interaction_FailReason::ActionBlocked);
    }

    // The lock is whichever end of the transfer a lock owns: the target of an Insert, the source of a Take. A transfer an
    // Act started answers that Act; a refused one is the initiator's refusal, not a broken caller.
    UFUNCTION()
    private void OnTransferComplete(FCk_Handle_Inventory InSource,
                                    FCk_Handle_Item InItem,
                                    FCk_Handle_Inventory InTarget,
                                    int32 InCount,
                                    FCk_Handle_Item InNewItemInTarget,
                                    ECk_Inventory_OperationResult_Transfer InResult)
    {
        auto TargetLock = utils_entity_lifetime::Get_LifetimeOwner(InTarget).As_KeyLock(ECk_SanityCheck::UnChecked);
        auto SourceLock = utils_entity_lifetime::Get_LifetimeOwner(InSource).As_KeyLock(ECk_SanityCheck::UnChecked);
        const auto TargetAct = DoEnd_PendingAct(TargetLock, InItem, InResult);
        const auto SourceAct = DoEnd_PendingAct(SourceLock, InItem, InResult);

        if (InResult == ECk_Inventory_OperationResult_Transfer::Success)
        { return; }

        ck::EnsureIfNot(TargetAct || SourceAct,
            f"[KeyLock] Moving [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]");

        if (ck::IsValid(TargetLock))
        { Broadcast_TransferFailed(TargetLock, InItem); }

        if (ck::IsValid(SourceLock))
        { Broadcast_TransferFailed(SourceLock, InItem); }
    }

    // True when InLock's in-flight Act moved InItem: the Act ends, refused (TransferRefused) unless InResult is Success.
    private bool DoEnd_PendingAct(FCk_Handle_KeyLock& InLock, const FCk_Handle_Item& InItem,
                                  ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (ck::Is_NOT_Valid(InLock) || InLock.Has_Fragment(FMars_Fragment_KeyLock_PendingAct) == false)
        { return false; }

        const auto Pending = InLock.Get_Fragment(FMars_Fragment_KeyLock_PendingAct);
        if (Pending.Item != InItem)
        { return false; }

        InLock.Request_TryRemove(FMars_Fragment_KeyLock_PendingAct);
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        { Refuse_Act(InLock, Pending.Initiator, EMars_Interaction_FailReason::TransferRefused); }

        return true;
    }

    // An Act whose handler requested no transfer has nothing in flight to answer it: it ends here, refused, so the lock
    // is free for the next Act.
    private void DoEnd_UnstartedAct(FCk_Handle_KeyLock& InLock, const FCk_Handle& InInitiator)
    {
        InLock.Request_TryRemove(FMars_Fragment_KeyLock_PendingAct);
        Refuse_Act(InLock, InInitiator, EMars_Interaction_FailReason::TransferRefused);
    }

    private void Refuse_Act(FCk_Handle_KeyLock& InLock, const FCk_Handle& InInitiator, EMars_Interaction_FailReason InReason)
    {
        auto& Net = InLock.Get_Fragment(FMars_Fragment_KeyLock_Net);
        Net.RefusalSerial += 1;
        Net.LastRefusal = InReason;
        Net.LastRefused = InInitiator;
        InLock.H().Request_MarkReplicationDirty(FMars_Fragment_KeyLock_Net);
    }

    private void Broadcast_TransferFailed(FCk_Handle_KeyLock& InLock, const FCk_Handle_Item& InItem)
    {
        if (InLock.Has_Fragment(FMars_Fragment_KeyLock_Signals))
        { InLock.Get_Fragment(FMars_Fragment_KeyLock_Signals).OnTransferFailed.Broadcast(InLock, InItem); }
    }
}
