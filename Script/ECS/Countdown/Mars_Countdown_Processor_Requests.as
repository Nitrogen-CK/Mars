// A charge refills every step and restarts the current one, however many arrive in one drain.
class UMars_Processor_Countdown_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Countdown_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Countdown);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Countdown_Requests& InRequests,
                       FMars_Fragment_Countdown& InState)
    {
        auto Self = InHandle.As_Countdown();
        const auto HasCharge = InRequests.ChargeRequests.Num() > 0;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Countdown_Requests);

        if (HasCharge == false)
        { return; }

        const auto Previous = InState.Remaining;
        InState.Remaining = Self.Get_Steps();
        InState.StepElapsed = 0.0f;

        if (Self.Has_Fragment(FMars_Tag_Countdown_Running) == false)
        { Self.Add_Fragment(FMars_Tag_Countdown_Running()); }

        if (InState.Remaining == Previous || Self.Has_Fragment(FMars_Fragment_Countdown_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Countdown_Signals).OnRemainingChanged.Broadcast(Self, InState.Remaining);
    }
}
