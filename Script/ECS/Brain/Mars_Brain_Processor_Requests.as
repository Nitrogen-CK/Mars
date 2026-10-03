// The brain's request drain and the only writer of its world state: tasks and handlers ask through Request_SetFact, never
// utils_goap_world_state::Set_Value. The planner's enable toggle is immediate in CkGoap (a disabled planner keeps its plan
// and neither replans nor changes its active chain, so the leaf holds); a fact write is deferred by CkGoap, and an actual
// value change replans per OnWorldStateDirty, throttled by MinReplanIntervalSeconds.
class UMars_Processor_Brain_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Brain_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Brain);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Brain_Requests& InRequests)
    {
        auto Self = InHandle.As_Brain();

        TArray<FMars_Request_Brain_SetEnabled> SetEnabledRequests = InRequests.SetEnabledRequests;
        TArray<FMars_Request_Brain_SetFact> SetFactRequests = InRequests.SetFactRequests;

        // InRequests is invalid past this line; removing first lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Brain_Requests);

        for (const auto& Request : SetEnabledRequests)
        { HandleSetEnabled(Self, Request); }

        for (const auto& Request : SetFactRequests)
        { HandleSetFact(Self, Request); }
    }

    private void HandleSetEnabled(FCk_Handle_Brain& InSelf, const FMars_Request_Brain_SetEnabled& InRequest)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Brain);
        State.IsEnabled = InRequest.EnableDisable == ECk_EnableDisable::Enable;

        auto Planner = State.Planner;
        utils_goap_planner::Request_SetEnableToggle(Planner, InRequest.EnableDisable);
    }

    private void HandleSetFact(FCk_Handle_Brain& InSelf, const FMars_Request_Brain_SetFact& InRequest)
    {
        auto WorldState = InSelf.Get_Fragment(FMars_Fragment_Brain).WorldState;
        utils_goap_world_state::Set_Value(WorldState, InRequest.Key, InRequest.Value);
    }
}
