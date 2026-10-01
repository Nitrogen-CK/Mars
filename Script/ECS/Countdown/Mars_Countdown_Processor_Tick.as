// Drains one step every SecondsPerStep while charged, broadcasting each change; the last step removes the Running tag.
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
        auto Self = InHandle.As_Countdown();
        const auto SecondsPerStep = Self.Get_Fragment(FMars_Fragment_Countdown_Params).SecondsPerStep;

        InState.StepElapsed += float32(InDeltaT.Get_Seconds());

        const auto Previous = InState.Remaining;
        while (InState.Remaining > 0 && InState.StepElapsed >= SecondsPerStep)
        {
            InState.Remaining -= 1;
            InState.StepElapsed -= SecondsPerStep;
        }

        if (InState.Remaining <= 0)
        {
            InState.Remaining = 0;
            InState.StepElapsed = 0.0f;
            Self.Request_TryRemove(FMars_Tag_Countdown_Running);
        }

        if (InState.Remaining == Previous || Self.Has_Fragment(FMars_Fragment_Countdown_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Countdown_Signals).OnRemainingChanged.Broadcast(Self, InState.Remaining);
    }
}
