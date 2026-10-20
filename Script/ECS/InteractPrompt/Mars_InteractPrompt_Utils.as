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
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).BlockedReason != EMars_InteractPrompt_BlockedReason::None;
}

mixin EMars_InteractPrompt_BlockedReason Get_BlockedReason(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).BlockedReason;
}

// The prompt text; a blocked reason is worded by the prompt widget instead.
mixin FText Get_DisplayText(const FCk_Handle_InteractPrompt& Self)
{
    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).PromptText;
}

mixin FLinearColor Get_DisplayTextColor(const FCk_Handle_InteractPrompt& Self)
{
    if (Self.Get_IsBlocked())
    { return constants_ui_colors::k_PromptText_Blocked; }

    return Self.Get_Fragment(FMars_Fragment_InteractPrompt).TextColor;
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
