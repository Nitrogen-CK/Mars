// Once per forage: the authority drops the mirror state (its own drain broadcasts). A client binds the ledger's
// rep-notify and its first pass shows the ledger this machine composed. The ledger's first application is the state the
// copy was born into, taken once as it stands: the charges as they stand, an exhausted source announced once, and no
// release the ledger already counts raised. Each later change is reconciled as it arrives: from the arrived ledger
// against the one it last reconciled, one OnReleased per release it had not seen (with an invalid world item: the yield
// is the authority's spawn and replicates on its own), then OnExhausted when the charges fell to 0 or OnReplenished
// when they rose from 0. OnReleaseRefused is never mirrored.
class UMars_Processor_Forage_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Forage_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Forage);
        Query.Require(FMars_Tag_Forage_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Forage_NeedsMirror);
        auto Forage = InHandle.As_Forage();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Forage.Get_Fragment(FMars_Fragment_Forage_Local).Last = TOptional<FMars_Fragment_Forage>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Forage, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Forage, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a source already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Forage() == false)
        { return; }

        auto Forage = InHandle.As_Forage();
        if (Forage.Get_Fragment(FMars_Fragment_Forage_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Forage.Get_Fragment(FMars_Fragment_Forage_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Forage, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Forage, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage.
    private void Reconcile(FCk_Handle_Forage& InForage, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InForage.Get_Fragment(FMars_Fragment_Forage);
        auto& Local = InForage.Get_Fragment(FMars_Fragment_Forage_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Forage] [{InForage.ToString()}] has no mirror state off authority"))
        { return; }

        auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Forage>(Ledger);

        // As it stands, every release the ledger counts came before this copy took its state; an exhausted source is
        // still announced once.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { Last.ReleasedCount = Ledger.ReleasedCount; }

        if (InForage.Has_Fragment(FMars_Fragment_Forage_Signals) == false)
        { return; }

        // Handlers swing a censer, crack a husk and dress a bed: scope the script world to the source's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InForage));

        for (int32 Release = Last.ReleasedCount; Release < Ledger.ReleasedCount; ++Release)
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnReleased.Broadcast(InForage, FCk_Handle(), Ledger.LastReason); }

        if (Ledger.ChargesLeft <= 0 && Last.ChargesLeft > 0)
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnExhausted.Broadcast(InForage); }
        else if (Ledger.ChargesLeft > 0 && Last.ChargesLeft <= 0)
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnReplenished.Broadcast(InForage); }
    }
}
