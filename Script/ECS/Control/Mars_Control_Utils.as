namespace utils_control
{
    // InMover is optional: an invalid handle means the control moves nothing. Interaction and HoldSeconds are not
    // retained; the entity script builds its interact target from them (Make_InteractTarget).
    FCk_Handle_Control Add(FCk_Handle& InHandle, FMars_Control_Spec InParams, FCk_Handle_Mover InMover)
    {
        auto Params = FMars_Fragment_Control_Params();
        Params.Behavior = InParams.Behavior;
        Params.ActiveSeconds = InParams.ActiveSeconds;

        auto State = FMars_Fragment_Control();
        State.IsActive = InParams.StartActive;
        State.Mover = InMover;

        InHandle.Add_Fragment(FMars_Feature_Control());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Control_NeedsSetup());
        return InHandle.As_Control();
    }

    // The interactable target a control's entity script mounts: Instant or Timed(HoldSeconds) on the Use channel,
    // routed to UMars_SmState_Control_Engage.
    FMars_Interactable_TargetEntry Make_InteractTarget(FMars_Control_Spec InParams, FText InPromptText)
    {
        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        if (InParams.Interaction == EMars_Control_Interaction::Timed)
        {
            TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Timed);
            TargetSpec.Set_InteractionDuration(FCk_Time(InParams.HoldSeconds));
        }
        else
        { TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant); }

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = InPromptText;

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_Control_Engage;
        return Target;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsActive(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control).IsActive;
}

mixin FCk_Handle_Mover Get_Mover(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control).Mover;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Engage(FCk_Handle_Control& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.EngageRequest = FMars_Request_Control_Engage();
}

mixin void Request_SetActive(FCk_Handle_Control& Self, bool InActive)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.SetActiveRequest = FMars_Request_Control_SetActive(InActive);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnActiveChanged(FCk_Handle_Control& Self, FMars_Delegate_Control_OnActiveChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Control_Signals);
    Fragment.OnActiveChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnActiveChanged(FCk_Handle_Control& Self, FMars_Delegate_Control_OnActiveChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Control_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Control_Signals).OnActiveChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnEngaged(FCk_Handle_Control& Self, FMars_Delegate_Control_OnEngaged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Control_Signals);
    Fragment.OnEngaged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEngaged(FCk_Handle_Control& Self, FMars_Delegate_Control_OnEngaged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Control_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Control_Signals).OnEngaged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
