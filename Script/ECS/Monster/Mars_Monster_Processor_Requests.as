// The monster arbiter. Die is latched: only the first one records the cause, raises the Dead attribute and writes the
// ledger. RegisterPart applies on every machine (the roster is each machine's own composition); Die only with authority
// over the monster, so a copy without it drops Die and learns the death from its mirror. Teardown (shedding legs, the
// corpse timer) belongs to the Dead HFSM state, not to this drain.
class UMars_Processor_Monster_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Monster_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Monster);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Monster_Requests& InRequests,
                       FMars_Fragment_Monster& InState)
    {
        auto Self = InHandle.As_Monster();

        TArray<FMars_Request_Monster_RegisterPart> RegisterPartRequests = InRequests.RegisterPartRequests;
        TArray<FMars_Request_Monster_Die> DieRequests = InRequests.DieRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Monster_Requests);

        for (const auto& Request : RegisterPartRequests)
        { HandleRegisterPart(Self, Request); }

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : DieRequests)
        { HandleDie(Self, Request); }
    }

    private void HandleRegisterPart(FCk_Handle_Monster& InMonster, const FMars_Request_Monster_RegisterPart& InRequest)
    {
        auto Part = InRequest.Part;
        if (ck::EnsureIfNot(ck::IsValid(Part), f"[Monster] [{InMonster.ToString()}] was asked to register an invalid part"))
        { return; }

        auto& State = InMonster.Get_Fragment(FMars_Fragment_Monster);
        for (auto Registered : State.Parts)
        {
            if (Registered == Part)
            { return; }
        }

        State.Parts.Add(Part);
    }

    private void HandleDie(FCk_Handle_Monster& InMonster, const FMars_Request_Monster_Die& InRequest)
    {
        auto& State = InMonster.Get_Fragment(FMars_Fragment_Monster);
        if (State.DeathCause.IsSet())
        { return; }

        State.DeathCause = InRequest.Cause;
        utils_byte_attribute::Request_Override(State.Dead, 1, ECk_MinMaxCurrent::Current);

        auto& Ledger = InMonster.Get_Fragment(FMars_Fragment_Monster_Net);
        Ledger.Life = EMars_Monster_Life::Dead;
        Ledger.DeathCause = utils_health::Make_NetHit(InRequest.Cause);
        FCk_Handle Entity = InMonster;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_Monster_Net);

        if (InMonster.Has_Fragment(FMars_Fragment_Monster_Signals) == false)
        { return; }

        // Handlers enter the Dead state on the monster: scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InMonster));
        InMonster.Get_Fragment(FMars_Fragment_Monster_Signals).OnDied.Broadcast(InMonster, InRequest.Cause);
    }
}
