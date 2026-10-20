namespace utils_resting
{
    // Composes the tracker on InHandle, the entity of the dynamic body that rests (added before, with PersistContacts
    // enabled). It starts Apart on every target; the Setup processor binds the body's contacts. A rejected spec or an entity
    // without a body ensures and returns an invalid handle.
    FCk_Handle_Resting Add(FCk_Handle& InHandle, FMars_Resting_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Resting] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Resting(); }

        if (ck::EnsureIfNot(InHandle.Is_JoltBody(), f"[Resting] [{InHandle.ToString()}] has no Jolt body (add the body first)"))
        { return FCk_Handle_Resting(); }

        InHandle.Add_Fragment(FMars_Feature_Resting());
        InHandle.Add_Fragment(Make_State(InHandle.As_JoltBody(), InSpec));
        InHandle.Add_Fragment(FMars_Tag_Resting_NeedsSetup());
        return InHandle.As_Resting();
    }

    // InSpec's targets and tuners, Apart on every target, no contact yet, no hop: the tracker as Add and a Retarget leave it.
    FMars_Fragment_Resting Make_State(FCk_Handle_JoltBody InBody, const FMars_Resting_Spec& InSpec)
    {
        auto State = FMars_Fragment_Resting();
        State.Targets = InSpec.Targets;
        State.GraceSeconds = InSpec.GraceSeconds;
        State.HopMinSeconds = InSpec.HopMinSeconds;
        State.Body = InBody;
        for (int32 Index = 0; Index < InSpec.Targets.Num(); ++Index)
        {
            State.ContactAges.Add(FMars_Resting_ContactAge());
            State.RestingOn.Add(false);
        }

        return State;
    }

    // The index of InEntity among InTargets; unset when it is not a target.
    TOptional<int32> TryFind_TargetIndex(const TArray<FCk_Handle>& InTargets, const FCk_Handle& InEntity)
    {
        for (int32 Index = 0; Index < InTargets.Num(); ++Index)
        {
            if (InTargets[Index] == InEntity)
            { return TOptional<int32>(Index); }
        }

        return TOptional<int32>();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// The targets and tuners the tracker runs on now: Add's, or the last Retarget's.
mixin FMars_Resting_Spec Get_Spec(const FCk_Handle_Resting& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Resting);
    return FMars_Resting_Spec(State.Targets, State.GraceSeconds, State.HopMinSeconds);
}

mixin EMars_Resting_State Get_State(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).State;
}

// Resting on any target.
mixin bool Get_IsResting(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).State == EMars_Resting_State::Resting;
}

// Resting on InTarget as of the last tick: a recent contact with it, or asleep while the last verdict for it was resting. A
// target the spec does not name ensures and answers false.
mixin bool Get_IsRestingOn(const FCk_Handle_Resting& Self, const FCk_Handle& InTarget)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Resting);
    const auto Index = utils_resting::TryFind_TargetIndex(State.Targets, InTarget);
    if (ck::EnsureIfNot(Index.IsSet(), f"[Resting] [{Self.ToString()}] has no target [{InTarget.ToString()}]"))
    { return false; }

    return State.RestingOn[Index.GetValue()];
}

// Whether the spec names InTarget.
mixin bool Get_HasTarget(const FCk_Handle_Resting& Self, const FCk_Handle& InTarget)
{
    return utils_resting::TryFind_TargetIndex(Self.Get_Fragment(FMars_Fragment_Resting).Targets, InTarget).IsSet();
}

mixin int32 Get_Hops(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).Hops;
}

// The first target (the only one of a single-target Resting).
mixin FCk_Handle Get_Target(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).Targets[0];
}

mixin TArray<FCk_Handle> Get_Targets(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).Targets;
}

mixin FCk_Handle_JoltBody Get_Body(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).Body;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Retarget(FCk_Handle_Resting& Self, const FMars_Request_Resting_Retarget& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Resting_Requests);
    Requests.RetargetRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnRestingChanged(FCk_Handle_Resting& Self, FMars_Delegate_Resting_OnRestingChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Resting_Signals);
    Fragment.OnRestingChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRestingChanged(FCk_Handle_Resting& Self, FMars_Delegate_Resting_OnRestingChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Resting_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Resting_Signals).OnRestingChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnLanded(FCk_Handle_Resting& Self, FMars_Delegate_Resting_OnLanded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Resting_Signals);
    Fragment.OnLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLanded(FCk_Handle_Resting& Self, FMars_Delegate_Resting_OnLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Resting_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Resting_Signals).OnLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
