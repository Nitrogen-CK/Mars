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

        auto State = FMars_Fragment_Pendulum();
        State.Oscillator = InSpec.Parts.Oscillator;
        State.Hazard = InSpec.Parts.Hazard;

        InHandle.Add_Fragment(FMars_Feature_Pendulum());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Pendulum_NeedsSetup());
        return InHandle.As_Pendulum();
    }
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
