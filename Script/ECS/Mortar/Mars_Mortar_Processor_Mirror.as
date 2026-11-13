// Once per mortar: the authority drops the mirror state (its own processors publish the ledger and broadcast). A machine
// without authority binds the ledger's rep-notify and reconciles once, so a ledger that replicated before the bind still
// counts. Each reconcile writes the state the ledger shows (the batch with its grind carried on from the anchor while the
// pestle circles, the tally, the pestle's motion, the Engaged tag; the sweep only when the ledger restarted the pass),
// then raises, from the arrived ledger against the one it last reconciled: OnStrikeStarted once per unseen StrikeSerial,
// OnStrikeLanded once per unseen LandedSerial (each with the ledger's last landing), then OnBatchChanged once when the
// batch's seasoning, stage, phase or hits differ.
class UMars_Processor_Mortar_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Mortar_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Mortar);
        Query.Require(FMars_Tag_Mortar_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Mortar_NeedsMirror);
        auto Mortar = InHandle.As_Mortar();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Mortar.Get_Fragment(FMars_Fragment_Mortar_Local).Last = TOptional<FMars_Fragment_Mortar_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Mortar_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Mortar);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Mortar() == false)
        { return; }

        auto Mortar = InHandle.As_Mortar();
        Reconcile(Mortar);
    }

    // Last is written before the state and any broadcast: a handler may compose on another entity and move the fragment
    // storage, so the signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_Mortar& InMortar)
    {
        const auto Ledger = InMortar.Get_Fragment(FMars_Fragment_Mortar_Net);
        auto& Local = InMortar.Get_Fragment(FMars_Fragment_Mortar_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Mortar] [{InMortar.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Mortar_Net>(Ledger);

        FCk_Handle Entity = InMortar;
        const auto Shown = utils_mortar::Get_Shown(Entity, Ledger, InMortar.Get_Spec());
        auto& State = InMortar.Get_Fragment(FMars_Fragment_Mortar);
        State.Batch = Shown.Batch;
        State.Tally = Shown.Tally;
        State.Pestle.Motion = Shown.Pestle.Motion;
        if (Ledger.SweepSerial != Last.SweepSerial)
        { State.SweepSeconds = Shown.SweepSeconds; }

        const auto IsEngaged = Ledger.Engagement == EMars_Mortar_Engagement::Engaged;
        if (IsEngaged && InMortar.Get_IsEngaged() == false)
        { Entity.Add_Fragment(FMars_Tag_Mortar_Engaged()); }
        else if (IsEngaged == false && InMortar.Get_IsEngaged())
        { Entity.Request_TryRemove(FMars_Tag_Mortar_Engaged); }

        if (InMortar.Has_Fragment(FMars_Fragment_Mortar_Signals) == false)
        { return; }

        // Handlers re-dress and re-label the station: scope the script world to the station's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InMortar));

        for (int32 Index = Last.StrikeSerial; Index < Ledger.StrikeSerial; ++Index)
        {
            if (InMortar.Has_Fragment(FMars_Fragment_Mortar_Signals))
            { InMortar.Get_Fragment(FMars_Fragment_Mortar_Signals).OnStrikeStarted.Broadcast(InMortar); }
        }

        for (int32 Index = Last.LandedSerial; Index < Ledger.LandedSerial; ++Index)
        {
            if (InMortar.Has_Fragment(FMars_Fragment_Mortar_Signals))
            { InMortar.Get_Fragment(FMars_Fragment_Mortar_Signals).OnStrikeLanded.Broadcast(InMortar, Ledger.LastLanded); }
        }

        const auto IsBatchChanged = Ledger.Batch.Seasoning != Last.Batch.Seasoning || Ledger.Batch.Stage != Last.Batch.Stage
            || Ledger.Batch.Phase != Last.Batch.Phase || Ledger.Batch.CrushHits != Last.Batch.CrushHits;
        if (IsBatchChanged && InMortar.Has_Fragment(FMars_Fragment_Mortar_Signals))
        { InMortar.Get_Fragment(FMars_Fragment_Mortar_Signals).OnBatchChanged.Broadcast(InMortar, Shown.Batch); }
    }
}
