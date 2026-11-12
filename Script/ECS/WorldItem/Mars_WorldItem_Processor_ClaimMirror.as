// Once per World-mode item composed without authority (only such an Add stamps FMars_Tag_WorldItem_NeedsClaimMirror): binds
// the replicated ledger's rep-notify and reconciles once, so a claim that replicated before the bind still counts. Each
// reconcile compares the ledger's claim with the one this machine's pickup last took on and, when they differ, claims or
// releases the pickup's Ledger reason, which takes it out of focus or brings it back. A notify that changes nothing does
// nothing. The authority writes the ledger in utils_world_item::Request_ClaimPickup and never runs this.
class UMars_Processor_WorldItem_ClaimMirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_WorldItem_NeedsClaimMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_WorldItem);
        Query.Require(FMars_Tag_WorldItem_NeedsClaimMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_WorldItem_NeedsClaimMirror);
        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(InHandle) == false,
            f"[WorldItem] [{InHandle.ToString()}] has authority but was tagged to mirror the ledger's claim"))
        { return; }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_WorldItem_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        auto WorldItem = InHandle.As_WorldItem();
        Reconcile(WorldItem);
    }

    // An expected absence, not a defect: a notify can land on an item already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Is_WorldItem() == false)
        { return; }

        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto WorldItem = InHandle.As_WorldItem();
        Reconcile(WorldItem);
    }

    private void Reconcile(FCk_Handle_WorldItem& InWorldItem)
    {
        const auto Claim = InWorldItem.Get_LedgerClaim();
        auto& State = InWorldItem.Get_Fragment(FMars_Fragment_WorldItem);
        if (State.AppliedLedgerClaim == Claim)
        { return; }

        auto Pickup = State.Pickup;
        if (ck::EnsureIfNot(ck::IsValid(Pickup), f"[WorldItem] [{InWorldItem.ToString()}] is in World mode but has no pickup to claim"))
        { return; }

        State.AppliedLedgerClaim = Claim;
        if (Claim == EMars_WorldItem_LedgerClaim::Claimed)
        { Pickup.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Ledger)); }
        else
        { Pickup.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Ledger)); }
    }
}
