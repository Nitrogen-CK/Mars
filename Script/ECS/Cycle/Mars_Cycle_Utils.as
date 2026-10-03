namespace utils_cycle
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Cycle Add(FCk_Handle& InHandle, FMars_Cycle_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Cycle] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Cycle(); }

        auto Params = FMars_Fragment_Cycle_Params();
        Params.Phases = InParams.Phases;
        Params.Loop = InParams.Loop;

        InHandle.Add_Fragment(FMars_Feature_Cycle());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Cycle());

        auto Cycle = InHandle.As_Cycle();
        if (InParams.StartRunning)
        { Cycle.Request_SetRunning(FMars_Request_Cycle_SetRunning(EMars_Cycle_RunState::Running)); }

        return Cycle;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsRunning(const FCk_Handle_Cycle& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cycle).RunState == EMars_Cycle_RunState::Running;
}

mixin FGameplayTag Get_CurrentPhase(const FCk_Handle_Cycle& Self)
{
    const auto& Phases = Self.Get_Fragment(FMars_Fragment_Cycle_Params).Phases;
    const auto Index = Self.Get_Fragment(FMars_Fragment_Cycle).PhaseIndex;
    if (Phases.IsValidIndex(Index) == false)
    { return FGameplayTag(); }

    return Phases[Index].Phase;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Starting re-enters phase 0 afresh (its timer restarts) whatever index the cycle stopped at; stopping keeps the index.
mixin void Request_SetRunning(FCk_Handle_Cycle& Self, const FMars_Request_Cycle_SetRunning& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cycle_Requests);
    Requests.SetRunningRequests.Add(InRequest);
}

// Rewinds to phase 0; re-enters it when the cycle is (or is being set) running.
mixin void Request_Restart(FCk_Handle_Cycle& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cycle_Requests);
    Requests.RestartRequests.Add(FMars_Request_Cycle_Restart());
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_Cycle& Self, FMars_Delegate_Cycle_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Cycle_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_Cycle& Self, FMars_Delegate_Cycle_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Cycle_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Cycle_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnRunningChanged(FCk_Handle_Cycle& Self, FMars_Delegate_Cycle_OnRunningChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Cycle_Signals);
    Fragment.OnRunningChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRunningChanged(FCk_Handle_Cycle& Self, FMars_Delegate_Cycle_OnRunningChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Cycle_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Cycle_Signals).OnRunningChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
