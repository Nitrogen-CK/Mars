namespace utils_action_hint_display
{
    FCk_Handle_ActionHintDisplay Add(FCk_Handle& InHandle)
    {
        InHandle.Add_Fragment(FMars_Feature_ActionHintDisplay());
        InHandle.Add_Fragment(FMars_Fragment_ActionHintDisplay());
        return InHandle.As_ActionHintDisplay();
    }

    // Suppression hides the rows registered before it was taken. A row whose register has not drained is never hidden.
    bool Get_IsRowHidden(const FMars_Fragment_ActionHintDisplay& InState, const FCk_Handle_ActionHintRow& InRow)
    {
        if (InState.SuppressWatermark.IsSet() == false)
        { return false; }

        const auto Sequence = InRow.Get_Sequence();
        return Sequence.IsSet() && Sequence.GetValue() < InState.SuppressWatermark.GetValue();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Row Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_ActionHint_Spec Get_Spec(const FCk_Handle_ActionHintRow& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ActionHintRow).Spec;
}

// Unset until the row's register drains; afterwards the display-wide registration order. Always set on a row a display
// signal hands out or Get_VisibleHints returns.
mixin TOptional<int64> Get_Sequence(const FCk_Handle_ActionHintRow& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ActionHintRow).Sequence;
}

mixin FName Get_OwnerKey(const FCk_Handle_ActionHintRow& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ActionHintRow).Spec.OwnerKey;
}

//--------------------------------------------------------------------------------------------------------------------------
// Display Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsHidden(const FCk_Handle_ActionHintDisplay& Self, const FCk_Handle_ActionHintRow& InRow)
{
    return utils_action_hint_display::Get_IsRowHidden(Self.Get_Fragment(FMars_Fragment_ActionHintDisplay), InRow);
}

// What a legend should show right now: suppressed rows filtered out, registration order preserved.
mixin TArray<FCk_Handle_ActionHintRow> Get_VisibleHints(const FCk_Handle_ActionHintDisplay& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_ActionHintDisplay);

    TArray<FCk_Handle_ActionHintRow> Visible;
    for (const auto& Row : State.Hints)
    {
        if (utils_action_hint_display::Get_IsRowHidden(State, Row))
        { continue; }

        Visible.Add(Row);
    }
    return Visible;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Mints the row synchronously - a child entity of the display carrying the spec - so the caller can update or unregister
// it before the register drains. The drain gives the row its Sequence.
mixin FCk_Handle_ActionHintRow Request_RegisterHint(
    FCk_Handle_ActionHintDisplay& Self,
    const FMars_ActionHint_Spec& InSpec)
{
    auto RowEntity = utils_entity_lifetime::Request_CreateEntity(Self);

    auto RowState = FMars_Fragment_ActionHintRow();
    RowState.Spec = InSpec;

    RowEntity.Add_Fragment(FMars_Feature_ActionHintRow());
    RowEntity.Add_Fragment(RowState);
    auto Row = RowEntity.As_ActionHintRow();

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.RegisterRequests.Add(FMars_Request_ActionHintDisplay_Register(Row));

    return Row;
}

// The row is destroyed by the drain that removes it.
mixin void Request_UnregisterHint(
    FCk_Handle_ActionHintDisplay& Self,
    const FMars_Request_ActionHintDisplay_Unregister& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.UnregisterRequests.Add(InRequest);
}

mixin void Request_UnregisterHintsByOwner(
    FCk_Handle_ActionHintDisplay& Self,
    const FMars_Request_ActionHintDisplay_UnregisterByOwner& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.UnregisterByOwnerRequests.Add(InRequest);
}

// Always queued: an update equal to the committed row may still revert a pending one. The drain skips no-op updates.
mixin void Request_UpdateHint(
    FCk_Handle_ActionHintDisplay& Self,
    const FMars_Request_ActionHintDisplay_Update& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.UpdateRequests.Add(InRequest);
}

// Hides every row registered before the matching drain until the paired Request_ReleaseSuppress.
mixin void Request_Suppress(FCk_Handle_ActionHintDisplay& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.SuppressRequests.Add(FMars_Request_ActionHintDisplay_SetSuppressed(EMars_ActionHintDisplay_Suppression::Suppress));
}

mixin void Request_ReleaseSuppress(FCk_Handle_ActionHintDisplay& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.SuppressRequests.Add(FMars_Request_ActionHintDisplay_SetSuppressed(EMars_ActionHintDisplay_Suppression::Release));
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHintRegistered(FCk_Handle_ActionHintDisplay& Self, FMars_Delegate_ActionHintDisplay_OnHintRegistered InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Signals);
    Fragment.OnHintRegistered.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHintRegistered(FCk_Handle_ActionHintDisplay& Self, FMars_Delegate_ActionHintDisplay_OnHintRegistered InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintRegistered.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHintUnregistered(FCk_Handle_ActionHintDisplay& Self, FMars_Delegate_ActionHintDisplay_OnHintUnregistered InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Signals);
    Fragment.OnHintUnregistered.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHintUnregistered(FCk_Handle_ActionHintDisplay& Self, FMars_Delegate_ActionHintDisplay_OnHintUnregistered InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintUnregistered.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHintUpdated(FCk_Handle_ActionHintDisplay& Self, FMars_Delegate_ActionHintDisplay_OnHintUpdated InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Signals);
    Fragment.OnHintUpdated.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHintUpdated(FCk_Handle_ActionHintDisplay& Self, FMars_Delegate_ActionHintDisplay_OnHintUpdated InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_ActionHintDisplay_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_ActionHintDisplay_Signals).OnHintUpdated.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
