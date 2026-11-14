// A Cancel applies first and lets the held victim go; then the Begins are tried in the order they were asked, and the
// first one that can be taken (utils Get_CanSeize) seizes its victim. The rest are dropped: one victim at a time. Only
// a machine with authority over the devourer applies them; it publishes the ledger (utils_devour::Publish) before the
// signals are raised.
class UMars_Processor_Devour_HandleRequests : UMars_Processor_Devour_Base
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Devour_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Devour);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Devour_Requests& InRequests,
                       FMars_Fragment_Devour& InState)
    {
        auto Self = InHandle.As_Devour();
        const auto HasCancel = InRequests.CancelRequests.Num() > 0;
        const TArray<FMars_Request_Devour_Begin> Begins = InRequests.BeginRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Devour_Requests);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto Released = FCk_Handle();
        const auto DidCancel = HasCancel && Self.Get_IsActive();
        if (DidCancel)
        { Released = DoRelease(Self, InState, EMars_Devour_End::Cancelled); }

        auto DidSeize = false;
        for (const auto& Begin : Begins)
        {
            if (Self.Get_CanSeize(Begin.Victim) == false)
            { continue; }

            DoSeize(Self, InState, Begin.Victim);
            DidSeize = true;
            break;
        }

        utils_devour::Publish(Self);

        // Handlers react on the devourer and its victim (a view, a state machine): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InHandle));
        if (DidCancel && Self.Has_Fragment(FMars_Fragment_Devour_Signals))
        { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnEnded.Broadcast(Self, Released, EMars_Devour_End::Cancelled); }

        if (DidSeize && Self.Has_Fragment(FMars_Fragment_Devour_Signals))
        { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnPhaseChanged.Broadcast(Self, EMars_Devour_Phase::Seize); }
    }
}
