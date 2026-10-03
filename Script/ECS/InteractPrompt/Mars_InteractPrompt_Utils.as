namespace utils_interact_prompt
{
    // Composes the prompt on InTarget; the channel and completion policy are read from the target. A rejected spec
    // ensures and returns an invalid handle.
    FCk_Handle_InteractPrompt Add(FCk_Handle_InteractTarget& InTarget, FMars_InteractPrompt_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[InteractPrompt] [{InTarget.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_InteractPrompt(); }

        auto Params = FMars_Fragment_InteractPrompt_Params();
        Params.InputAction = InSpec.InputAction;
        Params.Channel = utils_interact_target::Get_InteractionChannel(InTarget);
        Params.CompletionPolicy = utils_interact_target::Get_InteractionCompletionPolicy(InTarget);

        auto State = FMars_Fragment_InteractPrompt();
        State.PromptText = InSpec.PromptText;
        State.TextColor = InSpec.TextColor;

        InTarget.Add_Fragment(FMars_Feature_InteractPrompt());
        InTarget.Add_Fragment(Params);
        InTarget.Add_Fragment(State);
        return InTarget.As_InteractPrompt();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin UInputAction Get_InputAction(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt_Params).InputAction.Get();
}

mixin FGameplayTag Get_Channel(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt_Params).Channel;
}

mixin ECk_Interaction_CompletionPolicy Get_CompletionPolicy(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt_Params).CompletionPolicy;
}

mixin int32 Get_SortOrder(const FCk_Handle_InteractPrompt& Self)
{
    if (Self.Get_Channel() == GameplayTags::InteractionChannel_Mars_Use)
    { return constants_interact_prompt::k_UseSortOrder; }

    return constants_interact_prompt::k_OtherSortOrder;
}

mixin FText Get_PromptText(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).PromptText;
}

mixin FLinearColor Get_PromptTextColor(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).TextColor;
}

mixin bool Get_IsBlocked(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).BlockedText.IsSet();
}

// What the widget shows: the blocked reason while set, else the prompt text.
mixin FText Get_DisplayText(const FCk_Handle_InteractPrompt& Self)
{
    const auto& Fragment = Self.Get_Fragment(FMars_Fragment_InteractPrompt);
    if (Fragment.BlockedText.IsSet())
    { return Fragment.BlockedText.GetValue(); }

    return Fragment.PromptText;
}

mixin FLinearColor Get_DisplayTextColor(const FCk_Handle_InteractPrompt& Self)
{
    const auto& Fragment = Self.Get_Fragment(FMars_Fragment_InteractPrompt);
    if (Fragment.BlockedText.IsSet())
    { return constants_ui_colors::k_PromptText_Blocked; }

    return Fragment.TextColor;
}

mixin FCk_Handle_Interaction Get_CurrentInteraction(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).CurrentInteraction;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// The drain compares against the state it ends with, so a text that returns to the current one within a drain changes
// nothing.
mixin void Request_UpdateText(FCk_Handle_InteractPrompt& Self, const FMars_Request_InteractPrompt_UpdateText& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InteractPrompt_Requests);
    Requests.UpdateRequests.Add(InRequest);
}

mixin void Request_SetBlocked(FCk_Handle_InteractPrompt& Self, const FMars_Request_InteractPrompt_SetBlocked& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InteractPrompt_Requests);
    Requests.SetBlockedRequests.Add(InRequest);
}

mixin void Request_SetInteraction(FCk_Handle_InteractPrompt& Self, const FMars_Request_InteractPrompt_SetInteraction& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_InteractPrompt_Requests);
    Requests.SetInteractionRequests.Add(InRequest);
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
