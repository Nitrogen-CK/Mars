// The authority starts and advances the cycle in its request drain and needs no setup. A client binds the ledger's
// rep-notify and reconciles once (a value that arrived before the bind never re-fires), broadcasting in the authority's
// order: a phase entry (OnPhaseChanged), then a run-state change (OnRunningChanged).
class UMars_Processor_Cycle_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Cycle_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Cycle);
        Query.Require(FMars_Tag_Cycle_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Cycle_NeedsSetup);

        if (utils_net::Get_HasAuthority(InHandle))
        {
            InHandle.Request_TryRemove(FMars_Fragment_Cycle_Mirror);
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Cycle, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        auto Cycle = InHandle.As_Cycle();
        Reconcile(Cycle);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Cycle() == false)
        { return; }

        auto Cycle = InHandle.As_Cycle();
        Reconcile(Cycle);
    }

    // Several entries between two replications broadcast once, for the phase the cycle is in now.
    private void Reconcile(FCk_Handle_Cycle& InCycle)
    {
        const auto Ledger = InCycle.Get_Fragment(FMars_Fragment_Cycle);
        auto& Mirror = InCycle.Get_Fragment(FMars_Fragment_Cycle_Mirror);
        const auto Last = Mirror.Last;
        Mirror.Last = Ledger;

        if (InCycle.Has_Fragment(FMars_Fragment_Cycle_Signals) == false)
        { return; }

        // Handlers fire a vent's jet and move a trap's part: scope the script world to the cycle's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InCycle));

        if (Ledger.PhaseEntries != Last.PhaseEntries)
        {
            InCycle.Get_Fragment(FMars_Fragment_Cycle_Signals).OnPhaseChanged.Broadcast(
                InCycle, InCycle.Get_CurrentPhase(), Ledger.PhaseIndex);
        }

        if (Ledger.RunState != Last.RunState)
        { InCycle.Get_Fragment(FMars_Fragment_Cycle_Signals).OnRunningChanged.Broadcast(InCycle, Ledger.RunState); }
    }
}
