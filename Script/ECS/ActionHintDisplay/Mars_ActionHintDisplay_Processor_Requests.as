// Drains in one fixed order - Register, Update, Unregister, UnregisterByOwner, Suppress - so a suppress queued in
// the same frame as a register always sees that register's row and takes it under the watermark, and an update or
// unregister queued right after Request_RegisterHint finds its row already registered.
//
// Rows are child entities of the display. Register fills a row's state from its Params and gives it the next Sequence;
// every removal broadcasts (while visible) and then destroys the row.
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
        auto Row = InRequest.Row;
        if (ck::Is_NOT_Valid(Row))
        {
            ck::Warning(f"[ActionHintDisplay] [{InDisplay.ToString()}] skipped a Register whose row was destroyed before it drained");
            return;
        }

        const auto Spec = Row.Get_Fragment(FMars_Fragment_ActionHintRow_Params).Spec;

        auto& RowState = Row.Get_Fragment(FMars_Fragment_ActionHintRow);
        RowState.Spec = Spec;
        RowState.Sequence = InState.NextSequence;
        InState.NextSequence += 1;

        InState.Hints.Add(Row);

        if (IsRowHidden(InState, Row))
        { return; }

        Broadcast_Registered(InDisplay, Row);
    }

    private void HandleUpdateRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_Update& InRequest)
    {
        if (InState.Hints.Contains(InRequest.Row) == false)
        { return; }

        auto Row = InRequest.Row;
        auto Changed = false;
        auto& Spec = Row.Get_Fragment(FMars_Fragment_ActionHintRow).Spec;

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

        if (Changed && IsRowHidden(InState, Row) == false)
        { Broadcast_Updated(InDisplay, Row); }
    }

    private void HandleUnregisterRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_Unregister& InRequest)
    {
        const auto Index = InState.Hints.FindIndex(InRequest.Row);
        if (Index < 0)
        { return; }

        RemoveHintAt(InDisplay, InState, Index);
    }

    private void HandleUnregisterByOwnerRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_UnregisterByOwner& InRequest)
    {
        for (int32 Index = InState.Hints.Num() - 1; Index >= 0; --Index)
        {
            if (InState.Hints[Index].Get_OwnerKey() != InRequest.OwnerKey)
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

            InState.SuppressWatermark = InState.NextSequence;
            for (const auto& Row : InState.Hints)
            {
                if (Row.Get_Sequence() < InState.SuppressWatermark)
                { Broadcast_Unregistered(InDisplay, Row); }
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
        for (const auto& Row : InState.Hints)
        {
            if (Row.Get_Sequence() < ReleasedWatermark)
            { Broadcast_Registered(InDisplay, Row); }
        }
    }

    private void RemoveHintAt(FCk_Handle_ActionHintDisplay& InDisplay, FMars_Fragment_ActionHintDisplay& InState, int32 InIndex)
    {
        auto RemovedRow = InState.Hints[InIndex];
        const auto WasHidden = IsRowHidden(InState, RemovedRow);
        InState.Hints.RemoveAt(InIndex);

        if (WasHidden == false)
        { Broadcast_Unregistered(InDisplay, RemovedRow); }

        utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(RemovedRow));
    }

    private bool IsRowHidden(const FMars_Fragment_ActionHintDisplay& InState, const FCk_Handle_ActionHintRow& InRow)
    {
        return InState.SuppressDepth > 0 && InRow.Get_Sequence() < InState.SuppressWatermark;
    }

    private void Broadcast_Registered(FCk_Handle_ActionHintDisplay& InDisplay, FCk_Handle_ActionHintRow InRow)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintRegistered.Broadcast(InDisplay, InRow); }
    }

    private void Broadcast_Unregistered(FCk_Handle_ActionHintDisplay& InDisplay, FCk_Handle_ActionHintRow InRow)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintUnregistered.Broadcast(InDisplay, InRow); }
    }

    private void Broadcast_Updated(FCk_Handle_ActionHintDisplay& InDisplay, FCk_Handle_ActionHintRow InRow)
    {
        if (InDisplay.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals))
        { InDisplay.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintUpdated.Broadcast(InDisplay, InRow); }
    }
}
