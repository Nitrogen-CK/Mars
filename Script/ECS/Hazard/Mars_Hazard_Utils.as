namespace utils_hazard
{
    FCk_Handle_Hazard Add(FCk_Handle& InHandle, FMars_Hazard_Spec InParams, FCk_Handle_Trigger InTrigger)
    {
        auto Params = FMars_Fragment_Hazard_Params();
        Params.PushImpulse = InParams.PushImpulse;
        Params.PushIsRelative = InParams.PushIsRelative;

        auto State = FMars_Fragment_Hazard();
        State.IsArmed = InParams.StartArmed;
        State.Trigger = InTrigger;

        InHandle.Add_Fragment(FMars_Feature_Hazard());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Hazard_NeedsSetup());
        auto Hazard = InHandle.As_Hazard();

        if (ck::IsValid(InTrigger))
        {
            auto Trigger = InTrigger;
            Trigger.AddOrGet_Fragment(FMars_Fragment_Hazard_TriggerLink).Hazards.Add(Hazard);
        }

        return Hazard;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsArmed(const FCk_Handle_Hazard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hazard).IsArmed;
}

mixin FCk_Handle_Trigger Get_Trigger(const FCk_Handle_Hazard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hazard).Trigger;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetArmed(FCk_Handle_Hazard& Self, bool InArmed)
{
    // A pending request must still be overwritten even when InArmed matches the current state.
    if (Self.Has_Fragment(FMars_Fragment_Hazard_Requests) == false
        && Self.Get_Fragment(FMars_Fragment_Hazard).IsArmed == InArmed)
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hazard_Requests);
    Requests.SetArmed = FMars_Request_Hazard_SetArmed(InArmed);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHit(FCk_Handle_Hazard& Self, FMars_Delegate_Hazard_OnHit InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Hazard_Signals);
    Fragment.OnHit.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHit(FCk_Handle_Hazard& Self, FMars_Delegate_Hazard_OnHit InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Hazard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Hazard_Signals).OnHit.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnArmedChanged(FCk_Handle_Hazard& Self, FMars_Delegate_Hazard_OnArmedChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Hazard_Signals);
    Fragment.OnArmedChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnArmedChanged(FCk_Handle_Hazard& Self, FMars_Delegate_Hazard_OnArmedChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Hazard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Hazard_Signals).OnArmedChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
