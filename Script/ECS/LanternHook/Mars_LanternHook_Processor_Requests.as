// Drains Hang, then Take, then Refuel, then Act (each kind in queue order). Every kind moves a lantern or uses tallow, so a
// machine without authority drops them all (its transfers would be refused, and the move replicates from the authority).
// Hang and Take are plain inventory transfers; the hook never writes what it holds here -
// UMars_Processor_LanternHook_Sync reacts to what lands, and the lantern's world item mounts from where its item lands
// (UMars_Processor_WorldItem_Reconcile), so a refused transfer moves nothing.
//   Hang:   Item.Get_ParentInventory() -> this hook's inventory. Refused unless the hook is empty and Item is a lantern.
//   Take:   this hook's inventory -> Target. Refused unless Item is the hung lantern.
//   Refuel: the lantern hung at the drain gets Tallow's measures (its own request) and Tallow is destroyed. Refused unless
//           a lantern hangs here with room left after the refuels already queued in this drain (the lantern applies them
//           only in its own drain), and Tallow is tallow in an inventory. A refused tallow is kept.
//   Act:    Get_ActionFor(Initiator) is asked again here. Unless it is still the action the request names, the Act is
//           refused (ActionBlocked): two machines racing for one hook is legitimate, so it does not ensure. Otherwise it
//           runs as the Hang of the initiator's held lantern, the Take of the hung lantern into the initiator's hotbar take
//           target, or the Refuel with the initiator's held tallow.
// A refused Hang, Take or Refuel (here, or by the inventory) ensures - the caller bypassed Get_ActionFor, or raced another
// change to the hook - and broadcasts OnRequestFailed so whoever waits on the hook can stop waiting. A refused Act, or an
// Act whose transfer the inventory refuses (TransferRefused), advances FMars_Fragment_LanternHook_Net naming the initiator.
class UMars_Processor_LanternHook_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_LanternHook_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_LanternHook);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_LanternHook_Requests& InRequests,
                       FMars_Fragment_LanternHook& InState)
    {
        auto Self = InHandle.As_LanternHook();

        TArray<FMars_Request_LanternHook_Hang> HangRequests = InRequests.HangRequests;
        TArray<FMars_Request_LanternHook_Take> TakeRequests = InRequests.TakeRequests;
        TArray<FMars_Request_LanternHook_Refuel> RefuelRequests = InRequests.RefuelRequests;

        TArray<FMars_Request_LanternHook_Act> ActRequests = InRequests.ActRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_LanternHook_Requests);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : HangRequests)
        { HandleHangRequest(Self, InState, Request); }

        for (const auto& Request : TakeRequests)
        { HandleTakeRequest(Self, InState, Request); }

        auto QueuedMeasures = 0;
        for (const auto& Request : RefuelRequests)
        { HandleRefuelRequest(Self, Request, QueuedMeasures); }

        for (const auto& Request : ActRequests)
        { HandleActRequest(Self, Request, QueuedMeasures); }
    }

    // The hook is asked here, on the authority: the initiator's machine asked its own replicated copy before the cue, which
    // may be a round trip stale. One Act transfers at a time; a second while the first is in flight is refused.
    private void HandleActRequest(FCk_Handle_LanternHook& InHook, const FMars_Request_LanternHook_Act& InRequest,
                                  int32& InOutQueuedMeasures)
    {
        auto& State = InHook.Get_Fragment(FMars_Fragment_LanternHook);
        const auto Initiator = InRequest.Initiator;
        if (InHook.Has_Fragment(FMars_Fragment_LanternHook_PendingAct))
        {
            Refuse_Act(InHook, Initiator, EMars_Interaction_FailReason::TransferRefused);
            return;
        }

        const auto Action = InHook.Get_ActionFor(Initiator);
        if (Action != InRequest.Action)
        {
            Refuse_Act(InHook, Initiator, EMars_Interaction_FailReason::ActionBlocked);
            return;
        }

        if (Action == EMars_LanternHook_Action::Hang)
        {
            auto Item = Initiator.As_HeldItem().Get_CurrentItem();
            InHook.Add_Fragment(FMars_Fragment_LanternHook_PendingAct(Initiator, Item));
            if (HandleHangRequest(InHook, State, FMars_Request_LanternHook_Hang(Item)) == false)
            { DoEnd_UnstartedAct(InHook, Initiator); }

            return;
        }

        if (Action == EMars_LanternHook_Action::Take)
        {
            auto Item = InHook.Get_Item();
            const auto Target = Initiator.As_Hotbar().TryGet_TakeTarget(Item);
            InHook.Add_Fragment(FMars_Fragment_LanternHook_PendingAct(Initiator, Item));
            if (HandleTakeRequest(InHook, State, FMars_Request_LanternHook_Take(Item, Target)) == false)
            { DoEnd_UnstartedAct(InHook, Initiator); }

            return;
        }

        if (Action == EMars_LanternHook_Action::Refuel)
        {
            // Get_ActionFor cannot see what this drain already queued on the lantern: a second refuel for the last room
            // is two initiators racing, not a broken caller.
            const auto Flame = InHook.Get_Flame();
            if (Flame.Get_MeasuresLeft() + InOutQueuedMeasures >= Flame.Get_Measures())
            {
                Refuse_Act(InHook, Initiator, EMars_Interaction_FailReason::ActionBlocked);
                return;
            }

            HandleRefuelRequest(InHook, FMars_Request_LanternHook_Refuel(Initiator.As_HeldItem().Get_CurrentItem()), InOutQueuedMeasures);
            return;
        }

        Refuse_Act(InHook, Initiator, EMars_Interaction_FailReason::ActionBlocked);
    }

    // True when the transfer was requested; false when the request was refused before it.
    private bool HandleHangRequest(FCk_Handle_LanternHook& InHook,
                                   FMars_Fragment_LanternHook& InState,
                                   const FMars_Request_LanternHook_Hang& InRequest)
    {
        auto Item = InRequest.Item;
        if (ck::EnsureIfNot(utils_lantern_hook::Get_IsLantern(Item) && InHook.Get_IsOccupied() == false,
            f"[LanternHook] Hang on [{InHook.ToString()}]: item [{Item.ToString()}] is no lantern, or the hook is taken - skipped"))
        {
            Broadcast_RequestFailed(InHook, Item);
            return false;
        }

        auto Source = Item.Get_ParentInventory();
        if (ck::EnsureIfNot(ck::IsValid(Source),
            f"[LanternHook] Hang on [{InHook.ToString()}]: lantern [{Item.ToString()}] is in no inventory - skipped"))
        {
            Broadcast_RequestFailed(InHook, Item);
            return false;
        }

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Item, InState.Inventory),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));

        return true;
    }

    // True when the transfer was requested; false when the request was refused before it.
    private bool HandleTakeRequest(FCk_Handle_LanternHook& InHook,
                                   FMars_Fragment_LanternHook& InState,
                                   const FMars_Request_LanternHook_Take& InRequest)
    {
        const auto CanTake = ck::IsValid(InRequest.Item) && InRequest.Item == InHook.Get_Item() && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanTake,
            f"[LanternHook] Take from [{InHook.ToString()}]: item [{InRequest.Item.ToString()}] is not the hung lantern, or target [{InRequest.Target.ToString()}] is invalid - skipped"))
        {
            Broadcast_RequestFailed(InHook, InRequest.Item);
            return false;
        }

        auto Inventory = InState.Inventory;
        Inventory.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InRequest.Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));

        return true;
    }

    // InOutQueuedMeasures totals the measures this drain has already queued on the hung lantern.
    private void HandleRefuelRequest(FCk_Handle_LanternHook& InHook, const FMars_Request_LanternHook_Refuel& InRequest,
                                     int32& InOutQueuedMeasures)
    {
        auto Tallow = InRequest.Tallow;
        auto Flame = InHook.Get_Flame();
        const auto IsTallow = ck::IsValid(Tallow) && Tallow.Has_Tallow();
        auto Inventory = IsTallow ? Tallow.Get_ParentInventory() : FCk_Handle_Inventory();
        const auto HasRoom = ck::IsValid(Flame) && Flame.Get_CanRefuel()
            && Flame.Get_MeasuresLeft() + InOutQueuedMeasures < Flame.Get_Measures();
        if (ck::EnsureIfNot(IsTallow && ck::IsValid(Inventory) && HasRoom,
            f"[LanternHook] Refuel at [{InHook.ToString()}]: [{Tallow.ToString()}] is no tallow in an inventory, or no lantern with room hangs here - skipped"))
        {
            Broadcast_RequestFailed(InHook, Tallow);
            return;
        }

        const auto Measures = Tallow.Get_Tallow().Measures;
        InOutQueuedMeasures += Measures;
        Flame.Request_Refuel(FMars_Request_Flame_Refuel(Measures));

        auto Remove = FCk_Request_Inventory_RemoveItem(Tallow);
        Remove.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Inventory.Request_RemoveItem(Remove, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    // The hook is whichever end of the transfer a hook owns: the target of a Hang, the source of a Take. A transfer an Act
    // started answers that Act; a refused one is the initiator's refusal, not a broken caller.
    UFUNCTION()
    private void OnTransferComplete(FCk_Handle_Inventory InSource,
                                    FCk_Handle_Item InItem,
                                    FCk_Handle_Inventory InTarget,
                                    int32 InCount,
                                    FCk_Handle_Item InNewItemInTarget,
                                    ECk_Inventory_OperationResult_Transfer InResult)
    {
        auto TargetHook = utils_entity_lifetime::Get_LifetimeOwner(InTarget).As_LanternHook(ECk_SanityCheck::UnChecked);
        auto SourceHook = utils_entity_lifetime::Get_LifetimeOwner(InSource).As_LanternHook(ECk_SanityCheck::UnChecked);
        const auto TargetAct = DoEnd_PendingAct(TargetHook, InItem, InResult);
        const auto SourceAct = DoEnd_PendingAct(SourceHook, InItem, InResult);

        if (InResult == ECk_Inventory_OperationResult_Transfer::Success)
        { return; }

        ck::EnsureIfNot(TargetAct || SourceAct,
            f"[LanternHook] Moving [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]");

        if (ck::IsValid(TargetHook))
        { Broadcast_RequestFailed(TargetHook, InItem); }

        if (ck::IsValid(SourceHook))
        { Broadcast_RequestFailed(SourceHook, InItem); }
    }

    // True when InHook's in-flight Act moved InItem: the Act ends, refused (TransferRefused) unless InResult is Success.
    private bool DoEnd_PendingAct(FCk_Handle_LanternHook& InHook, const FCk_Handle_Item& InItem,
                                  ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (ck::Is_NOT_Valid(InHook) || InHook.Has_Fragment(FMars_Fragment_LanternHook_PendingAct) == false)
        { return false; }

        const auto Pending = InHook.Get_Fragment(FMars_Fragment_LanternHook_PendingAct);
        if (Pending.Item != InItem)
        { return false; }

        InHook.Request_TryRemove(FMars_Fragment_LanternHook_PendingAct);
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        { Refuse_Act(InHook, Pending.Initiator, EMars_Interaction_FailReason::TransferRefused); }

        return true;
    }

    // An Act whose handler requested no transfer has nothing in flight to answer it: it ends here, refused, so the hook
    // is free for the next Act.
    private void DoEnd_UnstartedAct(FCk_Handle_LanternHook& InHook, const FCk_Handle& InInitiator)
    {
        InHook.Request_TryRemove(FMars_Fragment_LanternHook_PendingAct);
        Refuse_Act(InHook, InInitiator, EMars_Interaction_FailReason::TransferRefused);
    }

    private void Refuse_Act(FCk_Handle_LanternHook& InHook, const FCk_Handle& InInitiator, EMars_Interaction_FailReason InReason)
    {
        auto& Net = InHook.Get_Fragment(FMars_Fragment_LanternHook_Net);
        Net.RefusalSerial += 1;
        Net.LastRefusal = InReason;
        Net.LastRefused = InInitiator;
        InHook.H().Request_MarkReplicationDirty(FMars_Fragment_LanternHook_Net);
    }

    private void Broadcast_RequestFailed(FCk_Handle_LanternHook& InHook, const FCk_Handle_Item& InItem)
    {
        if (InHook.Has_Fragment(FMars_Fragment_LanternHook_Signals))
        { InHook.Get_Fragment(FMars_Fragment_LanternHook_Signals).OnRequestFailed.Broadcast(InHook, InItem); }
    }
}
