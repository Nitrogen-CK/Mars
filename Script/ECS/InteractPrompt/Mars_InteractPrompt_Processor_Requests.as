// Drains UpdateText, then SetBlocked, then SetInteraction, then broadcasts OnChanged and refreshes the display the prompt
// is on, once, if anything changed. Text, colour and blocked state count as changed only when the drain ends somewhere
// other than where it started; every SetInteraction counts (the widget re-renders the hold bar from it).
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
                       FMars_Fragment_InteractPrompt& InPromptComp)
    {
        auto Self = InHandle.As_InteractPrompt();

        TArray<FMars_Request_InteractPrompt_UpdateText> UpdateRequests = InRequests.UpdateRequests;
        TArray<FMars_Request_InteractPrompt_SetBlocked> SetBlockedRequests = InRequests.SetBlockedRequests;
        TArray<FMars_Request_InteractPrompt_SetInteraction> SetInteractionRequests = InRequests.SetInteractionRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_InteractPrompt_Requests);

        const auto StartText = InPromptComp.PromptText.ToString();
        const auto StartColor = InPromptComp.TextColor;
        const auto StartBlocked = Get_BlockedKey(InPromptComp.BlockedText);

        for (const auto& UpdateRequest : UpdateRequests)
        {
            InPromptComp.PromptText = UpdateRequest.NewText;
            if (UpdateRequest.NewColor.IsSet())
            { InPromptComp.TextColor = UpdateRequest.NewColor.GetValue(); }
        }

        for (const auto& SetBlockedRequest : SetBlockedRequests)
        { InPromptComp.BlockedText = SetBlockedRequest.BlockedText; }

        for (const auto& SetInteractionRequest : SetInteractionRequests)
        { InPromptComp.CurrentInteraction = SetInteractionRequest.Interaction; }

        const auto Changed = SetInteractionRequests.Num() > 0
            || InPromptComp.PromptText.ToString() != StartText
            || InPromptComp.TextColor != StartColor
            || Get_BlockedKey(InPromptComp.BlockedText) != StartBlocked;
        if (Changed == false)
        { return; }

        if (Self.Has_Fragment(FMars_Fragment_InteractPrompt_Signals))
        { Self.Get_Fragment(FMars_Fragment_InteractPrompt_Signals).OnChanged.Broadcast(Self); }

        // The display only re-renders on add / refresh / remove, so a changed prompt refreshes the display it is on.
        if (Self.Has_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding))
        {
            auto BoundDisplay = Self.Get_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding).Display;
            if (ck::IsValid(BoundDisplay))
            { BoundDisplay.Request_RefreshPrompt(FMars_Request_InteractPromptDisplay_RefreshPrompt(Self)); }
        }
    }

    // Blocked state as one comparable value: unset, or the reason text.
    private TOptional<FString> Get_BlockedKey(const TOptional<FText>& InBlockedText) const
    {
        if (InBlockedText.IsSet() == false)
        { return TOptional<FString>(); }

        return TOptional<FString>(InBlockedText.GetValue().ToString());
    }
}
