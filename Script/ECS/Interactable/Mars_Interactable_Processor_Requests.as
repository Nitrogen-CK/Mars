// Drains focus changes in arrival order, then SetEnableDisable. Each focus change is applied and broadcast before the
// next one, so a listener reads the state its event describes. A Focus from the current focuser, and an Unfocus from
// anyone but the current focuser, change nothing and broadcast nothing.
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

        TArray<FMars_Interactable_FocusChangeRequest> FocusChangeRequests = InRequests.FocusChangeRequests;
        TArray<FMars_Request_Interactable_SetEnableDisable> SetEnableDisableRequests = InRequests.SetEnableDisableRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Interactable_Requests);

        for (const auto& Request : FocusChangeRequests)
        {
            if (Request.Change == EMars_Interactable_FocusChange::Focus)
            { ApplyFocus(Self, InState, Request.Focuser); }
            else
            { ApplyUnfocus(Self, InState, Request.Focuser); }
        }

        for (const auto& Request : SetEnableDisableRequests)
        {
            if (InState.EnableDisable == Request.EnableDisable)
            { continue; }

            InState.EnableDisable = Request.EnableDisable;
            if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals))
            { Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnEnableDisableChanged.Broadcast(Self, Request.EnableDisable); }
        }
    }

    private void ApplyFocus(FCk_Handle_Interactable& InSelf, FMars_Fragment_Interactable& InState, const FCk_Handle& InFocuser)
    {
        if (InState.Focuser == InFocuser)
        { return; }

        InState.Focuser = InFocuser;
        if (InSelf.Has_Fragment(FMars_Fragment_Interactable_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Interactable_Signals).OnFocused.Broadcast(InSelf, InFocuser); }
    }

    private void ApplyUnfocus(FCk_Handle_Interactable& InSelf, FMars_Fragment_Interactable& InState, const FCk_Handle& InUnfocuser)
    {
        // Compared by identity, not validity: a focuser destroyed while focusing still unfocuses itself.
        const auto IsFocused = InState.Focuser != FCk_Handle();
        if (IsFocused == false || InState.Focuser != InUnfocuser)
        { return; }

        InState.Focuser = FCk_Handle();
        if (InSelf.Has_Fragment(FMars_Fragment_Interactable_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Interactable_Signals).OnUnfocused.Broadcast(InSelf, InUnfocuser); }
    }
}
