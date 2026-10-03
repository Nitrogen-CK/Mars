// The latest SetOpen wins; a RetryClose in the same drain is then moot (the SetOpen already decided). A close while the
// gate is open and its threshold occupied is deferred: the gate stays open until a RetryClose finds the threshold clear.
class UMars_Processor_Gate_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Gate_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Gate);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Gate_Requests& InRequests,
                       FMars_Fragment_Gate& InState)
    {
        auto Self = InHandle.As_Gate();

        const auto HasSetOpen = InRequests.SetOpenRequests.Num() > 0;
        auto TargetOpen = false;
        if (HasSetOpen)
        { TargetOpen = InRequests.SetOpenRequests.Last().Open; }

        const auto HasRetryClose = InRequests.RetryCloseRequests.Num() > 0;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Gate_Requests);

        if (HasSetOpen)
        {
            DoHandle_SetOpen(Self, InState, TargetOpen);
            return;
        }

        if (HasRetryClose && InState.IsCloseDeferred)
        { DoHandle_SetOpen(Self, InState, false); }
    }

    private void DoHandle_SetOpen(FCk_Handle_Gate& InGate, FMars_Fragment_Gate& InState, bool InOpen)
    {
        if (InOpen == false && InState.IsOpen && InGate.Get_IsThresholdOccupied())
        {
            InState.IsCloseDeferred = true;
            return;
        }

        InState.IsCloseDeferred = false;

        if (InState.IsOpen == InOpen)
        { return; }

        InState.IsOpen = InOpen;

        auto Mover = InState.MovingNode.As_Mover(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Mover))
        { Mover.Request_MoveTo(InOpen); }

        if (InGate.Has_Fragment(FMars_Fragment_Gate_Signals))
        { InGate.Get_Fragment(FMars_Fragment_Gate_Signals).OnOpenChanged.Broadcast(InGate, InOpen); }
    }
}
