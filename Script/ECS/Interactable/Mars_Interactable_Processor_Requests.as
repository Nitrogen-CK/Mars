class UMars_Processor_Interactable_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Interactable_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Interactable);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Interactable_Requests& InRequests,
                       FMars_Fragment_Interactable& InState)
    {
        auto Self = InHandle.As_Interactable();

        for (const auto& FocusRequest : InRequests.FocusRequests)
        {
            InState.IsFocused = true;
            InState.CurrentFocuser = FocusRequest.FocusedBy;
            if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals))
            { Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnFocused.Broadcast(Self, FocusRequest.FocusedBy); }
        }

        for (const auto& UnfocusRequest : InRequests.UnfocusRequests)
        {
            InState.IsFocused = false;
            InState.CurrentFocuser = FCk_Handle();
            if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals))
            { Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnUnfocused.Broadcast(Self, UnfocusRequest.UnfocusedBy); }
        }

        for (const auto& EnableDisableRequest : InRequests.SetEnableDisableRequests)
        {
            if (InState.EnableDisable == EnableDisableRequest.EnableDisable)
            { continue; }

            InState.EnableDisable = EnableDisableRequest.EnableDisable;
            if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals))
            { Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnEnableDisableChanged.Broadcast(Self, EnableDisableRequest.EnableDisable); }
        }

        // Swap-and-pop - InRequests is dead past this line.
        Self.Request_TryRemove(FMars_Fragment_Interactable_Requests);
    }
}
