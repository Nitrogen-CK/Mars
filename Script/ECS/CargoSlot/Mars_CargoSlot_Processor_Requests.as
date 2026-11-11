// Drains ExpectArrival (latest per item wins), then Stow, Take and Act (each kind in queue order). ExpectArrival is
// presentation and applies on every machine; Stow, Take and Act move an item, so a machine without authority drops them
// (its transfers would be refused, and the move replicates from the authority). Stow and Take are plain inventory
// transfers; the slot never touches its visual here - UMars_Processor_CargoSlot_Sync reacts to what lands, like the
// hotbar's sync pass - and a stowed Persistent item (a food) mounts on the slot's node from where its item lands
// (UMars_Processor_WorldItem_Reconcile).
//   Stow: Item.Get_ParentInventory() -> this slot's inventory.
//   Take: this slot's inventory -> Target.
//   Act: Get_ActionFor(Initiator) is asked again here. Unless it is still the action the request names, the Act is refused
//        (ActionBlocked): two machines racing for one slot is legitimate, so it does not ensure. Otherwise it runs as the
//        Stow of the initiator's held item, or the Take of the slot's item into the initiator's hotbar take target.
// A refused Stow or Take (here, or by the inventory) ensures - the caller bypassed Get_ActionFor, or raced another change
// to the slot - and broadcasts OnTransferFailed so whoever waits on the slot can stop waiting. A refused Act, or an Act
// whose transfer the inventory refuses (TransferRefused), advances FMars_Fragment_CargoSlot_Net naming the initiator.
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

        TArray<FMars_Request_CargoSlot_ExpectArrival> ExpectArrivalRequests = InRequests.ExpectArrivalRequests;
        TArray<FMars_Request_CargoSlot_Stow> StowRequests = InRequests.StowRequests;
        TArray<FMars_Request_CargoSlot_Take> TakeRequests = InRequests.TakeRequests;
        TArray<FMars_Request_CargoSlot_Act> ActRequests = InRequests.ActRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_CargoSlot_Requests);

        for (const auto& Request : ExpectArrivalRequests)
        {
            InState.PendingArrival = TOptional<FMars_WorldItem_PendingArrival>(
                FMars_WorldItem_PendingArrival(Request.Item, Request.From, System::GetGameTimeInSeconds()));
        }

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : StowRequests)
        { HandleStowRequest(Self, InState, Request); }

        for (const auto& Request : TakeRequests)
        { HandleTakeRequest(Self, InState, Request); }

        for (const auto& Request : ActRequests)
        { HandleActRequest(Self, InState, Request); }
    }

    // True when the transfer was requested; false when the request was refused before it.
    private bool HandleStowRequest(FCk_Handle_CargoSlot& InSlot,
                                   FMars_Fragment_CargoSlot& InState,
                                   const FMars_Request_CargoSlot_Stow& InRequest)
    {
        auto Item = InRequest.Item;
        auto Source = ck::IsValid(Item) ? Item.Get_ParentInventory() : FCk_Handle_Inventory();
        if (ck::EnsureIfNot(ck::IsValid(Source),
            f"[CargoSlot] Stow into [{InSlot.ToString()}]: item [{Item.ToString()}] is invalid or in no inventory - skipped"))
        {
            Broadcast_TransferFailed(InSlot, Item);
            return false;
        }

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Item, InState.Inventory),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));

        return true;
    }

    // True when the transfer was requested; false when the request was refused before it.
    private bool HandleTakeRequest(FCk_Handle_CargoSlot& InSlot,
                                   FMars_Fragment_CargoSlot& InState,
                                   const FMars_Request_CargoSlot_Take& InRequest)
    {
        const auto CanTake = ck::IsValid(InRequest.Item) && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanTake,
            f"[CargoSlot] Take out of [{InSlot.ToString()}]: invalid item [{InRequest.Item.ToString()}] or target [{InRequest.Target.ToString()}] - skipped"))
        {
            Broadcast_TransferFailed(InSlot, InRequest.Item);
            return false;
        }

        auto Inventory = InState.Inventory;
        Inventory.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InRequest.Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));

        return true;
    }

    // The slot is asked here, on the authority: the initiator's machine asked its own replicated copy before the cue, which
    // may be a round trip stale. One Act transfers at a time; a second while the first is in flight is refused.
    private void HandleActRequest(FCk_Handle_CargoSlot& InSlot,
                                  FMars_Fragment_CargoSlot& InState,
                                  const FMars_Request_CargoSlot_Act& InRequest)
    {
        const auto Initiator = InRequest.Initiator;
        if (InSlot.Has_Fragment(FMars_Fragment_CargoSlot_PendingAct))
        {
            Refuse_Act(InSlot, Initiator, EMars_Interaction_FailReason::TransferRefused);
            return;
        }

        const auto Action = InSlot.Get_ActionFor(Initiator);
        if (Action != InRequest.Action)
        {
            Refuse_Act(InSlot, Initiator, EMars_Interaction_FailReason::ActionBlocked);
            return;
        }

        if (Action == EMars_CargoSlot_Action::Stow)
        {
            auto Item = Initiator.As_HeldItem().Get_CurrentItem();
            InSlot.Add_Fragment(FMars_Fragment_CargoSlot_PendingAct(Initiator, Item));
            if (HandleStowRequest(InSlot, InState, FMars_Request_CargoSlot_Stow(Item)) == false)
            { DoEnd_UnstartedAct(InSlot, Initiator); }

            return;
        }

        if (Action == EMars_CargoSlot_Action::Take)
        {
            auto Item = InSlot.Get_Item();
            const auto Target = Initiator.As_Hotbar().TryGet_TakeTarget(Item);
            InSlot.Add_Fragment(FMars_Fragment_CargoSlot_PendingAct(Initiator, Item));
            if (HandleTakeRequest(InSlot, InState, FMars_Request_CargoSlot_Take(Item, Target)) == false)
            { DoEnd_UnstartedAct(InSlot, Initiator); }

            return;
        }

        Refuse_Act(InSlot, Initiator, EMars_Interaction_FailReason::ActionBlocked);
    }

    // The slot is whichever end of the transfer a cargo slot owns: the target of a Stow, the source of a Take. A transfer
    // an Act started answers that Act; a refused one is the initiator's refusal, not a broken caller.
    UFUNCTION()
    private void OnTransferComplete(FCk_Handle_Inventory InSource,
                                    FCk_Handle_Item InItem,
                                    FCk_Handle_Inventory InTarget,
                                    int32 InCount,
                                    FCk_Handle_Item InNewItemInTarget,
                                    ECk_Inventory_OperationResult_Transfer InResult)
    {
        auto TargetSlot = utils_entity_lifetime::Get_LifetimeOwner(InTarget).As_CargoSlot(ECk_SanityCheck::UnChecked);
        auto SourceSlot = utils_entity_lifetime::Get_LifetimeOwner(InSource).As_CargoSlot(ECk_SanityCheck::UnChecked);
        const auto TargetAct = DoEnd_PendingAct(TargetSlot, InItem, InResult);
        const auto SourceAct = DoEnd_PendingAct(SourceSlot, InItem, InResult);

        if (InResult == ECk_Inventory_OperationResult_Transfer::Success)
        { return; }

        ck::EnsureIfNot(TargetAct || SourceAct,
            f"[CargoSlot] Moving [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]");

        if (ck::IsValid(TargetSlot))
        { Broadcast_TransferFailed(TargetSlot, InItem); }

        if (ck::IsValid(SourceSlot))
        { Broadcast_TransferFailed(SourceSlot, InItem); }
    }

    // True when InSlot's in-flight Act moved InItem: the Act ends, refused (TransferRefused) unless InResult is Success.
    private bool DoEnd_PendingAct(FCk_Handle_CargoSlot& InSlot, const FCk_Handle_Item& InItem,
                                  ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (ck::Is_NOT_Valid(InSlot) || InSlot.Has_Fragment(FMars_Fragment_CargoSlot_PendingAct) == false)
        { return false; }

        const auto Pending = InSlot.Get_Fragment(FMars_Fragment_CargoSlot_PendingAct);
        if (Pending.Item != InItem)
        { return false; }

        InSlot.Request_TryRemove(FMars_Fragment_CargoSlot_PendingAct);
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        { Refuse_Act(InSlot, Pending.Initiator, EMars_Interaction_FailReason::TransferRefused); }

        return true;
    }

    // An Act whose handler requested no transfer has nothing in flight to answer it: it ends here, refused, so the slot
    // is free for the next Act.
    private void DoEnd_UnstartedAct(FCk_Handle_CargoSlot& InSlot, const FCk_Handle& InInitiator)
    {
        InSlot.Request_TryRemove(FMars_Fragment_CargoSlot_PendingAct);
        Refuse_Act(InSlot, InInitiator, EMars_Interaction_FailReason::TransferRefused);
    }

    private void Refuse_Act(FCk_Handle_CargoSlot& InSlot, const FCk_Handle& InInitiator, EMars_Interaction_FailReason InReason)
    {
        auto& Net = InSlot.Get_Fragment(FMars_Fragment_CargoSlot_Net);
        Net.RefusalSerial += 1;
        Net.LastRefusal = InReason;
        Net.LastRefused = InInitiator;
        InSlot.H().Request_MarkReplicationDirty(FMars_Fragment_CargoSlot_Net);
    }

    private void Broadcast_TransferFailed(FCk_Handle_CargoSlot& InSlot, const FCk_Handle_Item& InItem)
    {
        if (InSlot.Has_Fragment(FMars_Fragment_CargoSlot_Signals))
        { InSlot.Get_Fragment(FMars_Fragment_CargoSlot_Signals).OnTransferFailed.Broadcast(InSlot, InItem); }
    }
}
