// Drains Add, then Refresh, then Remove. Entries are keyed by their prompt handle. A prompt carries
// FMars_Fragment_InteractPrompt_DisplayBinding from its first entry here until its last one is removed.
class UMars_Processor_InteractPromptDisplay_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_InteractPromptDisplay_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_InteractPromptDisplay);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_InteractPromptDisplay_Requests& InRequests,
                       FMars_Fragment_InteractPromptDisplay& InState)
    {
        auto Self = InHandle.As_InteractPromptDisplay();

        TArray<FMars_Request_InteractPromptDisplay_AddPrompt> AddRequests = InRequests.AddRequests;
        TArray<FMars_Request_InteractPromptDisplay_RefreshPrompt> RefreshRequests = InRequests.RefreshRequests;
        TArray<FMars_Request_InteractPromptDisplay_RemovePrompt> RemoveRequests = InRequests.RemoveRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_InteractPromptDisplay_Requests);

        for (const auto& AddRequest : AddRequests)
        { HandleAddRequest(Self, InState, AddRequest); }

        for (const auto& RefreshRequest : RefreshRequests)
        { HandleRefreshRequest(Self, InState, RefreshRequest); }

        for (const auto& RemoveRequest : RemoveRequests)
        { HandleRemoveRequest(Self, InState, RemoveRequest); }
    }

    // A prompt destroyed between its request and this drain is skipped.
    private void HandleAddRequest(
        FCk_Handle_InteractPromptDisplay& InDisplay,
        FMars_Fragment_InteractPromptDisplay& InState,
        const FMars_Request_InteractPromptDisplay_AddPrompt& InRequest)
    {
        if (ck::Is_NOT_Valid(InRequest.Prompt))
        { return; }

        const auto SlotKey = InRequest.Prompt.Get_SlotKeyFromPrompt();
        const auto SortOrder = InRequest.Prompt.Get_SortOrder();

        auto Entry = FMars_InteractPromptDisplay_Entry();
        Entry.PromptHandle = InRequest.Prompt;

        int32 SlotIndex = -1;
        for (int32 Index = 0; Index < InState.Slots.Num(); ++Index)
        {
            if (InState.Slots[Index].SlotKey == SlotKey)
            {
                SlotIndex = Index;
                break;
            }
        }

        if (SlotIndex == -1)
        {
            auto NewSlot = FMars_InteractPromptDisplay_Slot();
            NewSlot.SlotKey = SlotKey;
            NewSlot.SortOrder = SortOrder;

            auto InsertAt = InState.Slots.Num();
            for (int32 Index = 0; Index < InState.Slots.Num(); ++Index)
            {
                if (SortOrder < InState.Slots[Index].SortOrder)
                {
                    InsertAt = Index;
                    break;
                }
            }
            InState.Slots.Insert(NewSlot, InsertAt);
            SlotIndex = InsertAt;
        }

        const auto WasEmpty = InState.Slots[SlotIndex].Stack.Num() == 0;
        PruneInvalidTopEntries(InState.Slots[SlotIndex]);
        InState.Slots[SlotIndex].Stack.Add(Entry);

        auto PromptHandle = InRequest.Prompt;
        auto& Binding = PromptHandle.AddOrGet_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding);
        Binding.Display = InDisplay;

        if (WasEmpty)
        { Broadcast_Appeared(InDisplay, InState.Slots[SlotIndex], InRequest.Prompt); }
        else
        { Broadcast_Updated(InDisplay, InState.Slots[SlotIndex], InRequest.Prompt); }
    }

    private void HandleRefreshRequest(
        FCk_Handle_InteractPromptDisplay& InDisplay,
        FMars_Fragment_InteractPromptDisplay& InState,
        const FMars_Request_InteractPromptDisplay_RefreshPrompt& InRequest)
    {
        for (int32 SlotIndex = 0; SlotIndex < InState.Slots.Num(); ++SlotIndex)
        {
            auto& Slot = InState.Slots[SlotIndex];
            if (Slot.Stack.IsEmpty())
            { continue; }

            const auto TopIndex = Slot.Stack.Num() - 1;
            if (Slot.Stack[TopIndex].PromptHandle != InRequest.Prompt)
            { continue; }

            auto TopPrompt = Slot.Stack[TopIndex].PromptHandle;
            if (ck::Is_NOT_Valid(TopPrompt))
            {
                PruneInvalidTopEntries(Slot);

                if (Slot.Stack.IsEmpty())
                {
                    Broadcast_Removed(InDisplay, Slot, TopPrompt);
                    InState.Slots.RemoveAt(SlotIndex);
                }
                else
                { Broadcast_Updated(InDisplay, Slot, Slot.Stack.Last().PromptHandle); }
                return;
            }

            Broadcast_Updated(InDisplay, Slot, TopPrompt);
            return;
        }
    }

    private void HandleRemoveRequest(
        FCk_Handle_InteractPromptDisplay& InDisplay,
        FMars_Fragment_InteractPromptDisplay& InState,
        const FMars_Request_InteractPromptDisplay_RemovePrompt& InRequest)
    {
        for (int32 SlotIndex = InState.Slots.Num() - 1; SlotIndex >= 0; --SlotIndex)
        {
            auto& Slot = InState.Slots[SlotIndex];
            auto WasTop = false;
            auto Found = false;
            auto RemovedPrompt = FCk_Handle_InteractPrompt();

            for (int32 EntryIndex = Slot.Stack.Num() - 1; EntryIndex >= 0; --EntryIndex)
            {
                if (Slot.Stack[EntryIndex].PromptHandle != InRequest.Prompt)
                { continue; }

                WasTop = EntryIndex == Slot.Stack.Num() - 1;
                RemovedPrompt = Slot.Stack[EntryIndex].PromptHandle;
                Slot.Stack.RemoveAt(EntryIndex);
                Found = true;
                break;
            }

            if (Found == false)
            { continue; }

            if (WasTop)
            {
                PruneInvalidTopEntries(Slot);

                if (Slot.Stack.IsEmpty())
                {
                    Broadcast_Removed(InDisplay, Slot, RemovedPrompt);
                    InState.Slots.RemoveAt(SlotIndex);
                }
                else
                { Broadcast_Updated(InDisplay, Slot, Slot.Stack.Last().PromptHandle); }
            }

            Unbind_IfNoEntries(InDisplay, InState, RemovedPrompt);
            break;
        }
    }

    // A prompt's last entry on this display removed: it no longer refreshes this display.
    private void Unbind_IfNoEntries(
        const FCk_Handle_InteractPromptDisplay& InDisplay,
        const FMars_Fragment_InteractPromptDisplay& InState,
        FCk_Handle_InteractPrompt InPrompt)
    {
        if (ck::Is_NOT_Valid(InPrompt) || InPrompt.Has_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding) == false)
        { return; }

        for (const auto& Slot : InState.Slots)
        {
            for (const auto& Entry : Slot.Stack)
            {
                if (Entry.PromptHandle == InPrompt)
                { return; }
            }
        }

        if (InPrompt.Get_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding).Display != InDisplay)
        { return; }

        auto Prompt = InPrompt;
        Prompt.Request_TryRemove(FMars_Fragment_InteractPrompt_DisplayBinding);
    }

    private void Broadcast_Appeared(FCk_Handle_InteractPromptDisplay& InDisplay, const FMars_InteractPromptDisplay_Slot& InSlot, FCk_Handle_InteractPrompt InPrompt)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals).OnPromptAppeared.Broadcast(InDisplay, InSlot.SlotKey, InSlot.SortOrder, InPrompt); }
    }

    private void Broadcast_Removed(FCk_Handle_InteractPromptDisplay& InDisplay, const FMars_InteractPromptDisplay_Slot& InSlot, FCk_Handle_InteractPrompt InPrompt)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals).OnPromptRemoved.Broadcast(InDisplay, InSlot.SlotKey, InSlot.SortOrder, InPrompt); }
    }

    private void Broadcast_Updated(FCk_Handle_InteractPromptDisplay& InDisplay, const FMars_InteractPromptDisplay_Slot& InSlot, FCk_Handle_InteractPrompt InPrompt)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals).OnPromptUpdated.Broadcast(InDisplay, InSlot.SlotKey, InSlot.SortOrder, InPrompt); }
    }

    private void PruneInvalidTopEntries(FMars_InteractPromptDisplay_Slot& InSlot)
    {
        while (InSlot.Stack.IsEmpty() == false && ck::Is_NOT_Valid(InSlot.Stack.Last().PromptHandle))
        { InSlot.Stack.RemoveAt(InSlot.Stack.Num() - 1); }
    }
}
