// Drains one step every SecondsPerStep while charged, broadcasting each change; the last step removes the Running tag.
// The authority's clock: a client's copy touches nothing (its Remaining arrives through the ledger).
class UMars_Processor_Countdown_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Countdown);
        Query.Require(FMars_Tag_Countdown_Running);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Countdown& InState)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto Self = InHandle.As_Countdown();
        const auto SecondsPerStep = Self.Get_Fragment(FMars_Fragment_Countdown_Params).SecondsPerStep;

        auto& Clock = Self.Get_Fragment(FMars_Fragment_Countdown_Clock);
        Clock.StepElapsed += float32(InDeltaT.Get_Seconds());

        const auto Previous = InState.Remaining;
        while (InState.Remaining > 0 && Clock.StepElapsed >= SecondsPerStep)
        {
            InState.Remaining -= 1;
            Clock.StepElapsed -= SecondsPerStep;
        }

        if (InState.Remaining <= 0)
        {
            InState.Remaining = 0;
            Clock.StepElapsed = 0.0f;
            Self.Request_TryRemove(FMars_Tag_Countdown_Running);
        }

        if (InState.Remaining == Previous)
        { return; }

        InHandle.Request_MarkReplicationDirty(FMars_Fragment_Countdown);

        if (Self.Has_Fragment(FMars_Fragment_Countdown_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Countdown_Signals).OnRemainingChanged.Broadcast(Self, InState.Remaining);
    }
}
