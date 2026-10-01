namespace utils_control
{
    // InMover is optional: an invalid handle means the control moves nothing. The completion policy and HoldSeconds are
    // retained for Make_InteractTarget; a rejected spec ensures and returns an invalid handle.
    FCk_Handle_Control Add(FCk_Handle& InHandle, FMars_Control_Spec InParams, FCk_Handle_Mover InMover)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Control] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
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
        State.Mover = InMover;

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
        if (Screen.Size() < 0.05)
        { return float32(InLookDelta.Y); }

        Screen.Normalize();
        return float32(InLookDelta.X * Screen.X + InLookDelta.Y * Screen.Y);
    }

    // 0..1 toward EngageAlpha in the pull's direction: toward alpha 1, or toward 0 when InTowardStart.
    float32 Get_ProgressTowardEngage(bool InTowardStart, float32 InAlpha, float32 InEngageAlpha)
    {
        const auto Travelled = InTowardStart ? 1.0f - InAlpha : InAlpha;
        return Math::Clamp(Travelled / InEngageAlpha, 0.0f, 1.0f);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Interact Target
//--------------------------------------------------------------------------------------------------------------------------

// The interactable target a control's entity script mounts on the Use channel, routed to UMars_SmState_Control_Engage:
// Instant, Timed(HoldSeconds), or ManuallyCompleted (pulled; the Control's tick ends the interaction at EngageAlpha).
mixin FMars_Interactable_TargetEntry Make_InteractTarget(const FCk_Handle_Control& Self, FText InPromptText)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Control_Params);

    auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
    TargetSpec.Set_CompletionPolicy(Params.CompletionPolicy);
    if (Params.CompletionPolicy == ECk_Interaction_CompletionPolicy::Timed)
    { TargetSpec.Set_InteractionDuration(FCk_Time(Params.HoldSeconds)); }

    auto Prompt = FMars_InteractPrompt_Spec();
    Prompt.InputAction = mars::Mars_IA_Interact_Use;
    Prompt.PromptText = InPromptText;

    auto Target = FMars_Interactable_TargetEntry();
    Target.InteractTargetSpec = TargetSpec;
    Target.InteractPromptSpec = Prompt;
    Target.InteractionStateClass = UMars_SmState_Control_Engage;
    return Target;
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

mixin ECk_Interaction_CompletionPolicy Get_CompletionPolicy(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Params).CompletionPolicy;
}

mixin bool Get_IsManipulating(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control).Manipulation.IsActive;
}

mixin float32 Get_ManipulationAlpha(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control).Manipulation.Alpha;
}

// 0 when not manipulating.
mixin float32 Get_ManipulationProgress(const FCk_Handle_Control& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Control);
    if (State.Manipulation.IsActive == false)
    { return 0.0f; }

    const auto EngageAlpha = Self.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.EngageAlpha;
    return utils_control::Get_ProgressTowardEngage(Self.Get_PullsTowardStart(), State.Manipulation.Alpha, EngageAlpha);
}

// A ManuallyCompleted control whose handle springs back to rest after every pull instead of following IsActive (a pull
// chain). Every pull then runs toward the end pose.
mixin bool Get_ReturnsToRest(const FCk_Handle_Control& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Control_Params);
    return Params.CompletionPolicy == ECk_Interaction_CompletionPolicy::ManuallyCompleted && Params.Manipulation.ReturnsToRest;
}

// The next pull runs toward the start pose: an active control whose handle stayed where it was pulled (a lever that is on).
mixin bool Get_PullsTowardStart(const FCk_Handle_Control& Self)
{
    return Self.Get_IsActive() && Self.Get_ReturnsToRest() == false;
}

// PullAxis rotated into world space; zero when the axis is zero or the control entity has no Transform.
mixin FVector Get_PullDirectionWorld(const FCk_Handle_Control& Self)
{
    const auto PullAxis = Self.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.PullAxis;
    if (PullAxis.IsNearlyZero())
    { return FVector::ZeroVector; }

    const auto Transform = FCk_Handle(Self).As_Transform(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(Transform))
    { return FVector::ZeroVector; }

    return utils_transform::Get_EntityCurrentTransform(Transform).GetRotation().RotateVector(PullAxis);
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
mixin void Request_EndManipulation(FCk_Handle_Control& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.EndManipulationRequest = FMars_Request_Control_EndManipulation();
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
