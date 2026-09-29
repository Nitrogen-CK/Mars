class UMars_Processor_Oscillator_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Oscillator_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Oscillator);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Oscillator_Requests& InRequests,
                       FMars_Fragment_Oscillator& InState)
    {
        auto Self = InHandle.As_Oscillator();

        const auto HasRequest = InRequests.SetRunningRequest.IsSet();
        auto TargetRunning = false;
        if (HasRequest)
        { TargetRunning = InRequests.SetRunningRequest.GetValue().Running; }

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Oscillator_Requests);

        if (HasRequest == false || InState.IsRunning == TargetRunning)
        { return; }

        InState.IsRunning = TargetRunning;

        if (Self.Has_Fragment(FMars_Fragment_Oscillator_Signals))
        { Self.Get_Fragment(FMars_Fragment_Oscillator_Signals).OnRunningChanged.Broadcast(Self, TargetRunning); }
    }
}
