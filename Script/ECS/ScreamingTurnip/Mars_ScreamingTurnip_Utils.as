namespace utils_screaming_turnip
{
    // Composes the kernel on InHandle, which must be InSpec.Parts.WorldItem's own entity (the entity its body is on: the
    // contact handler resolves the kernel from the body). It starts Loose and Dormant; the Setup processor binds the body's
    // contacts and the Tick derives the real placement on its first pass. A rejected spec ensures and returns an invalid
    // handle with nothing composed.
    FCk_Handle_ScreamingTurnip Add(FCk_Handle& InHandle, FMars_ScreamingTurnip_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[ScreamingTurnip] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_ScreamingTurnip(); }

        FCk_Handle WorldItemEntity = InSpec.Parts.WorldItem;
        if (ck::EnsureIfNot(WorldItemEntity == InHandle,
            f"[ScreamingTurnip] [{InHandle.ToString()}] is not its Parts.WorldItem [{WorldItemEntity.ToString()}]: compose the kernel on the world item"))
        { return FCk_Handle_ScreamingTurnip(); }

        auto Params = FMars_Fragment_ScreamingTurnip_Params();
        Params.Vocal = InSpec.Vocal;
        Params.Settlement = InSpec.Settlement;
        Params.WorldItem = InSpec.Parts.WorldItem;

        InHandle.Add_Fragment(FMars_Feature_ScreamingTurnip());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_ScreamingTurnip());
        InHandle.Add_Fragment(FMars_Fragment_ScreamingTurnip_Settle());
        InHandle.Add_Fragment(FMars_Tag_ScreamingTurnip_NeedsSetup());
        return InHandle.As_ScreamingTurnip();
    }

    // Whether InPhase is part of the warning (the voice is audible from Anticipate on).
    bool Get_IsWarning(EMars_ScreamingTurnip_Phase InPhase)
    {
        return InPhase == EMars_ScreamingTurnip_Phase::Anticipate || InPhase == EMars_ScreamingTurnip_Phase::Inhale;
    }

    // Whether InPlacement lets the voice run.
    bool Get_IsEligible(EMars_ScreamingTurnip_Placement InPlacement)
    {
        return InPlacement == EMars_ScreamingTurnip_Placement::Held || InPlacement == EMars_ScreamingTurnip_Placement::LooseSettled;
    }

    // A contact that supports the root: not a sensor, and the other side is the baked static world (no entity, or an
    // attribution entity with no Jolt body) or a body that is not Dynamic. A root resting on another loose item is not
    // supported by it.
    bool Get_IsSupportingContact(const FCk_JoltBody_Payload_OnContact& InPayload)
    {
        if (InPayload.Get_OtherIsSensor() == ECk_EnableDisable::Enable)
        { return false; }

        auto Other = InPayload.Get_OtherEntity();
        if (ck::Is_NOT_Valid(Other))
        { return true; }

        auto OtherBody = Other.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(OtherBody))
        { return true; }

        return utils_jolt_body::Get_MotionType(OtherBody) != ECk_MotionType::Dynamic;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_ScreamingTurnip_Placement Get_Placement(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip).Placement;
}

mixin EMars_ScreamingTurnip_Phase Get_Phase(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip).Phase;
}

// 0 before the first commit.
mixin int32 Get_ScreamSequence(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip).ScreamSequence;
}

// On the kernel's clock (Get_Clock); unset before the first commit.
mixin TOptional<float32> Get_LastScreamCommittedAt(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip).LastScreamCommittedAt;
}

// The kernel's monotonic time, seconds since Add (zero and bad deltas excluded).
mixin float32 Get_Clock(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip).Clock;
}

mixin float32 Get_WarningElapsed(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip).WarningElapsed;
}

// The last settle sample's support (a recent supporting contact, or asleep); false off the world mount. The presentation
// tells an airborne root from one rolling on the ground by it.
mixin bool Get_HasSupport(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Settle).HasSupport;
}

// The world item's root at the last commit; zero before the first.
mixin FVector Get_LastScreamPosition(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip).LastWorldPosition;
}

mixin FMars_ScreamingTurnip_Vocal Get_Vocal(const FCk_Handle_ScreamingTurnip& Self)
{
    return Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Params).Vocal;
}

// Seconds until the next warning starts, if the placement stays eligible: the cooldown left while one runs, 0 when the next
// warning is due now or running. Unset while the placement is not eligible.
mixin TOptional<float32> Get_SecondsUntilNextWarning(const FCk_Handle_ScreamingTurnip& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_ScreamingTurnip);
    if (utils_screaming_turnip::Get_IsEligible(State.Placement) == false)
    { return TOptional<float32>(); }

    if (State.LastScreamCommittedAt.IsSet() == false || utils_screaming_turnip::Get_IsWarning(State.Phase))
    { return TOptional<float32>(0.0f); }

    const auto& Vocal = Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Params).Vocal;
    const auto Left = State.LastScreamCommittedAt.GetValue() + Vocal.CooldownSeconds - State.Clock;
    return TOptional<float32>(Math::Max(Left, 0.0f));
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Suspend(FCk_Handle_ScreamingTurnip& Self, const FMars_Request_ScreamingTurnip_Suspend& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_ScreamingTurnip_Requests);
    Requests.SuspendRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPlacementChanged(FCk_Handle_ScreamingTurnip& Self, FMars_Delegate_ScreamingTurnip_OnPlacementChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_ScreamingTurnip_Signals);
    Fragment.OnPlacementChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPlacementChanged(FCk_Handle_ScreamingTurnip& Self, FMars_Delegate_ScreamingTurnip_OnPlacementChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnPlacementChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPhaseChanged(FCk_Handle_ScreamingTurnip& Self, FMars_Delegate_ScreamingTurnip_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_ScreamingTurnip_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_ScreamingTurnip& Self, FMars_Delegate_ScreamingTurnip_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnScreamCommitted(FCk_Handle_ScreamingTurnip& Self, FMars_Delegate_ScreamingTurnip_OnScreamCommitted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_ScreamingTurnip_Signals);
    Fragment.OnScreamCommitted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnScreamCommitted(FCk_Handle_ScreamingTurnip& Self, FMars_Delegate_ScreamingTurnip_OnScreamCommitted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnScreamCommitted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
