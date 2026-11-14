namespace utils_control
{
    // A pull axis whose on-screen projection is shorter than this (a unit axis pointing nearly at the viewer) has no
    // usable screen direction.
    const float64 k_MinScreenPullLength = 0.05;

    // How long a machine without authority waits, after its pull crossed the threshold, for the engage to come back in
    // the ledger before it gives the handle back: an engage refused or lost with the control never arrives.
    const float32 k_PendingEngageSeconds = 2.0f;

    // The pacing rule for a grip's pull, wherever it is published (the authority's ledger write, a client's report): a
    // pull goes out when it differs from the last one published by at least the quantum and at least 1 / k_PullReportHz
    // has passed since.
    const float32 k_PullReportQuantum = 0.005f;
    const float32 k_PullReportHz = 15.0f;

    // A hitch must not blow the spring up: the frame is capped, then integrated in substeps no longer than this. One
    // semi-implicit Euler step is only stable while Stiffness * dt^2 stays small; at the turnip bed's 400 / 40 a single
    // 0.08 s step carried alpha from 0.30 past the 0.97 threshold and popped the root on a hitch frame (PIE run-09).
    // 1/240 s keeps a stiffness of a few thousand well inside the stable range; a 0.1 s frame costs 24 cheap steps.
    const float32 k_MaxSpringStepSeconds = 0.1f;
    const float32 k_MaxSpringSubstepSeconds = 1.0f / 240.0f;

    // Advances InOutPacer by InDeltaSeconds and returns whether InPull is published now (the pacing rule above); the
    // first pull is always published. A true answer records InPull as published.
    bool Advance_PullPacer(FMars_Control_PullPacer& InOutPacer, float32 InPull, float32 InDeltaSeconds)
    {
        InOutPacer.SecondsSincePublished += InDeltaSeconds;

        if (InOutPacer.Published.IsSet())
        {
            if (Math::Abs(InPull - InOutPacer.Published.GetValue()) < k_PullReportQuantum)
            { return false; }

            if (InOutPacer.SecondsSincePublished < 1.0f / k_PullReportHz)
            { return false; }
        }

        InOutPacer.Published = InPull;
        InOutPacer.SecondsSincePublished = 0.0f;
        return true;
    }

    // Who holds InLedger's grant as this machine reads it: InLocalGripper is the gripper of this machine's latest local
    // grip (invalid when it never gripped).
    EMars_Control_GripHolder Get_GripHolder(const FMars_Fragment_Control_Grip& InLedger, FCk_Handle InLocalGripper)
    {
        if (InLedger.Grip == EMars_Control_Grip::Released)
        { return EMars_Control_GripHolder::Nobody; }

        if (ck::IsValid(InLocalGripper) && InLedger.Gripper == InLocalGripper)
        { return EMars_Control_GripHolder::ThisMachine; }

        return EMars_Control_GripHolder::AnotherMachine;
    }

    // The controls the authority granted InGripper and it still holds; empty anywhere else, and for a gripper holding none.
    TArray<FCk_Handle_Control> Get_HeldControls(const FCk_Handle& InGripper)
    {
        if (ck::Is_NOT_Valid(InGripper) || InGripper.Has_Fragment(FMars_Fragment_Control_HeldGrips) == false)
        { return TArray<FCk_Handle_Control>(); }

        return InGripper.Get_Fragment(FMars_Fragment_Control_HeldGrips).Controls;
    }

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

        auto Local = FMars_Fragment_Control_Local();
        Local.Mover = InParams.Mover;

        auto State = FMars_Fragment_Control();
        State.IsActive = InParams.StartActive;

        auto Mirror = FMars_Fragment_Control_Mirror();
        Mirror.Last = State;

        InHandle.Add_Fragment(FMars_Feature_Control());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(Local);
        // A client's copy can receive the ledger before it composes: the arrived one stands; the mirror's seed stays the
        // composed state, so a value that arrived early still broadcasts.
        if (InHandle.Has_Fragment(FMars_Fragment_Control) == false)
        { InHandle.Add_Fragment(State, ECk_Replication::Replicates); }

        InHandle.Add_Fragment(Mirror);

        // A client's copy can receive the grip ledger before it composes: the arrived one stands, and the mirror starts
        // from it.
        if (InHandle.Has_Fragment(FMars_Fragment_Control_Grip) == false)
        { InHandle.Add_Fragment(FMars_Fragment_Control_Grip(), ECk_Replication::Replicates); }

        auto GripMirror = FMars_Fragment_Control_GripMirror();
        GripMirror.Last = InHandle.Get_Fragment(FMars_Fragment_Control_Grip);
        InHandle.Add_Fragment(GripMirror);
        InHandle.Add_Fragment(FMars_Tag_Control_NeedsGripMirror());

        InHandle.Add_Fragment(FMars_Tag_Control_NeedsSetup());
        return InHandle.As_Control();
    }

    // The ledger's gripper; invalid while Released.
    FCk_Handle Get_GrippedBy(const FMars_Fragment_Control_Grip& InLedger)
    {
        if (InLedger.Grip == EMars_Control_Grip::Released)
        { return FCk_Handle(); }

        return InLedger.Gripper;
    }

    // InGripper begins or ends a grip on InControl: the kernel's report of this machine's own grip, sent through
    // Cue.Mars.Control.Grip, which only the control's authority applies. A grip with no gripper (begun without an
    // interaction) or on a control that is not arbitrated claims nothing: nothing is sent.
    void Request_GripFor(FCk_Handle_Control& InControl, FCk_Handle InGripper, EMars_Control_GripVerb InVerb)
    {
        if (ck::Is_NOT_Valid(InGripper) || InControl.Get_IsGripArbitrated() == false)
        { return; }

        // The cue executor is found through the implicit world context, which a processor does not have and which two
        // PIE worlds in one process would share: scope it to the control's own world.
        const UWorld World = utils_entity_lifetime::Get_WorldForEntity(InControl);
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(World);
        utils_cue_generic::Request_ExecuteCue(InControl, GameplayTags::Cue_Mars_Control_Grip, FMars_Request_Control_Grip(InGripper, InVerb),
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
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

// The control's damped spring over InDeltaSeconds (capped, in substeps): Alpha'' = Stiffness (InPull - Alpha) - Damping
// Alpha', with the travel's ends [0, 1] as hard stops. The one spring a grip and a mirrored grip both move by.
mixin void Step_Spring(const FMars_Control_Manipulation_Spec& Self, FMars_Control_Spring& InOutSpring, float32 InPull, float32 InDeltaSeconds)
{
    const auto DeltaSeconds = Math::Min(InDeltaSeconds, utils_control::k_MaxSpringStepSeconds);
    const auto Substeps = Math::Max(int32(Math::CeilToInt(DeltaSeconds / utils_control::k_MaxSpringSubstepSeconds)), 1);
    const auto SubstepSeconds = DeltaSeconds / float32(Substeps);
    for (int32 Substep = 0; Substep < Substeps; ++Substep)
    {
        const auto Acceleration = Self.Stiffness * (InPull - InOutSpring.Alpha) - Self.Damping * InOutSpring.Velocity;
        InOutSpring.Velocity += Acceleration * SubstepSeconds;
        InOutSpring.Alpha += InOutSpring.Velocity * SubstepSeconds;
        if (InOutSpring.Alpha < 0.0f)
        {
            InOutSpring.Alpha = 0.0f;
            InOutSpring.Velocity = 0.0f;
        }
        else if (InOutSpring.Alpha > 1.0f)
        {
            InOutSpring.Alpha = 1.0f;
            InOutSpring.Velocity = 0.0f;
        }
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
    return Self.Get_Fragment(FMars_Fragment_Control_Local).Mover;
}

mixin ECk_Interaction_CompletionPolicy Get_CompletionPolicy(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Params).CompletionPolicy;
}

// Where a grip may begin and be driven: on the authority, or without it when the control's own entity replicates (has a
// replication driver), so the engage its threshold sends can reach the authority. A control on a scene node beneath a
// replicated root has no driver: it is gripped on the authority alone.
mixin bool Get_MayGripHere(const FCk_Handle_Control& Self)
{
    return utils_net::Get_HasAuthority(Self) || utils_entity_replication_driver::Has(Self);
}

// Whether the authority decides who grips: a control whose own entity replicates (has a replication driver). One without
// keeps its direct grip and engage, on its one machine, and its grip ledger never moves.
mixin bool Get_IsGripArbitrated(const FCk_Handle_Control& Self)
{
    return utils_entity_replication_driver::Has(Self);
}

// The granted grip's gripper, as the ledger stands on this machine; invalid while Released.
mixin FCk_Handle Get_Gripper(const FCk_Handle_Control& Self)
{
    return utils_control::Get_GrippedBy(Self.Get_Fragment(FMars_Fragment_Control_Grip));
}

mixin bool Get_IsGripped(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Grip).Grip == EMars_Control_Grip::Gripped;
}

mixin int32 Get_GripSerial(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Grip).GripSerial;
}

mixin int32 Get_RefusalSerial(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Grip).RefusalSerial;
}

// Who the latest refusal named; invalid before any.
mixin FCk_Handle Get_LastRefused(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Grip).LastRefused;
}

// Why the last granted grip was released; Ended before any.
mixin EMars_Control_GripRelease Get_LastGripRelease(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Grip).LastRelease;
}

// This machine's own grip, never another machine's shown here (TryGet_MirroredGripAlpha).
mixin bool Get_IsManipulating(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Local).Manipulation.IsSet();
}

// Where this machine's own grip has been pulled to, 0..1; unset when not manipulating.
mixin TOptional<float32> TryGet_ManipulationPull(const FCk_Handle_Control& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Control_Local);
    if (State.Manipulation.IsSet() == false)
    { return TOptional<float32>(); }

    return TOptional<float32>(State.Manipulation.GetValue().Pull);
}

// The handle position 0..1 this machine shows for another machine's grip; unset unless it is showing one.
mixin TOptional<float32> TryGet_MirroredGripAlpha(const FCk_Handle_Control& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Control_Local);
    if (State.MirroredGrip.IsSet() == false)
    { return TOptional<float32>(); }

    return TOptional<float32>(State.MirroredGrip.GetValue().Alpha);
}

// What this machine shows of the control's grip: its own grip's alpha, else the mirrored alpha of another machine's,
// else unset.
mixin TOptional<float32> TryGet_ShownGripAlpha(const FCk_Handle_Control& Self)
{
    const auto Own = Self.TryGet_ManipulationAlpha();
    if (Own.IsSet())
    { return Own; }

    return Self.TryGet_MirroredGripAlpha();
}

// The grip ledger's Pull as it stands on this machine (the last granted grip's, after a release).
mixin float32 Get_GripPull(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Grip).Pull;
}

// Who holds the grant as the grip mirror last read it on this machine.
mixin EMars_Control_GripHolder Get_GripHolder(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Local).GripHolder;
}

// Where a grip starts: the Mover's alpha, or without a Mover the end the pull runs from.
mixin float32 Get_GripStartAlpha(const FCk_Handle_Control& Self)
{
    const auto Mover = Self.Get_Mover();
    if (ck::IsValid(Mover))
    { return Mover.Get_Alpha(); }

    return Self.Get_PullDirection() == EMars_Control_PullDirection::TowardStart ? 1.0f : 0.0f;
}

// The handle's position 0..1 while gripped; unset when not manipulating.
mixin TOptional<float32> TryGet_ManipulationAlpha(const FCk_Handle_Control& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Control_Local);
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
    const auto& State = Self.Get_Fragment(FMars_Fragment_Control_Local);
    if (State.Manipulation.IsSet() == false)
    { return EMars_Control_ManipulationCompletion::AtEngageAlpha; }

    return State.Manipulation.GetValue().Completion;
}

// Where the control's Pull comes from while gripped (Look: the look delta; Walk: the puller's distance).
mixin EMars_Control_PullSource Get_PullSource(const FCk_Handle_Control& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.PullSource;
}

// Who walks away from a gripped Walk control; invalid unless a Walk control is being manipulated.
mixin FCk_Handle_Transform TryGet_Puller(const FCk_Handle_Control& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Control_Local);
    if (State.Manipulation.IsSet() == false || Self.Get_PullSource() != EMars_Control_PullSource::Walk)
    { return FCk_Handle_Transform(); }

    return State.Manipulation.GetValue().Puller;
}

// The horizontal (XY) distance, cm, from the control entity's own transform to InPuller (a Walk pull's measure).
mixin float32 Get_HorizontalDistanceTo(const FCk_Handle_Control& Self, const FCk_Handle_Transform& InPuller)
{
    const auto From = utils_transform::Get_EntityCurrentTransform(Self.As_Transform()).GetLocation();
    const auto To = utils_transform::Get_EntityCurrentTransform(InPuller).GetLocation();
    return float32(FVector2D(To.X - From.X, To.Y - From.Y).Size());
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

// Grips a ManuallyCompleted control; any other policy ensures and is ignored, as does a Walk control without a Puller.
mixin void Request_BeginManipulation(FCk_Handle_Control& Self, const FMars_Request_Control_BeginManipulation& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.BeginManipulationRequest = InRequest;
}

// Dropped unless manipulating when drained; a Walk control's pull is the distance, so it ignores nudges.
mixin void Request_Nudge(FCk_Handle_Control& Self, const FMars_Request_Control_Nudge& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.NudgeRequests.Add(InRequest);
}

// A grip claim or its release, applied by the authority on an arbitrated control and dropped anywhere else. The kernel
// sends its own through utils_control::Request_GripFor; a direct call is for a holder with no grip of its own.
mixin void Request_Grip(FCk_Handle_Control& Self, const FMars_Request_Control_Grip& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.GripRequests.Add(InRequest);
}

// A gripper's pull, for the authority's drain (see FMars_Request_Control_ReportPull); queued after the grip requests
// already waiting, so the drain reads them in arrival order.
mixin void Request_ReportPull(FCk_Handle_Control& Self, const FMars_Request_Control_ReportPull& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.PullReports.Add(FMars_Control_QueuedPullReport(InRequest, Requests.GripRequests.Num()));
}

// The assembly names the interactable it works this control through, on every machine.
mixin void Request_WatchInteractable(FCk_Handle_Control& Self, const FMars_Request_Control_WatchInteractable& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Control_Requests);
    Requests.WatchInteractableRequest = InRequest;
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

mixin void BindTo_OnGripRefused(FCk_Handle_Control& Self, FMars_Delegate_Control_OnGripRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Control_Signals);
    Fragment.OnGripRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnGripRefused(FCk_Handle_Control& Self, FMars_Delegate_Control_OnGripRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Control_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Control_Signals).OnGripRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnGripHolderChanged(FCk_Handle_Control& Self, FMars_Delegate_Control_OnGripHolderChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Control_Signals);
    Fragment.OnGripHolderChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnGripHolderChanged(FCk_Handle_Control& Self, FMars_Delegate_Control_OnGripHolderChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Control_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Control_Signals).OnGripHolderChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
