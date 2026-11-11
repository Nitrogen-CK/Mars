// Once per station: the authority drops the mirror state (its own arbiter broadcasts). A client binds the ledger's
// rep-notify and reconciles once, so a ledger that replicated before the bind still counts; each reconcile raises, from
// the arrived ledger against the one it last reconciled: OnReleased (the previous operator, LastReleaseReason) when
// ReleaseSerial advanced; then OnReserved when Operator is valid and changed, or stands again after a release; then one
// OnReserveRejected (LastRefused, LastRefusal) per refusal it had not seen. The Use interaction's conditions, the Use
// claim and the placing script's prompt follow those on a client with nothing else to do.
class UMars_Processor_Station_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Station_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Station);
        Query.Require(FMars_Tag_Station_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Station_NeedsMirror);
        auto Station = InHandle.As_Station();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Station.Get_Fragment(FMars_Fragment_Station_Local).Last = TOptional<FMars_Fragment_Station>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Station, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Station);
    }

    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        auto Station = InHandle.As_Station();
        Reconcile(Station);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage.
    private void Reconcile(FCk_Handle_Station& InStation)
    {
        const auto Ledger = InStation.Get_Fragment(FMars_Fragment_Station);
        auto& Local = InStation.Get_Fragment(FMars_Fragment_Station_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Station] [{InStation.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Station>(Ledger);

        if (InStation.Has_Fragment(FMars_Fragment_Station_Signals) == false)
        { return; }

        const auto Released = Ledger.ReleaseSerial > Last.ReleaseSerial;
        if (Released)
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReleased.Broadcast(InStation, utils_station::Get_HeldBy(Last), Ledger.LastReleaseReason); }

        const auto Holder = utils_station::Get_HeldBy(Ledger);
        if (ck::IsValid(Holder) && (Released || Holder != utils_station::Get_HeldBy(Last)))
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReserved.Broadcast(InStation, Holder); }

        for (int32 Refusal = Last.RefusalSerial; Refusal < Ledger.RefusalSerial; ++Refusal)
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReserveRejected.Broadcast(InStation, Ledger.LastRefused, Ledger.LastRefusal); }
    }
}
