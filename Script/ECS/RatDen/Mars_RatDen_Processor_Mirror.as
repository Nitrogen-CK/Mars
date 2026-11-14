// Once per den: the authority drops the mirror state (its drain publishes the ledger). A machine without authority
// binds the ledger's rep-notify and reconciles once, then again as each change arrives. A den's eyes are the same
// whether a ledger stood when the copy composed or arrived later, so one reconcile serves both: it keeps EyeSlot and
// raises OnEyesChanged once per change of what the eyes show.
class UMars_Processor_RatDen_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_RatDen_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RatDen);
        Query.Require(FMars_Tag_RatDen_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_RatDen_NeedsMirror);
        auto Den = InHandle.As_RatDen();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Den.Get_Fragment(FMars_Fragment_RatDen_Local).Last = TOptional<FMars_Fragment_RatDen_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_RatDen_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Den);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_RatDen() == false)
        { return; }

        auto Den = InHandle.As_RatDen();
        Reconcile(Den);
    }

    // Last is written before the state and the broadcast.
    private void Reconcile(FCk_Handle_RatDen& InDen)
    {
        const auto Ledger = InDen.Get_Fragment(FMars_Fragment_RatDen_Net);
        auto& Local = InDen.Get_Fragment(FMars_Fragment_RatDen_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[RatDen] [{InDen.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_RatDen_Net>(Ledger);
        if (utils_rat_den::Get_IsSameLedger(Last, Ledger))
        { return; }

        const auto EyeSlot = utils_rat_den::Get_EyeSlotOf(Ledger);
        InDen.Get_Fragment(FMars_Fragment_RatDen).EyeSlot = EyeSlot;
        if (InDen.Has_Fragment(FMars_Fragment_RatDen_Signals) == false)
        { return; }

        // The assembly writes the plate: scope the script world to the den's own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InDen));
        InDen.Get_Fragment(FMars_Fragment_RatDen_Signals).OnEyesChanged.Broadcast(InDen, EyeSlot.IsSet(), EyeSlot.IsSet() ? EyeSlot.GetValue() : 0);
    }
}
