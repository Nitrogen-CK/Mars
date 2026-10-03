namespace utils_hazard
{
    // Composes the hazard on InHandle around InTrigger, which links back to its hazards (trigger signals carry only the
    // trigger). An invalid trigger, or a push relative to InHandle's transform when InHandle has none, ensures and returns
    // an invalid handle with nothing composed.
    FCk_Handle_Hazard Add(FCk_Handle& InHandle, FMars_Hazard_Spec InSpec, FCk_Handle_Trigger InTrigger)
    {
        if (ck::EnsureIfNot(ck::IsValid(InTrigger), f"[Hazard] [{InHandle.ToString()}] needs a valid trigger; it would never hit"))
        { return FCk_Handle_Hazard(); }

        const auto PushesRelative = InSpec.PushIsRelative && InSpec.PushImpulse.IsNearlyZero() == false;
        if (ck::EnsureIfNot(PushesRelative == false || InHandle.Is_Transform(),
            f"[Hazard] [{InHandle.ToString()}] pushes relative to its transform but has none"))
        { return FCk_Handle_Hazard(); }

        auto Params = FMars_Fragment_Hazard_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Hazard();
        State.Arming = InSpec.StartArmed ? EMars_Hazard_Arming::Armed : EMars_Hazard_Arming::Disarmed;
        State.Trigger = InTrigger;

        InHandle.Add_Fragment(FMars_Feature_Hazard());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Hazard_NeedsSetup());
        auto Hazard = InHandle.As_Hazard();

        auto Trigger = InTrigger;
        Trigger.AddOrGet_Fragment(FMars_Fragment_Hazard_TriggerLink).Hazards.Add(Hazard);

        return Hazard;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Hazard_Spec Get_Spec(const FCk_Handle_Hazard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hazard_Params).Spec;
}

mixin bool Get_IsArmed(const FCk_Handle_Hazard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hazard).Arming == EMars_Hazard_Arming::Armed;
}

mixin FCk_Handle_Trigger Get_Trigger(const FCk_Handle_Hazard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hazard).Trigger;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetArmed(FCk_Handle_Hazard& Self, const FMars_Request_Hazard_SetArmed& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hazard_Requests);
    Requests.SetArmedRequests.Add(InRequest);
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
