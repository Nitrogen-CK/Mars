// The only writer of the dial's state. The last lock request applies first, then each step in arrival order; a step
// while locked is dropped. One OnIndexChanged per drain, carrying the final index, and only when it moved.
class UMars_Processor_Dial_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Dial_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Dial);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Dial_Requests& InRequests, FMars_Fragment_Dial& InState)
    {
        auto Self = InHandle.As_Dial();

        const auto HasLock = InRequests.LockRequests.Num() > 0;
        const auto Locked = HasLock ? InRequests.LockRequests.Last().Locked : InState.Locked;
        const auto StepRequests = InRequests.StepRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Dial_Requests);

        InState.Locked = Locked;
        if (Locked)
        { return; }

        const auto Positions = Self.Get_Positions();
        const auto Before = InState.Index;
        auto Index = Before;
        for (const auto& Step : StepRequests)
        { Index = utils_dial::Get_Wrapped(Index, Step.Detents, Positions); }

        if (Index == Before)
        { return; }

        InState.Index = Index;

        if (Self.Has_Fragment(FMars_Fragment_Dial_Signals))
        { Self.Get_Fragment(FMars_Fragment_Dial_Signals).OnIndexChanged.Broadcast(Self, Index); }
    }
}
