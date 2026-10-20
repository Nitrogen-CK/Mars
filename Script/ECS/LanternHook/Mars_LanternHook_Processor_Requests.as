// Drains Hang, then Take, then Refuel (each kind in queue order). Hang and Take are plain inventory transfers; the hook
// never writes what it holds here - UMars_Processor_LanternHook_Sync reacts to what lands, and the lantern's world item
// mounts from where its item lands (UMars_Processor_WorldItem_Reconcile), so a refused transfer moves nothing.
//   Hang:   Item.Get_ParentInventory() -> this hook's inventory. Refused unless the hook is empty and Item is a lantern.
//   Take:   this hook's inventory -> Target. Refused unless Item is the hung lantern.
//   Refuel: the lantern hung at the drain gets Tallow's measures (its own request) and Tallow is destroyed. Refused unless
//           a lantern hangs here with room left after the refuels already queued in this drain (the lantern applies them
//           only in its own drain), and Tallow is tallow in an inventory. A refused tallow is kept.
// A refused request (here, or by the inventory) ensures - the caller bypassed Get_ActionFor, or raced another change to
// the hook - and broadcasts OnRequestFailed so whoever waits on the hook can stop waiting.
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

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_LanternHook_Requests);

        for (const auto& Request : HangRequests)
        { HandleHangRequest(Self, InState, Request); }

        for (const auto& Request : TakeRequests)
        { HandleTakeRequest(Self, InState, Request); }

        auto QueuedMeasures = 0;
        for (const auto& Request : RefuelRequests)
        { HandleRefuelRequest(Self, Request, QueuedMeasures); }
    }

    private void HandleHangRequest(FCk_Handle_LanternHook& InHook,
                                   FMars_Fragment_LanternHook& InState,
                                   const FMars_Request_LanternHook_Hang& InRequest)
    {
        auto Item = InRequest.Item;
        if (ck::EnsureIfNot(utils_lantern_hook::Get_IsLantern(Item) && InHook.Get_IsOccupied() == false,
            f"[LanternHook] Hang on [{InHook.ToString()}]: item [{Item.ToString()}] is no lantern, or the hook is taken - skipped"))
        {
            Broadcast_RequestFailed(InHook, Item);
            return;
        }

        auto Source = Item.Get_ParentInventory();
        if (ck::EnsureIfNot(ck::IsValid(Source),
            f"[LanternHook] Hang on [{InHook.ToString()}]: lantern [{Item.ToString()}] is in no inventory - skipped"))
        {
            Broadcast_RequestFailed(InHook, Item);
            return;
        }

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Item, InState.Inventory),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));
    }

    private void HandleTakeRequest(FCk_Handle_LanternHook& InHook,
                                   FMars_Fragment_LanternHook& InState,
                                   const FMars_Request_LanternHook_Take& InRequest)
    {
        const auto CanTake = ck::IsValid(InRequest.Item) && InRequest.Item == InHook.Get_Item() && ck::IsValid(InRequest.Target);
        if (ck::EnsureIfNot(CanTake,
            f"[LanternHook] Take from [{InHook.ToString()}]: item [{InRequest.Item.ToString()}] is not the hung lantern, or target [{InRequest.Target.ToString()}] is invalid - skipped"))
        {
            Broadcast_RequestFailed(InHook, InRequest.Item);
            return;
        }

        auto Inventory = InState.Inventory;
        Inventory.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(InRequest.Item, InRequest.Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTransferComplete"));
    }

    // InOutQueuedMeasures totals the measures this drain has already queued on the hung lantern.
    private void HandleRefuelRequest(FCk_Handle_LanternHook& InHook, const FMars_Request_LanternHook_Refuel& InRequest,
                                     int32& InOutQueuedMeasures)
    {
        auto Tallow = InRequest.Tallow;
        auto Lantern = InHook.Get_Lantern();
        const auto IsTallow = ck::IsValid(Tallow) && Tallow.Has_Tallow();
        auto Inventory = IsTallow ? Tallow.Get_ParentInventory() : FCk_Handle_Inventory();
        const auto HasRoom = ck::IsValid(Lantern) && Lantern.Get_MeasuresLeft() + InOutQueuedMeasures < Lantern.Get_Measures();
        if (ck::EnsureIfNot(IsTallow && ck::IsValid(Inventory) && HasRoom,
            f"[LanternHook] Refuel at [{InHook.ToString()}]: [{Tallow.ToString()}] is no tallow in an inventory, or no lantern with room hangs here - skipped"))
        {
            Broadcast_RequestFailed(InHook, Tallow);
            return;
        }

        const auto Measures = Tallow.Get_Tallow().Measures;
        InOutQueuedMeasures += Measures;
        Lantern.Request_Refuel(FMars_Request_Lantern_Refuel(Measures));

        auto Remove = FCk_Request_Inventory_RemoveItem(Tallow);
        Remove.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Inventory.Request_RemoveItem(Remove, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    // The hook is whichever end of the transfer a hook owns: the target of a Hang, the source of a Take.
    UFUNCTION()
    private void OnTransferComplete(FCk_Handle_Inventory InSource,
                                    FCk_Handle_Item InItem,
                                    FCk_Handle_Inventory InTarget,
                                    int32 InCount,
                                    FCk_Handle_Item InNewItemInTarget,
                                    ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (ck::EnsureIfNot(InResult == ECk_Inventory_OperationResult_Transfer::Success,
            f"[LanternHook] Moving [{InItem.ToString()}] from [{InSource.ToString()}] to [{InTarget.ToString()}] failed with [{InResult :n}]"))
        {
            auto TargetHook = utils_entity_lifetime::Get_LifetimeOwner(InTarget).As_LanternHook(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(TargetHook))
            { Broadcast_RequestFailed(TargetHook, InItem); }

            auto SourceHook = utils_entity_lifetime::Get_LifetimeOwner(InSource).As_LanternHook(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(SourceHook))
            { Broadcast_RequestFailed(SourceHook, InItem); }
        }
    }

    private void Broadcast_RequestFailed(FCk_Handle_LanternHook& InHook, const FCk_Handle_Item& InItem)
    {
        if (InHook.Has_Fragment(FMars_Fragment_LanternHook_Signals))
        { InHook.Get_Fragment(FMars_Fragment_LanternHook_Signals).OnRequestFailed.Broadcast(InHook, InItem); }
    }
}
