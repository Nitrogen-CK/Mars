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

        const auto HasRequest = InRequests.SetRunningRequests.Num() > 0;
        auto TargetRunState = EMars_Oscillator_RunState::Stopped;
        if (HasRequest)
        { TargetRunState = InRequests.SetRunningRequests.Last().RunState; }

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Oscillator_Requests);

        const auto WasRunning = InState.State == EMars_Oscillator_State::Running;
        const auto Running = TargetRunState == EMars_Oscillator_RunState::Running;
        if (HasRequest == false || WasRunning == Running)
        { return; }

        // A caught swing is not running, so a stop never reaches it here; a start releases it.
        InState.State = Running ? EMars_Oscillator_State::Running : EMars_Oscillator_State::Stopped;

        if (Self.Has_Fragment(FMars_Fragment_Oscillator_Signals))
        { Self.Get_Fragment(FMars_Fragment_Oscillator_Signals).OnRunningChanged.Broadcast(Self, TargetRunState); }
    }
}
