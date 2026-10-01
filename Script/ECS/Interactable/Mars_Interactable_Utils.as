namespace utils_interactable
{
    int32 Get_SortOrderFromChannel(FGameplayTag InChannel)
    {
        if (InChannel == GameplayTags::InteractionChannel_Mars_Use)
        { return 0; }

        return 999;
    }

    FCk_Handle_Interactable Create(FCk_Handle_Transform& InOwner, FMars_Interactable_Spec InParams)
    {
        FCk_Handle_Transform InteractableHandle;
        if (InParams.ProbeInfo.IsSet())
        {
            auto Probe = InParams.ProbeInfo.GetValue();
            // QueryOnly: traceable by the player's view ray, never a physical contact.
            Probe.ProbeSpec
                .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent)
                .Set_ContactParticipation(ECk_Probe_ContactParticipation::QueryOnly);
            InteractableHandle = utils_prefab::Create_ProbeNode(InOwner, Probe.ProbeShape, Probe.ProbeSpec, Probe.ProbeOffset).As_Transform();
        }
        else
        {
            InteractableHandle = utils_scene_node::Create(InOwner, FTransform::Identity).As_Transform();
        }

        auto Params = FMars_Fragment_Interactable_Params();
        for (const auto& Entry : InParams.Targets)
        { Params.TargetChannels.Add(Entry.InteractTargetSpec.Get_InteractionChannel()); }
        Params.FocusPriority = InParams.FocusPriority;

        InteractableHandle.Add_Fragment(Params);
        InteractableHandle.Add_Fragment(FMars_Feature_Interactable());

        auto InitialState = FMars_Fragment_Interactable();
        InitialState.EnableDisable = InParams.StartEnableDisable;
        InteractableHandle.Add_Fragment(InitialState);

        InteractableHandle.Add_Fragment(FMars_Tag_Interactable_NeedsSetup());
        InteractableHandle.Request_OverrideToSelf();

        auto Interactable = InteractableHandle.As_Interactable();

        auto Context = FMars_Fragment_InteractionContext();
        Context.Interactable = Interactable;
        Context.InteractableOwner = InOwner;

        for (const auto& Entry : InParams.Targets)
        {
            auto InteractTarget = utils_interact_target::Add(InteractableHandle, Entry.InteractTargetSpec);
            auto TargetHandle = InteractTarget.H();
            InteractTarget.Request_OverrideToSelf();
            TargetHandle.Add_Fragment(Context);

            if (Entry.InteractPromptSpec.IsSet())
            {
                auto PromptSpec = Entry.InteractPromptSpec.GetValue();
                PromptSpec.SortOrder = Get_SortOrderFromChannel(Entry.InteractTargetSpec.Get_InteractionChannel());
                PromptSpec.IsTimedInteraction =
                    Entry.InteractTargetSpec.Get_CompletionPolicy() != ECk_Interaction_CompletionPolicy::Instant;
                utils_interact_prompt::Add(TargetHandle, PromptSpec);
            }

            auto InteractionStateClass = Entry.InteractionStateClass.Get();
            if (ck::EnsureIfNot(ck::IsValid(InteractionStateClass),
                f"Invalid Interaction State supplied to Interact Target {TargetHandle.ToString()} on [{InOwner.ToString()}]"))
            { continue; }

            auto TargetSm = utils_state_machine::Add(TargetHandle, FCk_StateMachine_Spec(UMars_SmState_Interactable_Idle));
            TargetSm.Request_AddOverrideState(InteractionStateClass);
        }

        return Interactable;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_InteractTarget Get_InteractTarget(const FCk_Handle_Interactable& Self, FGameplayTag InChannelTag)
{
    return utils_interact_target::TryGet(Self, InChannelTag);
}

mixin TArray<FCk_Handle_InteractTarget> Get_AllInteractTargets(const FCk_Handle_Interactable& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Interactable_Params);
    auto Result = TArray<FCk_Handle_InteractTarget>();
    for (const auto& Channel : Params.TargetChannels)
    {
        auto Target = utils_interact_target::TryGet(Self, Channel);
        if (ck::IsValid(Target))
        { Result.Add(Target); }
    }
    return Result;
}

mixin int32 Get_FocusPriority(const FCk_Handle_Interactable& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Interactable_Params).FocusPriority;
}

mixin ECk_EnableDisable Get_EnableDisable(const FCk_Handle_Interactable& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Interactable).EnableDisable;
}

mixin bool Get_IsFocused(const FCk_Handle_Interactable& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Interactable).IsFocused;
}

mixin FCk_Handle Get_CurrentFocuser(const FCk_Handle_Interactable& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Interactable).CurrentFocuser;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Focus(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_Focus& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.FocusRequests.Add(InRequest);
}

mixin void Request_Unfocus(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_Unfocus& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.UnfocusRequests.Add(InRequest);
}

mixin void Request_SetEnableDisable(FCk_Handle_Interactable& Self, ECk_EnableDisable InEnableDisable)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.SetEnableDisableRequests.Add(FMars_Request_Interactable_SetEnableDisable(InEnableDisable));
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnFocused(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnFocused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    Fragment.OnFocused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFocused(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnFocused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnFocused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnUnfocused(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnUnfocused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    Fragment.OnUnfocused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnUnfocused(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnUnfocused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnUnfocused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnEnableDisableChanged(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnEnableDisableChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    Fragment.OnEnableDisableChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEnableDisableChanged(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnEnableDisableChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnEnableDisableChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnInteractionStarted(FCk_Handle_Interactable& Self, FGameplayTag InChannel, FMars_Delegate_Interactable_OnInteractionStarted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    for (int32 Index = 0; Index < Fragment.ChanneledOnInteractionStarted.Num(); ++Index)
    {
        if (Fragment.ChanneledOnInteractionStarted[Index].Channel == InChannel)
        {
            Fragment.ChanneledOnInteractionStarted[Index].Delegates.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
            return;
        }
    }

    auto NewBinding = FMars_Interactable_ChanneledStartedBinding();
    NewBinding.Channel = InChannel;
    NewBinding.Delegates.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    Fragment.ChanneledOnInteractionStarted.Add(NewBinding);
}

mixin void UnbindFrom_OnInteractionStarted(FCk_Handle_Interactable& Self, FGameplayTag InChannel, FMars_Delegate_Interactable_OnInteractionStarted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    auto& Fragment = Self.Get_Fragment(FMars_Fragment_Interactable_Signals);
    for (int32 Index = 0; Index < Fragment.ChanneledOnInteractionStarted.Num(); ++Index)
    {
        if (Fragment.ChanneledOnInteractionStarted[Index].Channel == InChannel)
        {
            Fragment.ChanneledOnInteractionStarted[Index].Delegates.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
            return;
        }
    }
}

mixin void BindTo_OnInteractionFinished(FCk_Handle_Interactable& Self, FGameplayTag InChannel, FMars_Delegate_Interactable_OnInteractionFinished InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    for (int32 Index = 0; Index < Fragment.ChanneledOnInteractionFinished.Num(); ++Index)
    {
        if (Fragment.ChanneledOnInteractionFinished[Index].Channel == InChannel)
        {
            Fragment.ChanneledOnInteractionFinished[Index].Delegates.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
            return;
        }
    }

    auto NewBinding = FMars_Interactable_ChanneledFinishedBinding();
    NewBinding.Channel = InChannel;
    NewBinding.Delegates.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    Fragment.ChanneledOnInteractionFinished.Add(NewBinding);
}

mixin void UnbindFrom_OnInteractionFinished(FCk_Handle_Interactable& Self, FGameplayTag InChannel, FMars_Delegate_Interactable_OnInteractionFinished InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    auto& Fragment = Self.Get_Fragment(FMars_Fragment_Interactable_Signals);
    for (int32 Index = 0; Index < Fragment.ChanneledOnInteractionFinished.Num(); ++Index)
    {
        if (Fragment.ChanneledOnInteractionFinished[Index].Channel == InChannel)
        {
            Fragment.ChanneledOnInteractionFinished[Index].Delegates.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
            return;
        }
    }
}
