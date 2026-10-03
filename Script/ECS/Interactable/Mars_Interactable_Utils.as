// Stateless CanInteractWith predicate for every RequiresFreeHands target, bound from the CDO. The source is the player
// whose resolver or StartInteraction asks.
UCLASS()
class UMars_Interactable_FreeHandsPolicy : UObject
{
    UFUNCTION()
    void OnCanInteractWith(FCk_Handle_InteractTarget InTarget, FCk_Handle InInteractSource, FCk_Handle InInteractInstigator, bool& OutResult)
    { OutResult = utils_interactable::Get_HandsAreFree(InInteractSource); }
}

namespace utils_interactable
{
    // The blocked reason a RequiresFreeHands prompt shows while the focuser holds an item.
    FText Get_HandsFullText()
    {
        return FText::FromString("Hands full");
    }

    // Nothing in hand. An entity without HeldItem (tests, an NPC) has free hands.
    bool Get_HandsAreFree(const FCk_Handle& InEntity)
    {
        const auto HeldItem = InEntity.As_HeldItem(ECk_SanityCheck::UnChecked);
        return ck::Is_NOT_Valid(HeldItem) || ck::Is_NOT_Valid(HeldItem.Get_CurrentItem());
    }

    // Composes the interactable as a child of InOwner: a probe node when InSpec.ProbeInfo is set, else a transform-only
    // node, with one InteractTarget (and its prompt and per-interaction state machine) per spec target. A rejected spec
    // ensures and returns an invalid handle with nothing composed.
    FCk_Handle_Interactable Create(FCk_Handle_Transform& InOwner, FMars_Interactable_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Interactable] [{InOwner.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Interactable(); }

        FCk_Handle_Transform InteractableHandle;
        if (InSpec.ProbeInfo.IsSet())
        {
            auto Probe = InSpec.ProbeInfo.GetValue();
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
        for (const auto& Entry : InSpec.Targets)
        { Params.TargetChannels.Add(Entry.InteractTargetSpec.Get_InteractionChannel()); }
        Params.FocusPriority = InSpec.FocusPriority;

        InteractableHandle.Add_Fragment(Params);
        InteractableHandle.Add_Fragment(FMars_Feature_Interactable());

        auto InitialState = FMars_Fragment_Interactable();
        InitialState.EnableDisable = InSpec.StartEnableDisable;
        InteractableHandle.Add_Fragment(InitialState);

        InteractableHandle.Add_Fragment(FMars_Tag_Interactable_NeedsSetup());
        InteractableHandle.Request_OverrideToSelf();

        auto Interactable = InteractableHandle.As_Interactable();

        auto Context = FMars_Fragment_InteractionContext();
        Context.Interactable = Interactable;
        Context.InteractableOwner = InOwner;

        TSubclassOf<UMars_Interactable_FreeHandsPolicy> FreeHandsPolicyClass = UMars_Interactable_FreeHandsPolicy;
        auto FreeHandsPolicy = FreeHandsPolicyClass.GetDefaultObject();

        for (const auto& Entry : InSpec.Targets)
        {
            auto TargetSpec = Entry.InteractTargetSpec;
            if (Entry.RequiresFreeHands)
            { TargetSpec.Set_CustomCanInteractWithDynamic(FCk_Delegate_InteractTarget_CanInteractWith(FreeHandsPolicy, n"OnCanInteractWith")); }

            auto InteractTarget = utils_interact_target::Add(InteractableHandle, TargetSpec);
            InteractTarget.Request_OverrideToSelf();
            InteractTarget.Add_Fragment(Context);

            if (Entry.RequiresFreeHands)
            { InteractTarget.Add_Fragment(FMars_Tag_InteractTarget_RequiresFreeHands()); }

            if (Entry.InteractPromptSpec.IsSet())
            { utils_interact_prompt::Add(InteractTarget, Entry.InteractPromptSpec.GetValue()); }

            auto TargetSm = utils_state_machine::Add(InteractTarget, FCk_StateMachine_Spec(UMars_SmState_Interactable_Idle));
            TargetSm.Request_AddOverrideState(Entry.InteractionStateClass.Get());
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
    return ck::IsValid(Self.Get_Fragment(FMars_Fragment_Interactable).Focuser);
}

// Invalid when not focused.
mixin FCk_Handle Get_CurrentFocuser(const FCk_Handle_Interactable& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Interactable).Focuser;
}

// The source of the most recent interaction started on InTarget; invalid when the most recent interaction started on
// this interactable was on another target, or none has started.
mixin FCk_Handle Get_InitiatorOn(const FCk_Handle_Interactable& Self, const FCk_Handle& InTarget)
{
    const auto LastStarted = Self.Get_Fragment(FMars_Fragment_Interactable).LastStarted;
    if (LastStarted.Target != InTarget)
    { return FCk_Handle(); }

    return LastStarted.Initiator;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Focus(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_Focus& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.FocusedBy), f"[Interactable] [{Self.ToString()}] was asked to focus for an invalid focuser"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.FocusChangeRequests.Add(FMars_Interactable_FocusChangeRequest(EMars_Interactable_FocusChange::Focus, InRequest.FocusedBy));
}

mixin void Request_Unfocus(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_Unfocus& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.FocusChangeRequests.Add(FMars_Interactable_FocusChangeRequest(EMars_Interactable_FocusChange::Unfocus, InRequest.UnfocusedBy));
}

mixin void Request_SetEnableDisable(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_SetEnableDisable& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.SetEnableDisableRequests.Add(InRequest);
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
