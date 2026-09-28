class UMars_Processor_InteractPrompt_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_InteractPrompt_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_InteractPrompt);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_InteractPrompt_Requests& InRequests,
                       FMars_Fragment_InteractPrompt& InState)
    {
        auto Self = InHandle.As_InteractPrompt();

        auto Changed = false;
        for (const auto& UpdateRequest : InRequests.UpdateRequests)
        {
            if (InState.PromptText.ToString() != UpdateRequest.NewText.ToString())
            {
                InState.PromptText = UpdateRequest.NewText;
                Changed = true;
            }

            if (UpdateRequest.NewColor.IsSet() && InState.TextColor != UpdateRequest.NewColor.GetValue())
            {
                InState.TextColor = UpdateRequest.NewColor.GetValue();
                Changed = true;
            }
        }

        if (Changed && Self.Has_Fragment(FMars_Fragment_InteractPrompt_Signals))
        { Self.Get_Fragment(FMars_Fragment_InteractPrompt_Signals).OnChanged.Broadcast(Self); }

        // The display only re-renders on add/refresh/remove, so a changed prompt refreshes its display.
        if (Changed && Self.Has_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding))
        {
            const auto& Binding = Self.Get_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding);
            auto BoundDisplay = Binding.Display;
            if (ck::IsValid(BoundDisplay))
            { BoundDisplay.Request_RefreshPrompt(FMars_Request_InteractPromptDisplay_RefreshPrompt(Binding.Id)); }
        }

        // Swap-and-pop - InRequests is dead past this line.
        Self.Request_TryRemove(FMars_Fragment_InteractPrompt_Requests);
    }
}
