namespace utils_fphands
{
    // The gloves of InPlayer. The phase is driven by a Hands state machine (UMars_SmState_Hands_Rest as its initial state)
    // whose context is InPlayer; InHandNode is what the gloves hang off and what reaches are measured from.
    FCk_Handle_FPHands Add(FCk_Handle& InPlayer, FMars_FPHands_Spec InSpec, FCk_Handle_Transform InHandNode)
    {
        if (ck::EnsureIfNot(ck::IsValid(InHandNode), f"[FPHands] [{InPlayer.ToString()}] needs a valid hand node"))
        { return FCk_Handle_FPHands(); }

        auto Params = FMars_Fragment_FPHands_Params();
        Params.Spec = InSpec;
        Params.HandNode = InHandNode;

        // The player composes its gait before its hands; a missing gait only disables the arm swing.
        if (InPlayer.Is_Gait())
        { Params.Gait = InPlayer.As_Gait(); }

        InPlayer.Add_Fragment(FMars_Feature_FPHands());
        InPlayer.Add_Fragment(Params);
        InPlayer.Add_Fragment(FMars_Fragment_FPHands());
        return InPlayer.As_FPHands();
    }

    FVector Make_ArmSwing(const FCk_Handle_FPHands& InHands, float32 InSide)
    {
        const auto& Params = InHands.Get_Fragment(FMars_Fragment_FPHands_Params);
        if (ck::Is_NOT_Valid(Params.Gait))
        { return FVector::ZeroVector; }

        const auto Swing = Math::Sin(Params.Gait.Get_Phase()) * Params.Gait.Get_Amount() * InSide;
        return FVector(Params.Spec.ArmSwingCm * Swing, 0.0, Params.Spec.ArmSwingLiftCm * Math::Max(Swing, 0.0f));
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_FPHands_Phase Get_Phase(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Phase;
}

mixin float32 Get_PhaseTime(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).PhaseTime;
}

mixin float32 Get_ReleaseFromAlpha(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).ReleaseFromAlpha;
}

mixin FMars_FPHands_PhaseState Get_PhaseState(const FCk_Handle_FPHands& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_FPHands);
    return FMars_FPHands_PhaseState(State.Phase, State.PhaseTime, State.ReleaseFromAlpha, State.ReachFromAlpha);
}

mixin FMars_FPHands_ReachTarget Get_Target(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Target;
}

mixin FCk_Handle_InteractTarget Get_InteractTarget(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).InteractTarget;
}

mixin bool Get_IsInstant(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).IsInstant;
}

mixin FMars_FPHands_ReachTarget Get_FocusTarget(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).FocusTarget;
}

mixin float32 Get_FocusAlpha_L(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).FocusAlpha_L;
}

mixin float32 Get_FocusAlpha_R(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).FocusAlpha_R;
}

mixin FMars_FPHands_Hold Get_Hold(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Hold;
}

mixin FMars_FPHands_Hold Get_PushHold(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).PushHold;
}

mixin bool Get_PushIsThrow(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).PushIsThrow;
}

mixin FCk_Handle_Transform Get_HandNode(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands_Params).HandNode;
}

mixin const FMars_FPHands_Spec& Get_Spec(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands_Params).Spec;
}

// Free-hand arm swing this frame in the hand node's frame: the gait's stride swing, opposite per hand; the forward hand lifts.
mixin FVector Get_ArmSwing_Left(const FCk_Handle_FPHands& Self)
{
    return utils_fphands::Make_ArmSwing(Self, -1.0f);
}

mixin FVector Get_ArmSwing_Right(const FCk_Handle_FPHands& Self)
{
    return utils_fphands::Make_ArmSwing(Self, 1.0f);
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
