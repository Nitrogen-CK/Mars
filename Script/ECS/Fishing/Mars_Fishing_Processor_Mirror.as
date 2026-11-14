// Once per spot. With authority it drops the mirror state (the spot's own processors publish the ledger and broadcast).
// Without authority it binds the ledger's rep-notify and reconciles once, showing the ledger this machine composed. The
// ledger's first application is the state the copy was born into and is taken once as it stands: the rod's aim and the
// line where the ledger has them, every level written and announced, and no cast, bite, bite end, landing or collection
// the ledger already counts. Each later change is reconciled as it arrives: it writes the state the ledger shows
// (utils_fishing::Get_Shown: the phase, the presence and its fade, the reel, the run, the tally, the dip, the bait of a
// new cast or on the water, the catch and a new landing's fling; the aim and the line only for an idle spot, since the
// ticks' follow eases them while it is engaged), moves the Engaged tag to the ledger's engagement and the Transitioning
// tag to its fade, then raises, from the arrived ledger against the one it last reconciled: OnCast once per unseen
// cast, OnBite once per unseen bite, OnBiteEnded once per unseen bite end (each with the ledger's last result),
// OnLanded once per unseen landing, OnCollected once per unseen collection (with the catch as it was last shown),
// OnPhaseChanged once when the phase serial moved and OnPresenceChanged once when the presence differs. OnBaitLanded,
// OnRun and OnSnapped are the authority's alone.
class UMars_Processor_Fishing_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Fishing_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Fishing);
        Query.Require(FMars_Tag_Fishing_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Fishing_NeedsMirror);
        auto Fishing = InHandle.As_Fishing();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Fishing.Get_Fragment(FMars_Fragment_Fishing_Local).Last = TOptional<FMars_Fragment_Fishing_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Fishing_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Fishing, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Fishing() == false)
        { return; }

        auto Fishing = InHandle.As_Fishing();
        if (Fishing.Get_Fragment(FMars_Fragment_Fishing_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Fishing.Get_Fragment(FMars_Fragment_Fishing_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Fishing, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Fishing, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before the state and any broadcast: a handler may compose on another entity and move the fragment
    // storage, so the signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_Fishing& InFishing, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InFishing.Get_Fragment(FMars_Fragment_Fishing_Net);
        auto& Local = InFishing.Get_Fragment(FMars_Fragment_Fishing_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Fishing] [{InFishing.ToString()}] has no mirror state off authority"))
        { return; }

        auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Fishing_Net>(Ledger);

        FCk_Handle Entity = InFishing;
        auto& State = InFishing.Get_Fragment(FMars_Fragment_Fishing);
        const auto CatchBefore = State.Catch;
        auto Query = FMars_Fishing_ShowQuery();
        Query.Ledger = Ledger;
        Query.Last = Last;
        Query.Spec = InFishing.Get_Spec();
        Query.State = State;
        State = utils_fishing::Get_Shown(Entity, Query);

        // As it stands, the rod and the line are where the ledger has them (the follow eases toward them only for
        // what arrives), and every cast, bite, bite end, landing and collection the ledger counts came before this copy
        // took its state. Get_Shown has already read the unmodified Last: a cast's flight, a fling and a fade show from
        // their anchors.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            State.Aim = Ledger.Aim;
            State.Line = Ledger.Line;
            Last.CastSerial = Ledger.CastSerial;
            Last.BiteSerial = Ledger.BiteSerial;
            Last.BiteEndSerial = Ledger.BiteEndSerial;
            Last.LandedSerial = Ledger.LandedSerial;
            Last.CollectedSerial = Ledger.CollectedSerial;
        }

        const auto Shown = State;

        // State is not read past this line: the tags move, and a listener may add fragments to the station.
        const auto IsEngaged = Ledger.Engagement == EMars_Fishing_Engagement::Engaged;
        if (IsEngaged && InFishing.Get_IsEngaged() == false)
        { Entity.Add_Fragment(FMars_Tag_Fishing_Engaged()); }
        else if (IsEngaged == false && InFishing.Get_IsEngaged())
        { Entity.Request_TryRemove(FMars_Tag_Fishing_Engaged); }

        const auto IsFading = utils_fishing::Get_IsFading(Ledger.Presence);
        const auto IsTransitioning = InFishing.Has_Fragment(FMars_Tag_Fishing_Transitioning);
        if (IsFading && IsTransitioning == false)
        { Entity.Add_Fragment(FMars_Tag_Fishing_Transitioning()); }
        else if (IsFading == false && IsTransitioning)
        { Entity.Request_TryRemove(FMars_Tag_Fishing_Transitioning); }

        if (InFishing.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
        { return; }

        // Handlers re-dress and re-label the station: scope the script world to the station's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InFishing));

        for (int32 Index = Last.CastSerial; Index < Ledger.CastSerial; ++Index)
        {
            if (InFishing.Has_Fragment(FMars_Fragment_Fishing_Signals))
            { InFishing.Get_Fragment(FMars_Fragment_Fishing_Signals).OnCast.Broadcast(InFishing, Ledger.CastVelocity); }
        }

        for (int32 Index = Last.BiteSerial; Index < Ledger.BiteSerial; ++Index)
        {
            if (InFishing.Has_Fragment(FMars_Fragment_Fishing_Signals))
            { InFishing.Get_Fragment(FMars_Fragment_Fishing_Signals).OnBite.Broadcast(InFishing); }
        }

        for (int32 Index = Last.BiteEndSerial; Index < Ledger.BiteEndSerial; ++Index)
        {
            if (InFishing.Has_Fragment(FMars_Fragment_Fishing_Signals))
            { InFishing.Get_Fragment(FMars_Fragment_Fishing_Signals).OnBiteEnded.Broadcast(InFishing, Ledger.LastBiteEnd); }
        }

        for (int32 Index = Last.LandedSerial; Index < Ledger.LandedSerial; ++Index)
        {
            if (InFishing.Has_Fragment(FMars_Fragment_Fishing_Signals))
            { InFishing.Get_Fragment(FMars_Fragment_Fishing_Signals).OnLanded.Broadcast(InFishing, Shown.Catch); }
        }

        for (int32 Index = Last.CollectedSerial; Index < Ledger.CollectedSerial; ++Index)
        {
            if (InFishing.Has_Fragment(FMars_Fragment_Fishing_Signals))
            { InFishing.Get_Fragment(FMars_Fragment_Fishing_Signals).OnCollected.Broadcast(InFishing, CatchBefore); }
        }

        if (Ledger.PhaseSerial != Last.PhaseSerial && InFishing.Has_Fragment(FMars_Fragment_Fishing_Signals))
        { InFishing.Get_Fragment(FMars_Fragment_Fishing_Signals).OnPhaseChanged.Broadcast(InFishing, Ledger.Phase); }

        if (Ledger.Presence != Last.Presence && InFishing.Has_Fragment(FMars_Fragment_Fishing_Signals))
        { InFishing.Get_Fragment(FMars_Fragment_Fishing_Signals).OnPresenceChanged.Broadcast(InFishing, Ledger.Presence); }
    }
}
