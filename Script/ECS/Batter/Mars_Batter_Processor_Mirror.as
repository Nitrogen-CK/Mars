// Once per bowl. With authority it drops the mirror state: the bowl's own processors publish the ledger and broadcast.
// A machine without authority binds the ledger's rep-notify and reconciles once, showing the ledger this machine
// composed. The ledger's first application is the state the copy was born into and is taken once as it stands: each
// piece under the batter or at rest as the bowl stands, and no refusal the ledger already counts. Each later change is
// reconciled as it arrives, raising, from the arrived ledger against the one it last reconciled: OnAdmissionRefused
// once per unseen AdmissionRefusalSerial (with the ledger's last reason and a default piece id: the refused piece is
// the authority's), OnTakeOutRefused once per unseen TakeOutRefusalSerial (with the last reason), then OnBowlChanged
// once with the ledger's bowl when its serial moved. OnPieceAdded and OnPieceTakenOut are the Tick's (as each row's
// piece shows up and goes on this machine); OnCoatStage is never raised without authority.
class UMars_Processor_Batter_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Batter_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Batter);
        Query.Require(FMars_Tag_Batter_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Batter_NeedsMirror);
        auto Batter = InHandle.As_Batter();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Batter.Get_Fragment(FMars_Fragment_Batter_Local).Last = TOptional<FMars_Fragment_Batter_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Batter_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Batter, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Is_Batter() == false)
        { return; }

        auto Batter = InHandle.As_Batter();
        if (Batter.Get_Fragment(FMars_Fragment_Batter_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Batter.Get_Fragment(FMars_Fragment_Batter_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Batter, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Batter, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage, so the
    // signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_Batter& InBatter, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InBatter.Get_Fragment(FMars_Fragment_Batter_Net);
        auto& Local = InBatter.Get_Fragment(FMars_Fragment_Batter_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Batter] [{InBatter.ToString()}] has no mirror state off authority"))
        { return; }

        auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Batter_Net>(Ledger);

        // As it stands, every admission and take-out the ledger counts as refused came before this copy took its
        // state, and every piece the ledger holds is shown where the bowl puts it: this machine's follow eases only
        // what arrives.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            Last.AdmissionRefusalSerial = Ledger.AdmissionRefusalSerial;
            Last.TakeOutRefusalSerial = Ledger.TakeOutRefusalSerial;
            Local.Rows = utils_batter::Get_RowsAsTheyStand(Ledger, Local.Rows);
        }

        if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
        { return; }

        // Handlers re-text and flash on the station: scope the script world to the station's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InBatter));

        for (int32 Index = Last.AdmissionRefusalSerial; Index < Ledger.AdmissionRefusalSerial; ++Index)
        {
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnAdmissionRefused.Broadcast(InBatter, FMars_CookingFeed_PieceId(), Ledger.LastAdmissionRefusal); }
        }

        for (int32 Index = Last.TakeOutRefusalSerial; Index < Ledger.TakeOutRefusalSerial; ++Index)
        {
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnTakeOutRefused.Broadcast(InBatter, Ledger.LastTakeOutRefusal); }
        }

        if (Ledger.BowlSerial != Last.BowlSerial && InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
        { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnBowlChanged.Broadcast(InBatter, Ledger.Bowl); }
    }
}
