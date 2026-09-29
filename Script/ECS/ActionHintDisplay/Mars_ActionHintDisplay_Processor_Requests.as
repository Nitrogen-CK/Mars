// Drains in one fixed order - Register, Update, Unregister, UnregisterByOwner, Suppress - so a suppress queued in
// the same frame as a register always sees that register's row and takes it under the watermark.
class UMars_Processor_ActionHintDisplay_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_ActionHintDisplay_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_ActionHintDisplay);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_ActionHintDisplay_Requests& InRequests,
                       FMars_Fragment_ActionHintDisplay& InState)
    {
        auto Self = InHandle.As_ActionHintDisplay();

        TArray<FMars_Request_ActionHintDisplay_Register> RegisterRequests = InRequests.RegisterRequests;
        TArray<FMars_Request_ActionHintDisplay_Update> UpdateRequests = InRequests.UpdateRequests;
        TArray<FMars_Request_ActionHintDisplay_Unregister> UnregisterRequests = InRequests.UnregisterRequests;
        TArray<FMars_Request_ActionHintDisplay_UnregisterByOwner> UnregisterByOwnerRequests = InRequests.UnregisterByOwnerRequests;
        TArray<FMars_Request_ActionHintDisplay_SetSuppressed> SuppressRequests = InRequests.SuppressRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_ActionHintDisplay_Requests);

        for (const auto& Request : RegisterRequests)
        { HandleRegisterRequest(Self, InState, Request); }

        for (const auto& Request : UpdateRequests)
        { HandleUpdateRequest(Self, InState, Request); }

        for (const auto& Request : UnregisterRequests)
        { HandleUnregisterRequest(Self, InState, Request); }

        for (const auto& Request : UnregisterByOwnerRequests)
        { HandleUnregisterByOwnerRequest(Self, InState, Request); }

        for (const auto& Request : SuppressRequests)
        { HandleSetSuppressedRequest(Self, InState, Request); }
    }

    private void HandleRegisterRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_Register& InRequest)
    {
        auto Entry = FMars_ActionHintDisplay_Entry();
        Entry.Id = InRequest.PreAssignedId;
        Entry.Spec = InRequest.Spec;
        InState.Hints.Add(Entry);

        if (IsRowHidden(InState, Entry.Id))
        { return; }

        Broadcast_Registered(InDisplay, Entry.Id, Entry.Spec);
    }

    private void HandleUpdateRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_Update& InRequest)
    {
        for (int32 Index = 0; Index < InState.Hints.Num(); ++Index)
        {
            if (InState.Hints[Index].Id.Value != InRequest.Id.Value)
            { continue; }

            auto Changed = false;
            auto& Spec = InState.Hints[Index].Spec;

            if (InRequest.NewText.IsSet() && Spec.Text.ToString() != InRequest.NewText.GetValue().ToString())
            {
                Spec.Text = InRequest.NewText.GetValue();
                Changed = true;
            }

            if (InRequest.NewHoldLabel.IsSet() && Spec.HoldLabel.ToString() != InRequest.NewHoldLabel.GetValue().ToString())
            {
                Spec.HoldLabel = InRequest.NewHoldLabel.GetValue();
                Changed = true;
            }

            if (Changed && IsRowHidden(InState, InRequest.Id) == false)
            { Broadcast_Updated(InDisplay, InState.Hints[Index].Id, InState.Hints[Index].Spec); }

            return;
        }
    }

    private void HandleUnregisterRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_Unregister& InRequest)
    {
        for (int32 Index = InState.Hints.Num() - 1; Index >= 0; --Index)
        {
            if (InState.Hints[Index].Id.Value != InRequest.Id.Value)
            { continue; }

            RemoveHintAt(InDisplay, InState, Index);
            return;
        }
    }

    private void HandleUnregisterByOwnerRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_UnregisterByOwner& InRequest)
    {
        for (int32 Index = InState.Hints.Num() - 1; Index >= 0; --Index)
        {
            if (InState.Hints[Index].Spec.OwnerKey != InRequest.OwnerKey)
            { continue; }

            RemoveHintAt(InDisplay, InState, Index);
        }
    }

    private void HandleSetSuppressedRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_SetSuppressed& InRequest)
    {
        if (InRequest.Suppressed)
        {
            InState.SuppressDepth += 1;
            if (InState.SuppressDepth != 1)
            { return; }

            InState.SuppressWatermark = InState.NextId;
            for (const auto& Entry : InState.Hints)
            {
                if (Entry.Id.Value < InState.SuppressWatermark)
                { Broadcast_Unregistered(InDisplay, Entry.Id); }
            }
            return;
        }

        if (InState.SuppressDepth == 0)
        { return; }

        InState.SuppressDepth -= 1;
        if (InState.SuppressDepth != 0)
        { return; }

        const auto ReleasedWatermark = InState.SuppressWatermark;
        InState.SuppressWatermark = -1;
        for (const auto& Entry : InState.Hints)
        {
            if (Entry.Id.Value < ReleasedWatermark)
            { Broadcast_Registered(InDisplay, Entry.Id, Entry.Spec); }
        }
    }

    private void RemoveHintAt(FCk_Handle_ActionHintDisplay& InDisplay, FMars_Fragment_ActionHintDisplay& InState, int32 InIndex)
    {
        const auto RemovedId = InState.Hints[InIndex].Id;
        const auto WasHidden = IsRowHidden(InState, RemovedId);
        InState.Hints.RemoveAt(InIndex);

        if (WasHidden == false)
        { Broadcast_Unregistered(InDisplay, RemovedId); }
    }

    private bool IsRowHidden(const FMars_Fragment_ActionHintDisplay& InState, FMars_ActionHint_ID InId)
    {
        return InState.SuppressDepth > 0 && InId.Value < InState.SuppressWatermark;
    }

    private void Broadcast_Registered(FCk_Handle_ActionHintDisplay& InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintRegistered.Broadcast(InDisplay, InId, InSpec); }
    }

    private void Broadcast_Unregistered(FCk_Handle_ActionHintDisplay& InDisplay, FMars_ActionHint_ID InId)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintUnregistered.Broadcast(InDisplay, InId); }
    }

    private void Broadcast_Updated(FCk_Handle_ActionHintDisplay& InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintUpdated.Broadcast(InDisplay, InId, InSpec); }
    }
}
