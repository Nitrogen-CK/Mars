namespace utils_fphands
{
    // The gloves of InPlayer, hanging off InSpec.HandNode. The phase is driven by a Hands state machine
    // (UMars_SmState_Hands_Rest as its initial state) whose context is InPlayer. A spec that fails Validate() adds nothing.
    FCk_Handle_FPHands Add(FCk_Handle& InPlayer, FMars_FPHands_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[FPHands] [{InPlayer.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_FPHands(); }

        auto Params = FMars_Fragment_FPHands_Params();
        Params.Spec = InSpec;

        // The player composes its gait before its hands; a missing gait only disables the arm swing.
        if (InPlayer.Is_Gait())
        { Params.Gait = InPlayer.As_Gait(); }

        InPlayer.Add_Fragment(FMars_Feature_FPHands());
        InPlayer.Add_Fragment(Params);
        InPlayer.Add_Fragment(FMars_Fragment_FPHands());
        return InPlayer.As_FPHands();
    }

    EMars_FPHands_ReachKind Get_ReachKind(ECk_Interaction_CompletionPolicy InCompletionPolicy)
    {
        if (InCompletionPolicy == ECk_Interaction_CompletionPolicy::Instant)
        { return EMars_FPHands_ReachKind::Grab; }

        return EMars_FPHands_ReachKind::Hold;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_FPHands_Phase Get_Phase(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).PhaseState.Phase;
}

mixin float32 Get_PhaseTime(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).PhaseState.PhaseTime;
}

mixin float32 Get_ReleaseFromAlpha(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).PhaseState.ReleaseFromAlpha;
}

mixin FMars_FPHands_PhaseState Get_PhaseState(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).PhaseState;
}

mixin TOptional<FMars_FPHands_ReachTarget> Get_Target(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Reach.Target;
}

// Unset when the last reach served no interaction.
mixin TOptional<FCk_Handle_InteractTarget> Get_ReachInteractTarget(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Reach.InteractTarget;
}

// InTarget is the interact target of the gloves' current (or last) reach.
mixin bool Get_IsReachTarget(const FCk_Handle_FPHands& Self, const FCk_Handle_InteractTarget& InTarget)
{
    const auto& Reach = Self.Get_Fragment(FMars_Fragment_FPHands).Reach;
    return Reach.InteractTarget.IsSet() && Reach.InteractTarget.GetValue() == InTarget;
}

mixin ECk_Interaction_CompletionPolicy Get_CompletionPolicy(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Reach.CompletionPolicy;
}

mixin TOptional<FMars_FPHands_ReachTarget> Get_FocusTarget(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Focus.Target;
}

mixin float32 Get_FocusAlpha(const FCk_Handle_FPHands& Self, EMars_Hand InHand)
{
    const auto& Focus = Self.Get_Fragment(FMars_Fragment_FPHands).Focus;
    if (InHand == EMars_Hand::Right)
    { return Focus.Alpha_R; }

    return Focus.Alpha_L;
}

mixin FMars_FPHands_Hold Get_Hold(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Hold;
}

mixin FMars_FPHands_Hold Get_PushHold(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Push.Hold;
}

mixin EMars_LaunchKind Get_PushKind(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Push.Kind;
}

mixin FCk_Handle_Transform Get_HandNode(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands_Params).Spec.HandNode;
}

mixin const FMars_FPHands_Spec& Get_Spec(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands_Params).Spec;
}

// A free glove's arm swing this frame in the hand node's frame: the gait's stride swing, opposite per glove; the glove
// swinging forward lifts. Zero without a gait.
mixin FVector Get_ArmSwing(const FCk_Handle_FPHands& Self, EMars_Hand InHand)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_FPHands_Params);
    if (ck::Is_NOT_Valid(Params.Gait))
    { return FVector::ZeroVector; }

    const auto Side = InHand == EMars_Hand::Right ? 1.0f : -1.0f;
    const auto Swing = Math::Sin(Params.Gait.Get_Phase()) * Params.Gait.Get_Amount() * Side;
    const auto& ArmSwing = Params.Spec.ArmSwing;
    return FVector(ArmSwing.Cm * Swing, 0.0, ArmSwing.LiftCm * Math::Max(Swing, 0.0f));
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetPhase(FCk_Handle_FPHands& Self, const FMars_Request_FPHands_SetPhase& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Requests);
    Requests.SetPhaseRequests.Add(InRequest);
}

mixin void Request_StartReach(FCk_Handle_FPHands& Self, const FMars_Request_FPHands_StartReach& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Requests);
    Requests.StartReachRequests.Add(InRequest);
}

mixin void Request_StartPush(FCk_Handle_FPHands& Self, const FMars_Request_FPHands_StartPush& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Requests);
    Requests.StartPushRequests.Add(InRequest);
}

mixin void Request_Release(FCk_Handle_FPHands& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Requests);
    Requests.ReleaseRequests.Add(FMars_Request_FPHands_Release());
}

mixin void Request_SetFocus(FCk_Handle_FPHands& Self, const FMars_Request_FPHands_SetFocus& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Requests);
    Requests.SetFocusRequests.Add(InRequest);
}

mixin void Request_SetHold(FCk_Handle_FPHands& Self, const FMars_Request_FPHands_SetHold& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Requests);
    Requests.SetHoldRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnReachRequested(FCk_Handle_FPHands& Self, FMars_Delegate_FPHands_OnReachRequested InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Signals);
    Fragment.OnReachRequested.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReachRequested(FCk_Handle_FPHands& Self, FMars_Delegate_FPHands_OnReachRequested InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FPHands_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReachTargetLost(FCk_Handle_FPHands& Self, FMars_Delegate_FPHands_OnReachTargetLost InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Signals);
    Fragment.OnReachTargetLost.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReachTargetLost(FCk_Handle_FPHands& Self, FMars_Delegate_FPHands_OnReachTargetLost InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FPHands_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPushRequested(FCk_Handle_FPHands& Self, FMars_Delegate_FPHands_OnPushRequested InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Signals);
    Fragment.OnPushRequested.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPushRequested(FCk_Handle_FPHands& Self, FMars_Delegate_FPHands_OnPushRequested InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FPHands_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPushRequested.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPhaseChanged(FCk_Handle_FPHands& Self, FMars_Delegate_FPHands_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FPHands_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_FPHands& Self, FMars_Delegate_FPHands_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FPHands_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
