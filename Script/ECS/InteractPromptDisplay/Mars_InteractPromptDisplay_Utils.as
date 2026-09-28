namespace utils_interact_prompt_display
{
    FCk_Handle_InteractPromptDisplay Add(FCk_Handle& InHandle)
    {
        InHandle.Add_Fragment(FMars_Feature_InteractPromptDisplay());
        InHandle.Add_Fragment(FMars_Fragment_InteractPromptDisplay());
        return InHandle.As_InteractPromptDisplay();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// Slot by channel (SortOrder carries the channel identity), so one button never renders two prompts.
mixin FName Get_SlotKeyFromPrompt(const FCk_Handle_InteractPrompt& Self)
{
    const auto& Fragment = Self.Get_Fragment(FMars_Fragment_InteractPrompt);
    if (Fragment.SortOrder == 0) { return n"InteractChannel_Use"; }

    auto InputAction = Fragment.InputAction.Get();
    if (ck::IsValid(InputAction))
    { return InputAction.GetName(); }

    return NAME_None;
}

mixin TArray<FMars_InteractPromptDisplay_Slot> Get_Slots(const FCk_Handle_InteractPromptDisplay& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPromptDisplay).Slots;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_InteractPromptDisplay_ID Request_AddPrompt(
    FCk_Handle_InteractPromptDisplay& Self,
    const FMars_Request_InteractPromptDisplay_AddPrompt& InRequest)
{
    auto& State = Self.Get_Fragment(FMars_Fragment_InteractPromptDisplay);

    auto AssignedId = FMars_InteractPromptDisplay_ID();
    AssignedId.Value = State.NextId;
    State.NextId += 1;

    auto QueuedRequest = InRequest;
    QueuedRequest.PreAssignedId = AssignedId;

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InteractPromptDisplay_Requests);
    Requests.AddRequests.Add(QueuedRequest);

    return AssignedId;
}

mixin void Request_RemovePrompt(
    FCk_Handle_InteractPromptDisplay& Self,
    const FMars_Request_InteractPromptDisplay_RemovePrompt& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InteractPromptDisplay_Requests);
    Requests.RemoveRequests.Add(InRequest);
}

mixin void Request_RefreshPrompt(
    FCk_Handle_InteractPromptDisplay& Self,
    const FMars_Request_InteractPromptDisplay_RefreshPrompt& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InteractPromptDisplay_Requests);
    Requests.RefreshRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPromptAppeared(FCk_Handle_InteractPromptDisplay& Self, FMars_Delegate_InteractPromptDisplay_OnPromptAppeared InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_InteractPromptDisplay_Signals);
    Fragment.OnPromptAppeared.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPromptAppeared(FCk_Handle_InteractPromptDisplay& Self, FMars_Delegate_InteractPromptDisplay_OnPromptAppeared InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals).OnPromptAppeared.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPromptRemoved(FCk_Handle_InteractPromptDisplay& Self, FMars_Delegate_InteractPromptDisplay_OnPromptRemoved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_InteractPromptDisplay_Signals);
    Fragment.OnPromptRemoved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPromptRemoved(FCk_Handle_InteractPromptDisplay& Self, FMars_Delegate_InteractPromptDisplay_OnPromptRemoved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals).OnPromptRemoved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPromptUpdated(FCk_Handle_InteractPromptDisplay& Self, FMars_Delegate_InteractPromptDisplay_OnPromptUpdated InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_InteractPromptDisplay_Signals);
    Fragment.OnPromptUpdated.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPromptUpdated(FCk_Handle_InteractPromptDisplay& Self, FMars_Delegate_InteractPromptDisplay_OnPromptUpdated InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_InteractPromptDisplay_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_InteractPromptDisplay_Signals).OnPromptUpdated.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
