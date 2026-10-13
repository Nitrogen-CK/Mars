// A Cancel applies first and lets the held victim go; then the Begins are tried in the order they were asked, and the
// first one that can be taken (utils Get_CanSeize) seizes its victim. The rest are dropped: one victim at a time.
class UMars_Processor_Devour_HandleRequests : UCk_Processor_Script_Base_UE
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

        auto Released = FCk_Handle();
        const auto DidCancel = HasCancel && Self.Get_IsActive();
        if (DidCancel)
        { Released = utils_devour::DoRelease(Self, InState); }

        auto DidSeize = false;
        for (const auto& Begin : Begins)
        {
            if (Self.Get_CanSeize(Begin.Victim) == false)
            { continue; }

            utils_devour::DoSeize(Self, InState, Begin.Victim);
            DidSeize = true;
            break;
        }

        if (Self.Has_Fragment(FMars_Fragment_Devour_Signals) == false)
        { return; }

        if (DidCancel)
        { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnEnded.Broadcast(Self, Released, EMars_Devour_End::Cancelled); }

        if (DidSeize)
        { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnPhaseChanged.Broadcast(Self, EMars_Devour_Phase::Seize); }
    }
}
