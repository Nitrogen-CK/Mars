// The brain's request drain: SetEnabled -> SetFact, each kind in arrival order. It is the only writer of the brain's
// world state (D-A2): tasks and handlers ask through Request_SetFact, never utils_goap_world_state::Set_Value.
//   SetEnabled -> State.IsEnabled, and the planner's enable toggle (immediate in CkGoap; a disabled planner keeps its
//                 plan and neither replans nor changes its active chain, so the leaf holds)
//   SetFact    -> utils_goap_world_state::Set_Value (deferred by CkGoap; an actual value change dirties the world state
//                 and the planner replans per OnWorldStateDirty, throttled by MinReplanIntervalSeconds)
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

        // Swap-and-pop - InRequests is dead past this line. Removing first lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Brain_Requests);

        for (const auto& Request : SetEnabledRequests)
        { HandleSetEnabled(Self, Request); }

        for (const auto& Request : SetFactRequests)
        { HandleSetFact(Self, Request); }
    }

    private void HandleSetEnabled(FCk_Handle_Brain& InSelf, const FMars_Request_Brain_SetEnabled& InRequest)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Brain);
        State.IsEnabled = InRequest.Enabled;

        auto Planner = State.Planner;
        if (ck::Is_NOT_Valid(Planner))
        { return; }

        utils_goap_planner::Request_SetEnableToggle(Planner, InRequest.Enabled ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable);
    }

    private void HandleSetFact(FCk_Handle_Brain& InSelf, const FMars_Request_Brain_SetFact& InRequest)
    {
        auto WorldState = InSelf.Get_Fragment(FMars_Fragment_Brain).WorldState;
        if (ck::Is_NOT_Valid(WorldState))
        { return; }

        utils_goap_world_state::Set_Value(WorldState, InRequest.Key, InRequest.Value);
    }
}
