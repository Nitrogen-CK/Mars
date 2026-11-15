// Once per monster, on the monster's entity: the authority drops the mirror state (its drain publishes the ledger). A
// machine without authority binds the ledger's rep-notify, and its first pass shows the ledger this machine composed.
// The ledger's first application is the state the copy was born into and is taken once, as it stands: every changed
// condition is announced, a broken part is broken and announced, and a severed part is detached and its limb drops as
// debris, as a sever that arrives does. Each later change is reconciled as it arrives. A reconcile applies each changed
// entry to this machine's own part at that roster index: the condition (raising OnConditionChanged), then, from
// Attached, the same break or detach the authority ran, with an empty cause. Debris from a mirrored detach is this
// machine's own.
class UMars_Processor_BodyPart_Mirror : UMars_Processor_BodyPart_Base
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_BodyPart_RosterNeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Fragment_BodyPart_Roster);
        Query.Require(FMars_Tag_BodyPart_RosterNeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_BodyPart_RosterNeedsMirror);

        if (utils_net::Get_HasAuthority(InHandle))
        {
            InHandle.Get_Fragment(FMars_Fragment_BodyPart_Roster).Last = TOptional<FMars_Fragment_BodyPart_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_BodyPart_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(InHandle, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Has_Fragment(FMars_Fragment_BodyPart_Roster) == false)
        { return; }

        auto Root = InHandle;
        if (Root.Get_Fragment(FMars_Fragment_BodyPart_Roster).InitialState == EMars_Net_InitialState::Awaited)
        {
            Root.Get_Fragment(FMars_Fragment_BodyPart_Roster).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Root, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Root, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before any part changes. Only entries that differ from the last reconciled ledger are applied, so a
    // notify carrying another part's change, or nothing new, raises nothing. The ledger counts nothing, so both ways of
    // taking it apply an entry alike.
    private void Reconcile(FCk_Handle& InRoot, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InRoot.Get_Fragment(FMars_Fragment_BodyPart_Net);
        auto& Roster = InRoot.Get_Fragment(FMars_Fragment_BodyPart_Roster);
        if (ck::EnsureIfNot(Roster.Last.IsSet(), f"[BodyPart] [{InRoot.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Previous = Roster.Last.GetValue();
        Roster.Last = TOptional<FMars_Fragment_BodyPart_Net>(Ledger);

        // Copied: a handler may compose on another entity and move the roster's storage.
        const TArray<FCk_Handle_BodyPart> Parts = Roster.Parts;

        // Handlers react on the monster: scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InRoot));
        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            const auto Entry = Ledger.Get_Entry(Index);
            const auto Was = Previous.Get_Entry(Index);
            if (Entry.State == Was.State && Entry.Condition == Was.Condition)
            { continue; }

            auto Part = Parts[Index];
            if (ck::Is_NOT_Valid(Part))
            { continue; }

            Apply(Part, Entry);
        }
    }

    private void Apply(FCk_Handle_BodyPart& InPart, const FMars_BodyPart_NetEntry& InEntry)
    {
        const auto Old = InPart.Get_Condition();
        if (InEntry.Condition != Old)
        {
            InPart.Get_Fragment(FMars_Fragment_BodyPart).Condition = InEntry.Condition;

            if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
            { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnConditionChanged.Broadcast(InPart, Old, InEntry.Condition); }
        }

        if (InPart.Get_State() != EMars_BodyPart_State::Attached)
        { return; }

        if (InEntry.State == EMars_BodyPart_State::Broken)
        { DoBreak(InPart, FMars_DamageEvent()); }
        else if (InEntry.State == EMars_BodyPart_State::Severed)
        { DoDetach(InPart, FMars_DamageEvent()); }
    }
}
