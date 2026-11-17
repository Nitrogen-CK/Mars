// Once per monster: the authority drops the mirror state (its drain writes the ledger and broadcasts). A machine without
// authority binds the ledger's rep-notify and reconciles once, so a death that replicated before this copy composed
// still counts. A reconcile that reads the ledger Dead while this copy's DeathCause is unset writes the death into this
// copy (the cause, the Dead attribute) and raises OnDied, once. The first application is taken as it stands, and the
// mirror records which way it wrote the death (Get_DeathTaken); OnDied is raised once either way.
class UMars_Processor_Monster_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Monster_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Monster);
        Query.Require(FMars_Tag_Monster_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Monster_NeedsMirror);
        auto Monster = InHandle.As_Monster();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Monster.Get_Fragment(FMars_Fragment_Monster_Local).Last = TOptional<FMars_Fragment_Monster_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Monster_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        // What this machine composed, or a ledger that arrived first: both stand.
        Reconcile(Monster, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Monster() == false)
        { return; }

        auto Monster = InHandle.As_Monster();
        if (Monster.Get_Fragment(FMars_Fragment_Monster_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Monster.Get_Fragment(FMars_Fragment_Monster_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Monster, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Monster, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before the state and the broadcast; DeathCause is the once-only latch, as on the authority.
    private void Reconcile(FCk_Handle_Monster& InMonster, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InMonster.Get_Fragment(FMars_Fragment_Monster_Net);
        auto& Local = InMonster.Get_Fragment(FMars_Fragment_Monster_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Monster] [{InMonster.ToString()}] has no mirror state off authority"))
        { return; }

        Local.Last = TOptional<FMars_Fragment_Monster_Net>(Ledger);

        if (Ledger.Life != EMars_Monster_Life::Dead)
        { return; }

        auto& State = InMonster.Get_Fragment(FMars_Fragment_Monster);
        if (State.DeathCause.IsSet())
        { return; }

        const auto Cause = utils_health::Make_Event(Ledger.DeathCause);
        State.DeathCause = TOptional<FMars_DamageEvent>(Cause);
        Local.DeathTaken = TOptional<EMars_Net_Reconcile>(InHow);
        utils_byte_attribute::Request_Override(State.Dead, 1, ECk_MinMaxCurrent::Current);

        if (InMonster.Has_Fragment(FMars_Fragment_Monster_Signals) == false)
        { return; }

        // Handlers enter the Dead state on the monster: scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InMonster));
        InMonster.Get_Fragment(FMars_Fragment_Monster_Signals).OnDied.Broadcast(InMonster, Cause);
    }
}
