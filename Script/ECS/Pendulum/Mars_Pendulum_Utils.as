namespace utils_pendulum
{
    // Parts that fail Validate(), or a hazard on another entity, ensure and add nothing.
    FCk_Handle_Pendulum Add(FCk_Handle& InHandle, FMars_Pendulum_Spec InParams, FMars_Pendulum_Parts InParts)
    {
        const auto Validation = InParts.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Pendulum] [{InHandle.ToString()}] rejected the parts: {Validation.Get_Error()}"))
        { return FCk_Handle_Pendulum(); }

        if (ck::EnsureIfNot(InParts.Hazard == InHandle,
            f"[Pendulum] [{InHandle.ToString()}] was given Hazard [{InParts.Hazard.ToString()}] on another entity; OnTriggered could not fire"))
        { return FCk_Handle_Pendulum(); }

        auto Params = FMars_Fragment_Pendulum_Params();
        Params.Powered = InParams.Powered;

        auto State = FMars_Fragment_Pendulum();
        State.Oscillator = InParts.Oscillator;
        State.Hazard = InParts.Hazard;

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
