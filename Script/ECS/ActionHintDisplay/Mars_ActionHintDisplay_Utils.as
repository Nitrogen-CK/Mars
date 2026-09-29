namespace utils_action_hint_display
{
    FCk_Handle_ActionHintDisplay Add(FCk_Handle& InHandle)
    {
        InHandle.Add_Fragment(FMars_Feature_ActionHintDisplay());
        InHandle.Add_Fragment(FMars_Fragment_ActionHintDisplay());
        return InHandle.As_ActionHintDisplay();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsHidden(const FCk_Handle_ActionHintDisplay& Self, FMars_ActionHint_ID InId)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_ActionHintDisplay);
    return State.SuppressDepth > 0 && InId.Value < State.SuppressWatermark;
}

// What a legend should show right now: suppressed rows filtered out, registration order preserved.
mixin TArray<FMars_ActionHintDisplay_Entry> Get_VisibleHints(const FCk_Handle_ActionHintDisplay& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_ActionHintDisplay);

    TArray<FMars_ActionHintDisplay_Entry> Visible;
    for (const auto& Entry : State.Hints)
    {
        if (State.SuppressDepth > 0 && Entry.Id.Value < State.SuppressWatermark)
        { continue; }

        Visible.Add(Entry);
    }
    return Visible;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// The id is assigned here, synchronously, so the caller can update or unregister before the register drains.
mixin FMars_ActionHint_ID Request_RegisterHint(
    FCk_Handle_ActionHintDisplay& Self,
    const FMars_Request_ActionHintDisplay_Register& InRequest)
{
    auto& State = Self.Get_Fragment(FMars_Fragment_ActionHintDisplay);

    auto AssignedId = FMars_ActionHint_ID();
    AssignedId.Value = State.NextId;
    State.NextId += 1;

    auto QueuedRequest = InRequest;
    QueuedRequest.PreAssignedId = AssignedId;

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.RegisterRequests.Add(QueuedRequest);

    return AssignedId;
}

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

// Skips the queue when the row already holds the requested values, so per-frame callers do not churn the fragment.
mixin void Request_UpdateHint(
    FCk_Handle_ActionHintDisplay& Self,
    const FMars_Request_ActionHintDisplay_Update& InRequest)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_ActionHintDisplay);
    for (const auto& Entry : State.Hints)
    {
        if (Entry.Id.Value != InRequest.Id.Value)
        { continue; }

        const auto TextUnchanged = InRequest.NewText.IsSet() == false
            || Entry.Spec.Text.ToString() == InRequest.NewText.GetValue().ToString();
        const auto HoldLabelUnchanged = InRequest.NewHoldLabel.IsSet() == false
            || Entry.Spec.HoldLabel.ToString() == InRequest.NewHoldLabel.GetValue().ToString();

        if (TextUnchanged && HoldLabelUnchanged)
        { return; }

        break;
    }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.UpdateRequests.Add(InRequest);
}

// Hides every row registered before the matching drain until the paired Request_ReleaseSuppress.
mixin void Request_Suppress(FCk_Handle_ActionHintDisplay& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.SuppressRequests.Add(FMars_Request_ActionHintDisplay_SetSuppressed(true));
}

mixin void Request_ReleaseSuppress(FCk_Handle_ActionHintDisplay& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ActionHintDisplay_Requests);
    Requests.SuppressRequests.Add(FMars_Request_ActionHintDisplay_SetSuppressed(false));
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
