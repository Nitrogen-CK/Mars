// Once per Health: the authority drops the mirror state (its drain publishes the ledger and broadcasts). A machine without
// authority binds the ledger's rep-notify and reconciles once, so a ledger that replicated before the bind still counts.
// Each reconcile writes the state the ledger shows (the invulnerability, the depletion latch, LastHit once a damage has
// applied), asks the local attribute to follow the ledger's value, then raises, from the arrived ledger against the one
// it last reconciled and in the authority's order: OnHealed once when the heal serial advanced, OnDamaged once when the
// damage serial advanced, OnDepleted once when the depletion serial advanced and the Health stands depleted. Several
// heals or hits inside one replication are one signal, carrying the latest.
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
        Reconcile(Health);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Health() == false)
        { return; }

        auto Health = InHandle.As_Health();
        Reconcile(Health);
    }

    // Last is written before the state and any broadcast: a handler may compose on another entity and move the fragment
    // storage, so the signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_Health& InHealth)
    {
        const auto Ledger = InHealth.Get_Fragment(FMars_Fragment_Health_Net);
        auto& Local = InHealth.Get_Fragment(FMars_Fragment_Health_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Health] [{InHealth.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Health_Net>(Ledger);

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
