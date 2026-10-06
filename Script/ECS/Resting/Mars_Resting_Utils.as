namespace utils_resting
{
    // Composes the tracker on InHandle, the entity of the dynamic body that rests (added before, with PersistContacts
    // enabled). It starts Apart; the Setup processor binds the body's contacts. A rejected spec or an entity without a body
    // ensures and returns an invalid handle.
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

        InHandle.Add_Fragment(FMars_Feature_Resting());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Resting_NeedsSetup());
        return InHandle.As_Resting();
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

mixin bool Get_IsResting(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting).State == EMars_Resting_State::Resting;
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

mixin FCk_Handle Get_Target(const FCk_Handle_Resting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Resting_Params).Spec.Target;
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
