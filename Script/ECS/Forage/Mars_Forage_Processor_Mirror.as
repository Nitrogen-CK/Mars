// Once per forage: the authority drops the mirror state (its own drain broadcasts). A client binds the ledger's
// rep-notify and reconciles once, so a ledger that replicated before the bind still counts; each reconcile raises, from
// the arrived ledger against the one it last reconciled, one OnReleased per release it had not seen (with an invalid
// world item: the yield is the authority's spawn and replicates on its own), then OnExhausted when the charges fell to 0
// or OnReplenished when they rose from 0. OnReleaseRefused is never mirrored.
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
        Reconcile(Forage);
    }

    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        auto Forage = InHandle.As_Forage();
        Reconcile(Forage);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage.
    private void Reconcile(FCk_Handle_Forage& InForage)
    {
        const auto Ledger = InForage.Get_Fragment(FMars_Fragment_Forage);
        auto& Local = InForage.Get_Fragment(FMars_Fragment_Forage_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Forage] [{InForage.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Forage>(Ledger);

        if (InForage.Has_Fragment(FMars_Fragment_Forage_Signals) == false)
        { return; }

        for (int32 Release = Last.ReleasedCount; Release < Ledger.ReleasedCount; ++Release)
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnReleased.Broadcast(InForage, FCk_Handle(), Ledger.LastReason); }

        if (Ledger.ChargesLeft <= 0 && Last.ChargesLeft > 0)
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnExhausted.Broadcast(InForage); }
        else if (Ledger.ChargesLeft > 0 && Last.ChargesLeft <= 0)
        { InForage.Get_Fragment(FMars_Fragment_Forage_Signals).OnReplenished.Broadcast(InForage); }
    }
}
