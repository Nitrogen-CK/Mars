// Once per station: the authority drops the mirror state (its own arbiter broadcasts). A client binds the ledger's
// rep-notify and reconciles once, showing the ledger this machine composed. The ledger's first application is the state
// the copy was born into and is taken once as it stands: an operator who holds the station is raised once, and no
// release or refused reserve the ledger already counts. Each later change is reconciled as it arrives, from the arrived
// ledger against the one it last reconciled: OnReleased (the previous operator, LastReleaseReason) when ReleaseSerial
// advanced; then OnReserved when the holder (utils_station::Get_HeldBy) is valid and changed, or stands again after a
// release; then one OnReserveRejected (LastRefused, LastRefusal) per refusal it had not seen. The Use interaction's
// conditions, the Use claim and the placing script's prompt follow those on a client with nothing else to do.
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
        Reconcile(Station, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Station() == false)
        { return; }

        auto Station = InHandle.As_Station();
        if (Station.Get_Fragment(FMars_Fragment_Station_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Station.Get_Fragment(FMars_Fragment_Station_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Station, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Station, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage.
    private void Reconcile(FCk_Handle_Station& InStation, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InStation.Get_Fragment(FMars_Fragment_Station);
        auto& Local = InStation.Get_Fragment(FMars_Fragment_Station_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Station] [{InStation.ToString()}] has no mirror state off authority"))
        { return; }

        auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Station>(Ledger);

        // As it stands, every release and every refused reserve the ledger counts came before this copy took its state.
        // Last's occupancy stays as this machine last showed it, so an operator who holds the station is raised once.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            Last.ReleaseSerial = Ledger.ReleaseSerial;
            Last.RefusalSerial = Ledger.RefusalSerial;
        }

        if (InStation.Has_Fragment(FMars_Fragment_Station_Signals) == false)
        { return; }

        // Handlers claim the Use target and re-word its prompt: scope the script world to the station's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InStation));

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
