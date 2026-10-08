namespace utils_resting
{
    // A target's contact age before its first contact: far past any grace.
    const float32 k_NoContactAge = 999.0f;

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

        auto Params = FMars_Fragment_Resting_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Resting();
        State.Body = InHandle.As_JoltBody();
        for (int32 Index = 0; Index < InSpec.Targets.Num(); ++Index)
        {
            State.ContactAges.Add(k_NoContactAge);
            State.RestingOn.Add(false);
        }

        InHandle.Add_Fragment(FMars_Feature_Resting());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Resting_NeedsSetup());
        return InHandle.As_Resting();
    }

    // The index of InEntity among InTargets; -1 = not a target.
    int32 Find_TargetIndex(const TArray<FCk_Handle>& InTargets, const FCk_Handle& InEntity)
    {
        for (int32 Index = 0; Index < InTargets.Num(); ++Index)
        {
            if (InTargets[Index] == InEntity)
            { return Index; }
        }

        return -1;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Resting_Spec Get_Spec(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting_Params).Spec;
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
    const auto Index = utils_resting::Find_TargetIndex(Self.Get_Targets(), InTarget);
    if (ck::EnsureIfNot(Index >= 0, f"[Resting] [{Self.ToString()}] has no target [{InTarget.ToString()}]"))
    { return false; }

    return Self.Get_Fragment(FMars_Fragment_Resting).RestingOn[Index];
}

mixin int32 Get_Hops(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).Hops;
}

// 0 while Resting.
mixin float32 Get_ApartSeconds(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).ApartSeconds;
}

// The first target (the only one of a single-target Resting).
mixin FCk_Handle Get_Target(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting_Params).Spec.Targets[0];
}

mixin TArray<FCk_Handle> Get_Targets(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting_Params).Spec.Targets;
}

mixin FCk_Handle_JoltBody Get_Body(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).Body;
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
