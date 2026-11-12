// Drains Dock, then Undock, then Act (each kind in queue order), on the authority only: a copy without authority drops what
// it was asked once the request fragment is removed. Dock and Undock are plain inventory transfers; the dock never writes
// what it holds here - UMars_Processor_PlatterDock_Sync reacts to what lands, like the cargo slot's sync pass - and the
// platter's world item mounts from where its item lands (UMars_Processor_WorldItem_Reconcile), so a refused transfer moves
// nothing.
//   Dock:   Item.Get_ParentInventory() -> this dock's inventory, refused when the dock is taken or the policy says no.
//   Undock: this dock's inventory -> Target. A refused undock (not the docked item, no target, or the inventory refused)
//           broadcasts OnUndockRefused, so a taker waiting on OnUndocked ends.
//   Act:    an initiator's Place or Take, resolved here: Place runs the Dock of the initiator's held item, Take the Undock of
//           the dock's item into the initiator's hotbar stow target. The dock's occupancy and policy are judged by the Dock
//           and Undock handlers alone. One Act transfers at a time; a second while the first is in flight is refused. A
//           refused Act advances FMars_Fragment_PlatterDock_Net naming the initiator, without an ensure: two machines
//           racing for one dock is legitimate.
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
        TArray<FMars_Request_PlatterDock_Act> ActRequests = InRequests.ActRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_PlatterDock_Requests);

        // Its verbs are applied by the authority: a copy without authority moves nothing and refuses nothing.
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : DockRequests)
        { HandleDockRequest(Self, InState, Request); }

        for (const auto& Request : UndockRequests)
        { HandleUndockRequest(Self, InState, Request); }

        for (const auto& Request : ActRequests)
        { HandleActRequest(Self, InState, Request); }
    }

    // True when the transfer was requested; false when the request was refused before it.
    private bool HandleDockRequest(FCk_Handle_PlatterDock& InDock,
                                   FMars_Fragment_PlatterDock& InState,
                                   const FMars_Request_PlatterDock_Dock& InRequest)
    {
        auto Item = InRequest.Item;
        auto Source = ck::IsValid(Item) ? Item.Get_ParentInventory() : FCk_Handle_Inventory();
        if (ck::EnsureIfNot(ck::IsValid(Source),
            f"[PlatterDock] Dock onto [{InDock.ToString()}]: item [{Item.ToString()}] is invalid or in no inventory - refused"))
        {
            Broadcast_DockRefused(InDock, Item, EMars_PlatterDock_Refusal::TransferFailed);
            return false;
        }

        const auto Refusal = Get_DockRefusal(InDock, Item);
        if (Refusal.IsSet())
        {
            Broadcast_DockRefused(InDock, Item, Refusal.GetValue());
            return false;
        }

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Item, InState.Inventory),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnDockTransferComplete"));

        return true;
    }

    // True when the transfer was requested; false when the request was refused before it.
    private bool HandleUndockRequest(FCk_Handle_PlatterDock& InDock,
                                     FMars_Fragment_PlatterDock& InState,
                                     const FMars_Request_PlatterDock_Undock& InRequest)
    {
        const auto IsDocked = ck::IsValid(InRequest.Item) && InRequest.Item == InDock.Get_Item();
        const auto CanUndock = IsDocked && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanUndock,
            f"[PlatterDock] Undock from [{InDock.ToString()}]: item [{InRequest.Item.ToString()}] is not the docked one, or target [{InRequest.Target.ToString()}] is invalid - refused"))
        {
            Broadcast_UndockRefused(InDock, InRequest.Item, IsDocked ? EMars_PlatterDock_Refusal::TransferFailed : EMars_PlatterDock_Refusal::NotDocked);
            return false;
        }

        auto Inventory = InState.Inventory;
        Inventory.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InRequest.Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnUndockTransferComplete"));

        return true;
    }

    // The initiator's machine asked its own replicated copy before the cue, which may be a round trip stale: the item and
    // the target are resolved here, and the handlers judge the dock as it is now.
    private void HandleActRequest(FCk_Handle_PlatterDock& InDock,
                                  FMars_Fragment_PlatterDock& InState,
                                  const FMars_Request_PlatterDock_Act& InRequest)
    {
        const auto Initiator = InRequest.Initiator;
        const auto Action = InRequest.Action;
        if (Action != EMars_PlatterDock_Action::Place && Action != EMars_PlatterDock_Action::Take)
        {
            Refuse_Act(InDock, Initiator, EMars_Interaction_FailReason::ActionBlocked);
            return;
        }

        const auto RefusedAs = Get_RefusalOf(Action);
        if (InDock.Has_Fragment(FMars_Fragment_PlatterDock_PendingAct))
        {
            Refuse_Act(InDock, Initiator, RefusedAs);
            return;
        }

        if (Action == EMars_PlatterDock_Action::Place)
        {
            const auto HeldItem = Initiator.As_HeldItem(ECk_SanityCheck::UnChecked);
            const auto Item = ck::IsValid(HeldItem) ? HeldItem.Get_CurrentItem() : FCk_Handle_Item();
            if (ck::Is_NOT_Valid(Item))
            {
                Refuse_Act(InDock, Initiator, RefusedAs);
                return;
            }

            InDock.Add_Fragment(FMars_Fragment_PlatterDock_PendingAct(Initiator, Item));
            if (HandleDockRequest(InDock, InState, FMars_Request_PlatterDock_Dock(Item)) == false)
            { DoEnd_UnstartedAct(InDock, Initiator, RefusedAs); }

            return;
        }

        const auto Item = InDock.Get_Item();
        if (ck::Is_NOT_Valid(Item))
        {
            Refuse_Act(InDock, Initiator, EMars_Interaction_FailReason::NoLongerDocked);
            return;
        }

        const auto Hotbar = Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        const auto Target = ck::IsValid(Hotbar) ? Hotbar.TryGet_StowTarget(Item) : FCk_Handle_Inventory_DataOnly();
        if (ck::Is_NOT_Valid(Target))
        {
            Refuse_Act(InDock, Initiator, EMars_Interaction_FailReason::NowhereToStow);
            return;
        }

        InDock.Add_Fragment(FMars_Fragment_PlatterDock_PendingAct(Initiator, Item));
        if (HandleUndockRequest(InDock, InState, FMars_Request_PlatterDock_Undock(Item, Target)) == false)
        { DoEnd_UnstartedAct(InDock, Initiator, RefusedAs); }
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

    // The dock is the target's owner. A transfer an Act started answers that Act.
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
        FCk_Handle Initiator;
        if (TryEnd_PendingAct(Dock, InItem, Initiator) && Succeeded == false)
        { Refuse_Act(Dock, Initiator, EMars_Interaction_FailReason::DockRefused); }

        if (ck::EnsureIfNot(Succeeded,
            f"[PlatterDock] Docking [{InItem.ToString()}] from [{InSource.ToString()}] onto [{Dock.ToString()}] failed with [{InResult :n}]"))
        {
            if (ck::IsValid(Dock))
            { Broadcast_DockRefused(Dock, InItem, EMars_PlatterDock_Refusal::TransferFailed); }
        }
    }

    // A refused undock leaves the platter docked. The dock is the source's owner. A transfer an Act started answers that
    // Act.
    UFUNCTION()
    private void OnUndockTransferComplete(FCk_Handle_Inventory InSource,
                                          FCk_Handle_Item InItem,
                                          FCk_Handle_Inventory InTarget,
                                          int32 InCount,
                                          FCk_Handle_Item InNewItemInTarget,
                                          ECk_Inventory_OperationResult_Transfer InResult)
    {
        auto Dock = utils_entity_lifetime::Get_LifetimeOwner(InSource).As_PlatterDock(ECk_SanityCheck::UnChecked);
        const auto Succeeded = InResult == ECk_Inventory_OperationResult_Transfer::Success;
        FCk_Handle Initiator;
        if (TryEnd_PendingAct(Dock, InItem, Initiator) && Succeeded == false)
        { Refuse_Act(Dock, Initiator, EMars_Interaction_FailReason::UndockRefused); }

        if (ck::EnsureIfNot(Succeeded,
            f"[PlatterDock] Undocking [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]"))
        {
            if (ck::IsValid(Dock))
            { Broadcast_UndockRefused(Dock, InItem, EMars_PlatterDock_Refusal::TransferFailed); }
        }
    }

    // True when InDock's in-flight Act moved InItem: that Act ends here, and OutInitiator is who asked for it.
    private bool TryEnd_PendingAct(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, FCk_Handle& OutInitiator)
    {
        if (ck::Is_NOT_Valid(InDock) || InDock.Has_Fragment(FMars_Fragment_PlatterDock_PendingAct) == false)
        { return false; }

        const auto Pending = InDock.Get_Fragment(FMars_Fragment_PlatterDock_PendingAct);
        if (Pending.Item != InItem)
        { return false; }

        OutInitiator = Pending.Initiator;
        InDock.Request_TryRemove(FMars_Fragment_PlatterDock_PendingAct);
        return true;
    }

    // An Act whose handler requested no transfer has nothing in flight to answer it: it ends here, refused, so the dock is
    // free for the next Act.
    private void DoEnd_UnstartedAct(FCk_Handle_PlatterDock& InDock, const FCk_Handle& InInitiator, EMars_Interaction_FailReason InReason)
    {
        InDock.Request_TryRemove(FMars_Fragment_PlatterDock_PendingAct);
        Refuse_Act(InDock, InInitiator, InReason);
    }

    private EMars_Interaction_FailReason Get_RefusalOf(EMars_PlatterDock_Action InAction) const
    {
        return InAction == EMars_PlatterDock_Action::Place
            ? EMars_Interaction_FailReason::DockRefused
            : EMars_Interaction_FailReason::UndockRefused;
    }

    private void Refuse_Act(FCk_Handle_PlatterDock& InDock, const FCk_Handle& InInitiator, EMars_Interaction_FailReason InReason)
    {
        auto& Net = InDock.Get_Fragment(FMars_Fragment_PlatterDock_Net);
        Net.RefusalSerial += 1;
        Net.LastRefusal = InReason;
        Net.LastRefused = InInitiator;
        InDock.H().Request_MarkReplicationDirty(FMars_Fragment_PlatterDock_Net);
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
