// Once per Health: the authority drops the mirror state (its drain publishes the ledger and broadcasts). A machine
// without authority binds the ledger's rep-notify, and its first pass shows the ledger this machine composed. The
// ledger's first application is the state the copy was born into and is taken once, as it stands: the value, the
// latches and LastHit are written, no heal or damage the ledger counts is raised, and OnDepleted is raised once when it
// stands depleted. Each later change is reconciled as it arrives: the state the ledger shows is written (the
// invulnerability, the depletion latch, LastHit once a damage has applied), the local attribute follows the ledger's
// value, then, from the arrived ledger against the one last reconciled and in the authority's order: OnHealed once
// when the heal serial advanced, OnDamaged once when the damage serial advanced, OnDepleted once when the depletion
// serial advanced and the Health stands depleted. Several heals or hits inside one replication are one signal,
// carrying the latest.
class UMars_Processor_Health_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Health_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Health);
        Query.Require(FMars_Tag_Health_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Health_NeedsMirror);
        auto Health = InHandle.As_Health();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Health.Get_Fragment(FMars_Fragment_Health_Local).Last = TOptional<FMars_Fragment_Health_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Health_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Health, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Health() == false)
        { return; }

        auto Health = InHandle.As_Health();
        if (Health.Get_Fragment(FMars_Fragment_Health_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Health.Get_Fragment(FMars_Fragment_Health_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Health, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Health, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before the state and any broadcast: a handler may compose on another entity and move the fragment
    // storage, so the signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_Health& InHealth, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InHealth.Get_Fragment(FMars_Fragment_Health_Net);
        auto& Local = InHealth.Get_Fragment(FMars_Fragment_Health_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Health] [{InHealth.ToString()}] has no mirror state off authority"))
        { return; }

        auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Health_Net>(Ledger);

        // As it stands, every heal and every damage the ledger counts came before this copy took its state: the value,
        // the latches and LastHit are written below, and only a depletion that still stands is announced.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            Last.HealSerial = Ledger.HealSerial;
            Last.DamageSerial = Ledger.DamageSerial;
        }

        auto& State = InHealth.Get_Fragment(FMars_Fragment_Health);
        State.IsInvulnerable = Ledger.Invulnerability == ECk_EnableDisable::Enable;
        State.IsDepleted = Ledger.Vitality == EMars_Health_Vitality::Depleted;
        if (Ledger.DamageSerial > 0)
        { State.LastHit = TOptional<FMars_DamageEvent>(utils_health::Make_Event(Ledger.LastDamage)); }

        const auto Attribute = State.Attribute;
        if (Math::IsNearlyEqual(utils_float_attribute::Get_FinalValue(Attribute, ECk_MinMaxCurrent::Current), Ledger.Current) == false)
        { utils_float_attribute::Request_Override_Current(Attribute, Ledger.Current); }

        if (InHealth.Has_Fragment(FMars_Fragment_Health_Signals) == false)
        { return; }

        // Handlers react on the hit entity (a sever, a death): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InHealth));

        if (Ledger.HealSerial > Last.HealSerial && InHealth.Has_Fragment(FMars_Fragment_Health_Signals))
        { InHealth.Get_Fragment(FMars_Fragment_Health_Signals).OnHealed.Broadcast(InHealth, Ledger.LastHealApplied, Ledger.Current); }

        if (Ledger.DamageSerial > Last.DamageSerial && InHealth.Has_Fragment(FMars_Fragment_Health_Signals))
        {
            InHealth.Get_Fragment(FMars_Fragment_Health_Signals).OnDamaged.Broadcast(InHealth, utils_health::Make_Event(Ledger.LastDamage),
                Ledger.LastDamageApplied, Ledger.Current);
        }

        const auto IsDepleted = Ledger.Vitality == EMars_Health_Vitality::Depleted;
        if (Ledger.DepletionSerial > Last.DepletionSerial && IsDepleted && InHealth.Has_Fragment(FMars_Fragment_Health_Signals))
        { InHealth.Get_Fragment(FMars_Fragment_Health_Signals).OnDepleted.Broadcast(InHealth, utils_health::Make_Event(Ledger.LastDamage)); }
    }
}
