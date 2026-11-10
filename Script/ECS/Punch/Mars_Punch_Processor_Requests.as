// Drains Mirror, then Throw. A Mirror throws its hand's fist at once, in arrival order (a jab another machine threw: its
// rhythm was applied there). Throws carry no payload, so any number of them in a drain are one throw waiting for its
// turn; UMars_Processor_Punch_Tick, which runs after this, starts it the moment the rhythm allows - this frame when it
// already does. A throw arriving while one waits is dropped.
class UMars_Processor_Punch_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Punch_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Punch);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Punch_Requests& InRequests,
                       FMars_Fragment_Punch& InState)
    {
        auto Self = InHandle.As_Punch();

        TArray<FMars_Request_Punch_Mirror> MirrorRequests = InRequests.MirrorRequests;
        const auto Throw = InRequests.ThrowRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Punch_Requests);

        for (const auto& Request : MirrorRequests)
        { utils_punch::Start_Jab(InState, Request.Hand, false); }

        if (Throw)
        { InState.HasWaitingThrow = true; }

        // InState is not touched past this line: a listener may compose anything.
        if (Self.Has_Fragment(FMars_Fragment_Punch_Signals) == false)
        { return; }

        for (const auto& Request : MirrorRequests)
        { Self.Get_Fragment(FMars_Fragment_Punch_Signals).OnThrown.Broadcast(Self, Request.Hand); }
    }
}
