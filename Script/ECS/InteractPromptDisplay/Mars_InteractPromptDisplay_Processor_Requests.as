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

        for (const auto& AddRequest : InRequests.AddRequests)
        { HandleAddRequest(Self, InState, AddRequest); }

        for (const auto& RefreshRequest : InRequests.RefreshRequests)
        { HandleRefreshRequest(Self, InState, RefreshRequest); }

        for (const auto& RemoveRequest : InRequests.RemoveRequests)
        { HandleRemoveRequest(Self, InState, RemoveRequest); }

        // Swap-and-pop - InRequests is dead past this line.
        Self.Request_TryRemove(FMars_Fragment_InteractPromptDisplay_Requests);
    }

    private void HandleAddRequest(
        FCk_Handle_InteractPromptDisplay& InDisplay,
        FMars_Fragment_InteractPromptDisplay& InState,
        const FMars_Request_InteractPromptDisplay_AddPrompt& InRequest)
    {
        if (ck::Is_NOT_Valid(InRequest.PromptHandle))
        { return; }

        const auto SlotKey = InRequest.PromptHandle.Get_SlotKeyFromPrompt();
        const auto SortOrder = InRequest.PromptHandle.Get_Fragment(FMars_Fragment_InteractPrompt).SortOrder;

        auto Entry = FMars_InteractPromptDisplay_Entry();
        Entry.PromptHandle = InRequest.PromptHandle;
        Entry.Id = InRequest.PreAssignedId;

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

        auto PromptHandle = InRequest.PromptHandle;
        auto& Binding = PromptHandle.AddOrGet_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding);
        Binding.Display = InDisplay;
        Binding.Id = Entry.Id;

        if (InDisplay.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals) == false)
        { return; }

        auto& Signals = InDisplay.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals);
        const auto SlotSortOrder = InState.Slots[SlotIndex].SortOrder;
        if (WasEmpty)
        { Signals.OnPromptAppeared.Broadcast(InDisplay, SlotKey, SlotSortOrder, InRequest.PromptHandle); }
        else
        { Signals.OnPromptUpdated.Broadcast(InDisplay, SlotKey, SlotSortOrder, InRequest.PromptHandle); }
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
            if (Slot.Stack[TopIndex].Id.Value != InRequest.Id.Value)
            { continue; }

            auto TopPrompt = Slot.Stack[TopIndex].PromptHandle;
            if (ck::Is_NOT_Valid(TopPrompt))
            {
                PruneInvalidTopEntries(Slot);

                if (Slot.Stack.IsEmpty())
                {
                    Broadcast_Removed(InDisplay, Slot.SlotKey, Slot.SortOrder, TopPrompt);
                    InState.Slots.RemoveAt(SlotIndex);
                }
                else
                { Broadcast_Updated(InDisplay, Slot.SlotKey, Slot.SortOrder, Slot.Stack.Last().PromptHandle); }
                return;
            }

            Broadcast_Updated(InDisplay, Slot.SlotKey, Slot.SortOrder, TopPrompt);
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
                if (Slot.Stack[EntryIndex].Id.Value != InRequest.Id.Value)
                { continue; }

                WasTop = EntryIndex == Slot.Stack.Num() - 1;
                RemovedPrompt = Slot.Stack[EntryIndex].PromptHandle;
                Slot.Stack.RemoveAt(EntryIndex);
                Found = true;
                break;
            }

            if (Found == false)
            { continue; }

            if (WasTop == false)
            { break; }

            PruneInvalidTopEntries(Slot);

            if (Slot.Stack.IsEmpty())
            {
                Broadcast_Removed(InDisplay, Slot.SlotKey, Slot.SortOrder, RemovedPrompt);
                InState.Slots.RemoveAt(SlotIndex);
            }
            else
            { Broadcast_Updated(InDisplay, Slot.SlotKey, Slot.SortOrder, Slot.Stack.Last().PromptHandle); }

            break;
        }
    }

    private void Broadcast_Removed(FCk_Handle_InteractPromptDisplay& InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals).OnPromptRemoved.Broadcast(InDisplay, InSlotKey, InSortOrder, InPrompt); }
    }

    private void Broadcast_Updated(FCk_Handle_InteractPromptDisplay& InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals).OnPromptUpdated.Broadcast(InDisplay, InSlotKey, InSortOrder, InPrompt); }
    }

    private void PruneInvalidTopEntries(FMars_InteractPromptDisplay_Slot& InSlot)
    {
        while (InSlot.Stack.IsEmpty() == false && ck::Is_NOT_Valid(InSlot.Stack.Last().PromptHandle))
        { InSlot.Stack.RemoveAt(InSlot.Stack.Num() - 1); }
    }
}
