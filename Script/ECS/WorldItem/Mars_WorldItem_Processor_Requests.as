// Drains ArriveNextMount (latest wins), then Release (in queue order) for Persistent world items, then PickUp (in queue
// order). Where a world item mounts is not requested: UMars_Processor_WorldItem_Reconcile derives it from the inventory its
// item lives in. ArriveNextMount is presentation and applies on every machine; Release and PickUp move the item, so a
// non-authority drops them (its transfers would be refused, and the move replicates from the authority).
//
// A PickUp stows the holder's item into the initiator's hotbar stow target. While a kernel's ledger holds the item, with
// nowhere to stow, a pickup already in flight, or a refused transfer, it advances FMars_Fragment_WorldItem_Net (the
// replicated refusal) naming the initiator.
//
// A Release validates before it mutates: the item must sit in an inventory other than the holder, with no release already
// in flight. It then transfers the item back into the holder; the transfer's answer commits World (detach, Dynamic, own
// profile, the launch, the pickup's Mounted claim released). A refused transfer ensures and changes nothing. Every release
// that does not end in the World commit is answered with OnReleaseRefused, so whoever released waits on one of the two.
class UMars_Processor_WorldItem_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_HeldItem_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Hotbar_Sync");
    default _MarkedDirtyBy = FMars_Fragment_WorldItem_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_WorldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_WorldItem_Requests& InRequests,
                       FMars_Fragment_WorldItem& InState)
    {
        auto Self = InHandle.As_WorldItem();

        TArray<FMars_Request_WorldItem_ArriveNextMount> ArriveNextMountRequests = InRequests.ArriveNextMountRequests;
        TArray<FMars_Request_WorldItem_Release> ReleaseRequests = InRequests.ReleaseRequests;
        TArray<FMars_Request_WorldItem_PickUp> PickUpRequests = InRequests.PickUpRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_WorldItem_Requests);

        if (ArriveNextMountRequests.Num() > 0)
        {
            InState.NextArrive = TOptional<FMars_WorldItem_PendingArrive>(
                FMars_WorldItem_PendingArrive(ArriveNextMountRequests.Last().Arrive, System::GetGameTimeInSeconds()));
        }

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : ReleaseRequests)
        { HandleReleaseRequest(Self, InState, Request); }

        for (const auto& Request : PickUpRequests)
        { HandlePickUpRequest(Self, Request); }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // PickUp
    //--------------------------------------------------------------------------------------------------------------------------

    // The hotbar is asked here, on the authority: the initiator's machine checked its own replicated copy before the cue,
    // which may be a round trip stale.
    private void HandlePickUpRequest(FCk_Handle_WorldItem& InWorldItem, const FMars_Request_WorldItem_PickUp& InRequest)
    {
        // The ledger, not the pickup's reasons: the interactable applies a claim in its own later drain, and a client's
        // pickup sent before the claim reached it arrives here all the same.
        if (InWorldItem.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Claimed)
        {
            Refuse_PickUp(InWorldItem, InRequest.Initiator, EMars_Interaction_FailReason::ActionBlocked);
            return;
        }

        if (InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingPickUp))
        {
            Refuse_PickUp(InWorldItem, InRequest.Initiator, EMars_Interaction_FailReason::TransferRefused);
            return;
        }

        auto Item = InWorldItem.Get_HeldItem();
        const auto Hotbar = InRequest.Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        auto Target = ck::IsValid(Hotbar) && ck::IsValid(Item) ? Hotbar.TryGet_StowTarget(Item) : FCk_Handle_Inventory_DataOnly();
        if (ck::Is_NOT_Valid(Target))
        {
            Refuse_PickUp(InWorldItem, InRequest.Initiator, EMars_Interaction_FailReason::NowhereToStow);
            return;
        }

        auto Holder = InWorldItem.Get_Holder();
        InWorldItem.Add_Fragment(FMars_Fragment_WorldItem_PendingPickUp(InRequest.Initiator));
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnPickUpTransferComplete"));
    }

    // The holder is the source; its lifetime owner is the world item. A stowed Transient item's world item then ends
    // itself (its holder emptied); a Persistent one mounts from where its item landed.
    UFUNCTION()
    private void OnPickUpTransferComplete(FCk_Handle_Inventory InSource,
                                          FCk_Handle_Item InItem,
                                          FCk_Handle_Inventory InTarget,
                                          int32 InCount,
                                          FCk_Handle_Item InNewItemInTarget,
                                          ECk_Inventory_OperationResult_Transfer InResult)
    {
        FCk_Handle Holder = InSource;
        auto WorldItem = utils_entity_lifetime::Get_LifetimeOwner(Holder).As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingPickUp) == false)
        { return; }

        const auto Initiator = WorldItem.Get_Fragment(FMars_Fragment_WorldItem_PendingPickUp).Initiator;
        WorldItem.Request_TryRemove(FMars_Fragment_WorldItem_PendingPickUp);

        if (InResult == ECk_Inventory_OperationResult_Transfer::Success)
        { return; }

        Refuse_PickUp(WorldItem, Initiator, EMars_Interaction_FailReason::TransferRefused);
    }

    private void Refuse_PickUp(FCk_Handle_WorldItem& InWorldItem, const FCk_Handle& InInitiator, EMars_Interaction_FailReason InReason)
    {
        auto& Net = InWorldItem.Get_Fragment(FMars_Fragment_WorldItem_Net);
        Net.RefusalSerial += 1;
        Net.LastRefusal = InReason;
        Net.LastRefused = InInitiator;
        InWorldItem.H().Request_MarkReplicationDirty(FMars_Fragment_WorldItem_Net);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Release
    //--------------------------------------------------------------------------------------------------------------------------

    // Carried | Held -> World, once the item is back in the holder.
    private void HandleReleaseRequest(FCk_Handle_WorldItem& InWorldItem,
                                      FMars_Fragment_WorldItem& InState,
                                      const FMars_Request_WorldItem_Release& InRequest)
    {
        const auto Persistence = InWorldItem.Get_Persistence();
        const auto TargetMount = InWorldItem.Get_TargetMount();
        const auto IsMounted = TargetMount == EMars_WorldItem_Mount::Carried || TargetMount == EMars_WorldItem_Mount::Held;
        const auto IsLegal = Persistence == EMars_WorldItem_Persistence::Persistent && InState.Item.IsSet() && IsMounted;
        if (ck::EnsureIfNot(IsLegal,
            f"[WorldItem] Illegal release of [{InWorldItem.ToString()}]: mount [{TargetMount :n}], persistence [{Persistence :n}], item linked [{InState.Item.IsSet()}] - skipped"))
        {
            Refuse_Release(InWorldItem, EMars_WorldItem_ReleaseRefusal::NotMounted);
            return;
        }

        const auto InFlight = InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingRelease);
        if (ck::EnsureIfNot(InFlight == false,
            f"[WorldItem] Release of [{InWorldItem.ToString()}] while its last release has not answered - skipped"))
        {
            Refuse_Release(InWorldItem, EMars_WorldItem_ReleaseRefusal::InFlight);
            return;
        }

        auto Item = InState.Item.GetValue();
        auto Source = ck::IsValid(Item) ? Item.Get_ParentInventory() : FCk_Handle_Inventory();
        FCk_Handle SourceEntity = Source;
        const FCk_Handle HolderEntity = InState.Holder;
        const auto IsAway = ck::IsValid(Source) && SourceEntity != HolderEntity;
        if (ck::EnsureIfNot(IsAway,
            f"[WorldItem] Release of [{InWorldItem.ToString()}]: its item [{Item.ToString()}] is in no inventory but its own holder ([{Source.ToString()}]) - skipped"))
        {
            Refuse_Release(InWorldItem, EMars_WorldItem_ReleaseRefusal::NotAway);
            return;
        }

        InWorldItem.Add_Fragment(FMars_Fragment_WorldItem_PendingRelease(InRequest.LinearVelocity, InRequest.AngularVelocityDeg));

        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Item, InState.Holder),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnReleaseTransferComplete"));
    }

    // The holder is the target; its lifetime owner is the world item. A world item gone since its release has nothing to
    // commit.
    UFUNCTION()
    private void OnReleaseTransferComplete(FCk_Handle_Inventory InSource,
                                           FCk_Handle_Item InItem,
                                           FCk_Handle_Inventory InTarget,
                                           int32 InCount,
                                           FCk_Handle_Item InNewItemInTarget,
                                           ECk_Inventory_OperationResult_Transfer InResult)
    {
        FCk_Handle Holder = InTarget;
        auto WorldItem = utils_entity_lifetime::Get_LifetimeOwner(Holder).As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingRelease) == false)
        { return; }

        const auto Release = WorldItem.Get_Fragment(FMars_Fragment_WorldItem_PendingRelease);
        WorldItem.Request_TryRemove(FMars_Fragment_WorldItem_PendingRelease);

        if (ck::EnsureIfNot(InResult == ECk_Inventory_OperationResult_Transfer::Success,
            f"[WorldItem] Returning [{InItem.ToString()}] from [{InSource.ToString()}] to the holder of [{WorldItem.ToString()}] failed with [{InResult :n}]: it stays mounted"))
        {
            Refuse_Release(WorldItem, EMars_WorldItem_ReleaseRefusal::TransferFailed);
            return;
        }

        const auto Launch = FMars_Fragment_WorldItem_PendingLaunch(Release.LinearVelocity, Release.AngularVelocityDeg);
        utils_world_item::Commit_World(WorldItem, TOptional<FMars_Fragment_WorldItem_PendingLaunch>(Launch),
            FCk_Delegate_Request_OnCompleted(this, n"OnOwnProfileRestored"));
    }

    private void Refuse_Release(FCk_Handle_WorldItem& InWorldItem, EMars_WorldItem_ReleaseRefusal InReason)
    {
        if (InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_Signals))
        { InWorldItem.Get_Fragment(FMars_Fragment_WorldItem_Signals).OnReleaseRefused.Broadcast(InWorldItem, InReason); }
    }

    // The body has no profile read-back: the completed request is the record (the body is the world item's own entity). A
    // request cancelled with its body (the world item torn down) has nothing to record.
    UFUNCTION()
    private void OnOwnProfileRestored(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        if (InResult == ECk_Request_OperationResult::Failed_Cancelled)
        { return; }

        auto Owner = InRequestOwner;
        if (ck::EnsureIfNot(InResult == ECk_Request_OperationResult::Succeeded,
            f"[WorldItem] Restoring the own collision profile of [{Owner.ToString()}] completed [{InResult :n}]"))
        { return; }

        if (ck::Is_NOT_Valid(Owner) || Owner.Has_Fragment(FMars_Fragment_WorldItem) == false)
        { return; }

        auto& State = Owner.Get_Fragment(FMars_Fragment_WorldItem);
        State.AppliedBodyProfile = TOptional<FName>(State.BodyProfile);
    }
}
