// Drains SetMatcher, then SetMoveDirection, each in submission order, then AddLookDelta. Every SetMatcher that changes
// the matcher broadcasts OnMatcherChanged(Prev, New) - a swap to INVALID and back inside one frame broadcasts twice - so
// matcher-signal consumers rebind inside the handler. The AddLookDelta requests of one drain are summed into LookDelta
// (replacing the last one) and advance LookDeltaSequence once.
class UMars_Processor_InputIntents_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_InputIntents_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_InputIntents);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_InputIntents_Requests& InRequests,
                       FMars_Fragment_InputIntents& InState)
    {
        auto Self = InHandle.As_InputIntents();

        TArray<FMars_Request_InputIntents_SetMatcher> SetMatcherRequests = InRequests.SetMatcherRequests;
        TArray<FMars_Request_InputIntents_SetMoveDirection> SetMoveDirectionRequests = InRequests.SetMoveDirectionRequests;
        TArray<FMars_Request_InputIntents_AddLookDelta> AddLookDeltaRequests = InRequests.AddLookDeltaRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_InputIntents_Requests);

        for (const auto& Request : SetMatcherRequests)
        { HandleSetMatcherRequest(Self, InState, Request); }

        for (const auto& Request : SetMoveDirectionRequests)
        { InState.MoveDirection = Request.MoveDirection; }

        HandleAddLookDeltaRequests(InState, AddLookDeltaRequests);
    }

    private void HandleAddLookDeltaRequests(
        FMars_Fragment_InputIntents& InState,
        const TArray<FMars_Request_InputIntents_AddLookDelta>& InRequests)
    {
        if (InRequests.IsEmpty())
        { return; }

        auto LookDelta = FVector::ZeroVector;
        for (const auto& Request : InRequests)
        { LookDelta += Request.LookDelta; }

        InState.LookDelta = LookDelta;
        InState.LookDeltaSequence += 1;
    }

    private void HandleSetMatcherRequest(
        FCk_Handle_InputIntents& InIntents,
        FMars_Fragment_InputIntents& InState,
        const FMars_Request_InputIntents_SetMatcher& InRequest)
    {
        const auto PrevMatcher = InState.Matcher;
        if (PrevMatcher == InRequest.Matcher)
        { return; }

        InState.Matcher = InRequest.Matcher;

        if (InIntents.Has_Fragment(FMars_Fragment_InputIntents_Signals))
        { InIntents.Get_Fragment(FMars_Fragment_InputIntents_Signals).OnMatcherChanged.Broadcast(InIntents, PrevMatcher, InRequest.Matcher); }
    }
}
