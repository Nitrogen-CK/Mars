namespace utils_pendulum
{
    // A spec that fails Validate(), or a hazard on another entity, ensures and adds nothing.
    FCk_Handle_Pendulum Add(FCk_Handle& InHandle, FMars_Pendulum_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Pendulum] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Pendulum(); }

        if (ck::EnsureIfNot(InSpec.Parts.Hazard == InHandle,
            f"[Pendulum] [{InHandle.ToString()}] was given Hazard [{InSpec.Parts.Hazard.ToString()}] on another entity; OnTriggered could not fire"))
        { return FCk_Handle_Pendulum(); }

        auto Params = FMars_Fragment_Pendulum_Params();
        Params.Powered = InSpec.Powered;
        Params.Oscillator = InSpec.Parts.Oscillator;
        Params.Hazard = InSpec.Parts.Hazard;

        auto Ledger = FMars_Fragment_Pendulum();
        Ledger.Swing = InSpec.Parts.Oscillator.Get_Sample();
        Ledger.Anchors = 0;

        auto Mirror = FMars_Fragment_Pendulum_Mirror();
        Mirror.Last = Ledger;

        InHandle.Add_Fragment(FMars_Feature_Pendulum());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(Ledger, ECk_Replication::Replicates);
        InHandle.Add_Fragment(Mirror);
        InHandle.Add_Fragment(FMars_Tag_Pendulum_NeedsSetup());
        return InHandle.As_Pendulum();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Oscillator Get_Oscillator(const FCk_Handle_Pendulum& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Pendulum_Params).Oscillator;
}

mixin FCk_Handle_Hazard Get_Hazard(const FCk_Handle_Pendulum& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Pendulum_Params).Hazard;
}

// The authority's anchored swing carried on to now by the server clock: the phase this machine's swing should show.
mixin FMars_Oscillator_Sample Get_AnchoredSample(const FCk_Handle_Pendulum& Self)
{
    const auto& Ledger = Self.Get_Fragment(FMars_Fragment_Pendulum);
    const auto Elapsed = Math::Max(utils_mars_net::Get_ServerWorldSeconds(Self) - Ledger.AnchorServerSeconds, 0.0);
    return Self.Get_Oscillator().Get_Advanced(Ledger.Swing, float32(Elapsed));
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnTriggered(FCk_Handle_Pendulum& Self, FMars_Delegate_Pendulum_OnTriggered InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Pendulum_Signals);
    Fragment.OnTriggered.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTriggered(FCk_Handle_Pendulum& Self, FMars_Delegate_Pendulum_OnTriggered InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Pendulum_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Pendulum_Signals).OnTriggered.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
