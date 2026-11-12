// Once per feed: the authority drops the mirror state (its own processors publish the ledger and broadcast). A machine
// without authority binds the ledger's rep-notify and reconciles once, so a ledger that replicated before the bind still
// counts; each reconcile restarts this machine's phase clock when the authority's phase serial moved, then raises, from the
// arrived ledger against the one it last reconciled: OnPieceLetGo once per unseen LetGoSerial (naming no piece: the piece
// is the authority's to let go), OnTransferRefused once per unseen RefusalSerial (each with the ledger's last refusal),
// OnPhaseChanged once with the ledger's phase when its serial moved, then OnStockChanged once when the sourcing, the counts
// or the pile differ. OnReleaseRequested and OnTransferSettled are never raised without authority.
class UMars_Processor_CookingFeed_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_CookingFeed_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CookingFeed);
        Query.Require(FMars_Tag_CookingFeed_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_CookingFeed_NeedsMirror);
        auto Feed = InHandle.As_CookingFeed();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Feed.Get_Fragment(FMars_Fragment_CookingFeed_Local).Last = TOptional<FMars_Fragment_CookingFeed_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_CookingFeed_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Feed);
    }

    // An expected absence, not a defect: a notify can land on a feed already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Is_CookingFeed() == false)
        { return; }

        auto Feed = InHandle.As_CookingFeed();
        Reconcile(Feed);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage, so the
    // signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_CookingFeed& InFeed)
    {
        const auto Ledger = InFeed.Get_Fragment(FMars_Fragment_CookingFeed_Net);
        auto& Local = InFeed.Get_Fragment(FMars_Fragment_CookingFeed_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[CookingFeed] [{InFeed.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_CookingFeed_Net>(Ledger);

        const auto PhaseMoved = Ledger.PhaseSerial != Last.PhaseSerial;
        if (PhaseMoved)
        { Local.PhaseSeconds = 0.0f; }

        if (InFeed.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
        { return; }

        // Handlers re-text and flash on the station: scope the script world to the feed's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InFeed));

        for (int32 Index = Last.LetGoSerial; Index < Ledger.LetGoSerial; ++Index)
        {
            if (InFeed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
            { InFeed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPieceLetGo.Broadcast(InFeed, FCk_Handle_FoodPiece()); }
        }

        for (int32 Index = Last.RefusalSerial; Index < Ledger.RefusalSerial; ++Index)
        {
            if (InFeed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
            { InFeed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferRefused.Broadcast(InFeed, Ledger.LastRefusal); }
        }

        if (PhaseMoved && InFeed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { InFeed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Broadcast(InFeed, Ledger.Phase); }

        const auto IsStockChanged = Ledger.Sourcing != Last.Sourcing || Ledger.Available != Last.Available
            || Ledger.Admitted != Last.Admitted || Ledger.Pile != Last.Pile;
        if (IsStockChanged && InFeed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { InFeed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnStockChanged.Broadcast(InFeed, Ledger.Available, Ledger.Admitted); }
    }
}
