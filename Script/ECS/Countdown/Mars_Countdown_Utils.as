namespace utils_countdown
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Countdown Add(FCk_Handle& InHandle, FMars_Countdown_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Countdown] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Countdown(); }

        auto Params = FMars_Fragment_Countdown_Params();
        Params.Steps = InParams.Steps;
        Params.SecondsPerStep = InParams.SecondsPerStep;

        auto State = FMars_Fragment_Countdown();
        State.Remaining = InParams.StartCharged ? InParams.Steps : 0;

        InHandle.Add_Fragment(FMars_Feature_Countdown());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Countdown_NeedsSetup());
        if (State.Remaining > 0)
        { InHandle.Add_Fragment(FMars_Tag_Countdown_Running()); }

        return InHandle.As_Countdown();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin int32 Get_Steps(const FCk_Handle_Countdown& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Countdown_Params).Steps;
}

mixin int32 Get_Remaining(const FCk_Handle_Countdown& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Countdown).Remaining;
}

mixin bool Get_IsCharged(const FCk_Handle_Countdown& Self)
{
    return Self.Get_Remaining() > 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Charge(FCk_Handle_Countdown& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Countdown_Requests);
    Requests.ChargeRequests.Add(FMars_Request_Countdown_Charge());
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnRemainingChanged(FCk_Handle_Countdown& Self, FMars_Delegate_Countdown_OnRemainingChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Countdown_Signals);
    Fragment.OnRemainingChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRemainingChanged(FCk_Handle_Countdown& Self, FMars_Delegate_Countdown_OnRemainingChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Countdown_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Countdown_Signals).OnRemainingChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
