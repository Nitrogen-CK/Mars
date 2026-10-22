namespace utils_control
{
    // A pull axis whose on-screen projection is shorter than this (a unit axis pointing nearly at the viewer) has no
    // usable screen direction.
    const float64 k_MinScreenPullLength = 0.05;

    // InParams.Mover is optional: an invalid handle means the control moves nothing. The completion policy and HoldSeconds
    // are retained for Make_InteractTarget; a rejected spec ensures and returns an invalid handle.
    FCk_Handle_Control Add(FCk_Handle& InHandle, FMars_Control_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Control] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Control(); }

        auto Manipulation = InParams.Manipulation;
        Manipulation.PullAxis = InParams.Manipulation.PullAxis.GetSafeNormal();

        auto Params = FMars_Fragment_Control_Params();
        Params.CompletionPolicy = InParams.Interaction;
        Params.HoldSeconds = InParams.HoldSeconds;
        Params.Behavior = InParams.Behavior;
        Params.ActiveSeconds = InParams.ActiveSeconds;
        Params.Manipulation = Manipulation;

        auto State = FMars_Fragment_Control();
        State.IsActive = InParams.StartActive;
        State.Mover = InParams.Mover;

        InHandle.Add_Fragment(FMars_Feature_Control());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Control_NeedsSetup());
        return InHandle.As_Control();
    }

    // The look delta projected onto the control's on-screen pull direction, in the look delta's units (degrees of
    // would-be view rotation). InLookDelta is the camera intention (X yaw right+, Y pitch DOWN+). InPullWorld is the
    // pull axis in world space (zero = unknown). A pull axis that projects to (nearly) nothing on screen - zero, or
    // pointing at the viewer - falls back to raw pitch so the control stays usable.
    float32 Get_PullDegrees(const FVector& InPullWorld, const FTransform& InView, const FVector& InLookDelta)
    {
        const auto Right = InView.GetRotation().GetRightVector();
        const auto Up = InView.GetRotation().GetUpVector();
        auto Screen = FVector2D(InPullWorld.DotProduct(Right), -InPullWorld.DotProduct(Up));
        if (Screen.Size() < k_MinScreenPullLength)
        { return float32(InLookDelta.Y); }

        Screen.Normalize();
        return float32(InLookDelta.X * Screen.X + InLookDelta.Y * Screen.Y);
    }

    // 0..1 toward EngageAlpha in the pull's direction.
    float32 Get_ProgressTowardEngage(EMars_Control_PullDirection InDirection, float32 InAlpha, float32 InEngageAlpha)
    {
        const auto Travelled = InDirection == EMars_Control_PullDirection::TowardStart ? 1.0f - InAlpha : InAlpha;
        return Math::Clamp(Travelled / InEngageAlpha, 0.0f, 1.0f);
    }

    // Whether InAlpha is past EngageAlpha in the pull's direction.
    bool Get_HasCrossedEngage(EMars_Control_PullDirection InDirection, float32 InAlpha, float32 InEngageAlpha)
    {
        if (InDirection == EMars_Control_PullDirection::TowardStart)
        { return InAlpha <= 1.0f - InEngageAlpha; }

        return InAlpha >= InEngageAlpha;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Interact Target
//--------------------------------------------------------------------------------------------------------------------------

// The interactable target a control's entity script mounts on the Use channel, routed to UMars_SmState_Control_Engage once
// the interaction completes (AfterCompletion): Instant, Timed(HoldSeconds), or ManuallyCompleted (pulled; the Control's tick
// ends the interaction at EngageAlpha). The gloves grab an Instant control and hold a timed or pulled one. Working a control
// takes both hands (RequiresFreeHands). InPrompt is the caller's, input action included.
mixin FMars_Interactable_TargetEntry Make_InteractTarget(const FCk_Handle_Control& Self, FMars_InteractPrompt_Spec InPrompt)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Control_Params);

    auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
    TargetSpec.Set_CompletionPolicy(Params.CompletionPolicy);
    if (Params.CompletionPolicy == ECk_Interaction_CompletionPolicy::Timed)
    { TargetSpec.Set_InteractionDuration(FCk_Time(Params.HoldSeconds)); }

    auto Target = FMars_Interactable_TargetEntry();
    Target.InteractTargetSpec = TargetSpec;
    Target.InteractPromptSpec = InPrompt;
    Target.InteractionStateClass = UMars_SmState_Control_Engage;
    Target.RequiresFreeHands = true;
    Target.ReachKind = Params.CompletionPolicy == ECk_Interaction_CompletionPolicy::Instant
        ? EMars_FPHands_ReachKind::Grab
        : EMars_FPHands_ReachKind::Hold;
    return Target;
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsActive(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control).IsActive;
}

mixin EMars_Control_Activation Get_Activation(const FCk_Handle_Control& Self)
{
    return Self.Get_IsActive() ? EMars_Control_Activation::Active : EMars_Control_Activation::Inactive;
}

mixin FCk_Handle_Mover Get_Mover(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control).Mover;
}

mixin ECk_Interaction_CompletionPolicy Get_CompletionPolicy(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Params).CompletionPolicy;
}

mixin bool Get_IsManipulating(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control).Manipulation.IsSet();
}

// The handle's position 0..1 while gripped; unset when not manipulating.
mixin TOptional<float32> TryGet_ManipulationAlpha(const FCk_Handle_Control& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Control);
    if (State.Manipulation.IsSet() == false)
    { return TOptional<float32>(); }

    return TOptional<float32>(State.Manipulation.GetValue().Alpha);
}

// 0..1 toward EngageAlpha in the pull's direction while gripped; unset when not manipulating.
mixin TOptional<float32> TryGet_ManipulationProgress(const FCk_Handle_Control& Self)
{
    const auto Alpha = Self.TryGet_ManipulationAlpha();
    if (Alpha.IsSet() == false)
    { return TOptional<float32>(); }

    const auto EngageAlpha = Self.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.EngageAlpha;
    return TOptional<float32>(utils_control::Get_ProgressTowardEngage(Self.Get_PullDirection(), Alpha.GetValue(), EngageAlpha));
}

// The Control behind a ManuallyCompleted interact target (one Make_InteractTarget built); invalid for any other target.
mixin FCk_Handle_Control TryGet_ManipulatedControl(const FCk_Handle_InteractTarget& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Get_InteractionCompletionPolicy() != ECk_Interaction_CompletionPolicy::ManuallyCompleted)
    { return FCk_Handle_Control(); }

    const auto Owner = Self.TryGet_InteractableOwner();
    if (ck::Is_NOT_Valid(Owner))
    { return FCk_Handle_Control(); }

    auto Control = Owner.As_Control(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(Control) || Control.Get_CompletionPolicy() != ECk_Interaction_CompletionPolicy::ManuallyCompleted)
    { return FCk_Handle_Control(); }

    return Control;
}

// How the current grip ends; AtEngageAlpha when not manipulating.
mixin EMars_Control_ManipulationCompletion Get_ManipulationCompletion(const FCk_Handle_Control& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Control);
    if (State.Manipulation.IsSet() == false)
    { return EMars_Control_ManipulationCompletion::AtEngageAlpha; }

    return State.Manipulation.GetValue().Completion;
}

// A gripped control that moves nothing and hands its pull out as OnTurned (EMars_Control_ManipulationMode::FreeTurn).
mixin bool Get_IsFreeTurn(const FCk_Handle_Control& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Control_Params);
    return Params.CompletionPolicy == ECk_Interaction_CompletionPolicy::ManuallyCompleted
        && Params.Manipulation.Mode == EMars_Control_ManipulationMode::FreeTurn;
}

// A ManuallyCompleted control whose handle springs back to rest after every pull instead of following IsActive (a pull
// chain). Every pull then runs toward the end pose.
mixin bool Get_ReturnsToRest(const FCk_Handle_Control& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Control_Params);
    return Params.CompletionPolicy == ECk_Interaction_CompletionPolicy::ManuallyCompleted && Params.Manipulation.ReturnsToRest;
}

// The next pull runs toward the start pose only on an active control whose handle stayed where it was pulled (a lever that
// is on).
mixin EMars_Control_PullDirection Get_PullDirection(const FCk_Handle_Control& Self)
{
    if (Self.Get_IsActive() && Self.Get_ReturnsToRest() == false)
    { return EMars_Control_PullDirection::TowardStart; }

    return EMars_Control_PullDirection::TowardEnd;
}

// PullAxis rotated into world space; zero when the axis is zero.
mixin FVector Get_PullDirectionWorld(const FCk_Handle_Control& Self)
{
    const auto PullAxis = Self.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.PullAxis;
    if (PullAxis.IsNearlyZero())
    { return FVector::ZeroVector; }

    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform()).GetRotation().RotateVector(PullAxis);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Engage(FCk_Handle_Control& Self, const FMars_Request_Control_Engage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.EngageRequest = InRequest;
}

mixin void Request_SetActive(FCk_Handle_Control& Self, const FMars_Request_Control_SetActive& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.SetActiveRequest = InRequest;
}

// Grips a ManuallyCompleted control; any other policy ensures and is ignored.
mixin void Request_BeginManipulation(FCk_Handle_Control& Self, const FMars_Request_Control_BeginManipulation& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.BeginManipulationRequest = InRequest;
}

// Dropped unless manipulating when drained.
mixin void Request_Nudge(FCk_Handle_Control& Self, const FMars_Request_Control_Nudge& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.NudgeRequests.Add(InRequest);
}

// Lets go: the handle settles back to the current target pose. A no-op when not manipulating.
mixin void Request_EndManipulation(FCk_Handle_Control& Self, const FMars_Request_Control_EndManipulation& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.EndManipulationRequest = InRequest;
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

mixin void BindTo_OnManipulationChanged(FCk_Handle_Control& Self, FMars_Delegate_Control_OnManipulationChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Control_Signals);
    Fragment.OnManipulationChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnManipulationChanged(FCk_Handle_Control& Self, FMars_Delegate_Control_OnManipulationChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Control_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnManipulationProgress(FCk_Handle_Control& Self, FMars_Delegate_Control_OnManipulationProgress InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Control_Signals);
    Fragment.OnManipulationProgress.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnManipulationProgress(FCk_Handle_Control& Self, FMars_Delegate_Control_OnManipulationProgress InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Control_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTurned(FCk_Handle_Control& Self, FMars_Delegate_Control_OnTurned InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Control_Signals);
    Fragment.OnTurned.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTurned(FCk_Handle_Control& Self, FMars_Delegate_Control_OnTurned InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Control_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Control_Signals).OnTurned.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
