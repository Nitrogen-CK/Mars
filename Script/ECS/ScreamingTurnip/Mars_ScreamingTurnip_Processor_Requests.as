// Drains Suspend: the warning is cancelled as entering Loose cancels it (WarningElapsed 0, phase Dormant; the last commit
// and the sequence kept) and the next tick runs no voice. Several in one drain are one. Only a machine with authority
// over the root applies them; it publishes the ledger before it broadcasts (utils_screaming_turnip::Publish). A copy
// without authority drops them.
class UMars_Processor_ScreamingTurnip_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_ScreamingTurnip_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_ScreamingTurnip);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_ScreamingTurnip_Requests& InRequests,
                       FMars_Fragment_ScreamingTurnip& InState)
    {
        auto Self = InHandle.As_ScreamingTurnip();
        const auto SuspendCount = InRequests.SuspendRequests.Num();

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_ScreamingTurnip_Requests);

        if (utils_net::Get_HasAuthority(InHandle) == false || SuspendCount == 0)
        { return; }

        const auto Previous = InState.Phase;
        InState.SuspendPending = true;
        InState.WarningElapsed = 0.0f;
        InState.Phase = EMars_ScreamingTurnip_Phase::Dormant;
        InState.PhaseStartedAt = InState.Clock;
        utils_screaming_turnip::Publish(Self);

        // Handlers react on the root (its presentation): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(Self));

        if (Previous != EMars_ScreamingTurnip_Phase::Dormant && Self.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals))
        { Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnPhaseChanged.Broadcast(Self, Previous, EMars_ScreamingTurnip_Phase::Dormant); }
    }
}
