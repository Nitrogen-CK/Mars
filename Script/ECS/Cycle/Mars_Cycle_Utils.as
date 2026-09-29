namespace utils_cycle
{
    FCk_Handle_Cycle Add(FCk_Handle& InHandle, FMars_Cycle_Spec InParams)
    {
        auto AllPhasesHaveDuration = true;
        for (const auto& Phase : InParams.Phases)
        {
            if (Phase.Duration <= 0.0f)
            { AllPhasesHaveDuration = false; }
        }

        const auto TableIsValid = InParams.Phases.Num() > 0 && AllPhasesHaveDuration;
        ck::EnsureIfNot(TableIsValid, f"Cycle on [{InHandle.ToString()}] needs at least one phase and every phase Duration > 0; it will never run");

        auto Params = FMars_Fragment_Cycle_Params();
        Params.Loop = InParams.Loop;
        if (TableIsValid)
        { Params.Phases = InParams.Phases; }

        InHandle.Add_Fragment(FMars_Feature_Cycle());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Cycle());

        auto Cycle = InHandle.As_Cycle();
        if (InParams.StartRunning && TableIsValid)
        { Cycle.Request_SetRunning(true); }

        return Cycle;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsRunning(const FCk_Handle_Cycle& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cycle).IsRunning;
}

mixin int32 Get_PhaseIndex(const FCk_Handle_Cycle& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cycle).PhaseIndex;
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

// Starting enters the current PhaseIndex afresh (its timer restarts); stopping keeps the index.
mixin void Request_SetRunning(FCk_Handle_Cycle& Self, bool InRunning)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cycle_Requests);
    Requests.SetRunningRequest = FMars_Request_Cycle_SetRunning(InRunning);
}

// Rewinds to phase 0; re-enters it when the cycle is (or is being set) running.
mixin void Request_Restart(FCk_Handle_Cycle& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cycle_Requests);
    Requests.RestartRequest = FMars_Request_Cycle_Restart();
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
