namespace utils_interact_prompt
{
    FCk_Handle_InteractPrompt Add(FCk_Handle& InHandle, FMars_InteractPrompt_Spec InParams)
    {
        auto Params = FMars_Fragment_InteractPrompt_Params();
        Params.InputAction = InParams.InputAction;
        Params.SortOrder = InParams.SortOrder;
        Params.IsTimedInteraction = InParams.IsTimedInteraction;

        auto State = FMars_Fragment_InteractPrompt();
        State.PromptText = InParams.PromptText;
        State.TextColor = InParams.TextColor;

        InHandle.Add_Fragment(FMars_Feature_InteractPrompt());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_InteractPrompt();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin UInputAction Get_InputAction(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt_Params).InputAction.Get();
}

mixin FText Get_PromptText(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).PromptText;
}

mixin FLinearColor Get_PromptTextColor(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).TextColor;
}

mixin bool Get_IsTimedInteraction(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt_Params).IsTimedInteraction;
}

mixin FCk_Handle_Interaction Get_CurrentInteraction(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).CurrentInteraction;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_UpdateText(FCk_Handle_InteractPrompt& Self, const FMars_Request_InteractPrompt_UpdateText& InRequest)
{
    const auto& Fragment = Self.Get_Fragment(FMars_Fragment_InteractPrompt);
    const auto TextUnchanged = Fragment.PromptText.ToString() == InRequest.NewText.ToString();
    const auto ColorUnchanged = InRequest.NewColor.IsSet() == false || Fragment.TextColor == InRequest.NewColor.GetValue();
    if (TextUnchanged && ColorUnchanged)
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InteractPrompt_Requests);
    Requests.UpdateRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPromptChanged(FCk_Handle_InteractPrompt& Self, FMars_Delegate_InteractPrompt_OnChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_InteractPrompt_Signals);
    Fragment.OnChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPromptChanged(FCk_Handle_InteractPrompt& Self, FMars_Delegate_InteractPrompt_OnChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_InteractPrompt_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_InteractPrompt_Signals).OnChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
