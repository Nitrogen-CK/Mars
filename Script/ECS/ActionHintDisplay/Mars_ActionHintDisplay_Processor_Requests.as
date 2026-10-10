// Drains in one fixed order - Register, Update, Unregister, UnregisterByOwner - so an update or unregister queued right
// after Request_RegisterHint finds its row already registered. Updates apply in queue order, each one compared with the
// row as the previous one left it.
//
// Rows are child entities of the display. Register gives a row the next Sequence; every removal broadcasts and then
// destroys the row.
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

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_ActionHintDisplay_Requests);

        for (const auto& Request : RegisterRequests)
        { HandleRegisterRequest(Self, InState, Request); }

        for (const auto& Request : UpdateRequests)
        { HandleUpdateRequest(Self, InState, Request); }

        for (const auto& Request : UnregisterRequests)
        { HandleUnregisterRequest(Self, InState, Request); }

        for (const auto& Request : UnregisterByOwnerRequests)
        { HandleUnregisterByOwnerRequest(Self, InState, Request); }
    }

    // The row is the display's own child, minted with the request; only the drain destroys it.
    private void HandleRegisterRequest(
        FCk_Handle_ActionHintDisplay& InDisplay,
        FMars_Fragment_ActionHintDisplay& InState,
        const FMars_Request_ActionHintDisplay_Register& InRequest)
    {
        auto Row = InRequest.Row;
        if (ck::EnsureIfNot(ck::IsValid(Row),
            f"[ActionHintDisplay] [{InDisplay.ToString()}] got a Register whose row was destroyed before it drained"))
        { return; }

        auto& RowState = Row.Get_Fragment(FMars_Fragment_ActionHintRow);
        RowState.Sequence = TOptional<int64>(InState.NextSequence);
        InState.NextSequence += 1;

        InState.Hints.Add(Row);
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

        if (Changed)
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

    private void RemoveHintAt(FCk_Handle_ActionHintDisplay& InDisplay, FMars_Fragment_ActionHintDisplay& InState, int32 InIndex)
    {
        auto RemovedRow = InState.Hints[InIndex];
        InState.Hints.RemoveAt(InIndex);

        Broadcast_Unregistered(InDisplay, RemovedRow);
        utils_entity_lifetime::Request_DestroyEntity(RemovedRow.H());
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
