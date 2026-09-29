namespace utils_pendulum
{
    // InHazard must live on InHandle, and InOscillator on InHandle or on a scene node created directly under it:
    // the pendulum finds itself from their signals.
    FCk_Handle_Pendulum Add(FCk_Handle& InHandle, FMars_Pendulum_Spec InParams, FCk_Handle_Oscillator InOscillator, FCk_Handle_Hazard InHazard)
    {
        ck::EnsureIfNot(FCk_Handle(InHazard) == InHandle, f"Pendulum on [{InHandle.ToString()}] was given Hazard [{InHazard.ToString()}] on another entity; OnTriggered will not fire");

        auto Params = FMars_Fragment_Pendulum_Params();
        Params.Powered = InParams.Powered;

        auto State = FMars_Fragment_Pendulum();
        State.Oscillator = InOscillator;
        State.Hazard = InHazard;

        InHandle.Add_Fragment(FMars_Feature_Pendulum());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Pendulum_NeedsSetup());
        return InHandle.As_Pendulum();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Oscillator Get_Oscillator(const FCk_Handle_Pendulum& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Pendulum).Oscillator;
}

mixin FCk_Handle_Hazard Get_Hazard(const FCk_Handle_Pendulum& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Pendulum).Hazard;
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
