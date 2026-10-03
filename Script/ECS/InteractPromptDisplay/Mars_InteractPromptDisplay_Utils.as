namespace constants_interact_prompt_display
{
    const FName k_UseSlotKey = n"InteractChannel_Use";
}

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

// Every Use prompt shares one slot; any other prompt is slotted by its input action, so one button never renders two
// prompts.
mixin FName Get_SlotKeyFromPrompt(const FCk_Handle_InteractPrompt& Self)
{
    if (Self.Get_Channel() == GameplayTags::InteractionChannel_Mars_Use)
    { return constants_interact_prompt_display::k_UseSlotKey; }

    auto InputAction = Self.Get_InputAction();
    if (ck::EnsureIfNot(ck::IsValid(InputAction), f"[InteractPromptDisplay] prompt [{Self.ToString()}] has no loadable InputAction"))
    { return NAME_None; }

    return InputAction.GetName();
}

mixin TArray<FMars_InteractPromptDisplay_Slot> Get_Slots(const FCk_Handle_InteractPromptDisplay& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPromptDisplay).Slots;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_AddPrompt(
    FCk_Handle_InteractPromptDisplay& Self,
    const FMars_Request_InteractPromptDisplay_AddPrompt& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InteractPromptDisplay_Requests);
    Requests.AddRequests.Add(InRequest);
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
