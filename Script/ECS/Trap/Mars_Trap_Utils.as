namespace utils_trap
{
    // InHazard must live on InHandle: the trap finds itself from the hazard's OnHit.
    FCk_Handle_Trap Add(FCk_Handle& InHandle, FMars_Trap_Spec InParams, FCk_Handle_Hazard InHazard, FCk_Handle_Mover InMover)
    {
        ck::EnsureIfNot(FCk_Handle(InHazard) == InHandle, f"Trap on [{InHandle.ToString()}] was given Hazard [{InHazard.ToString()}] on another entity; OnTriggered will not fire");

        auto Cycle = utils_cycle::Add(InHandle, InParams.Cycle);

        auto Params = FMars_Fragment_Trap_Params();
        Params.Actions = InParams.Actions;
        Params.Powered = InParams.Powered;

        auto State = FMars_Fragment_Trap();
        State.Cycle = Cycle;
        State.Hazard = InHazard;
        State.Mover = InMover;

        InHandle.Add_Fragment(FMars_Feature_Trap());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Trap_NeedsSetup());
        return InHandle.As_Trap();
    }

    // Generated spawn params declare a Trap spec without an initializer, so an empty phase table means "use the
    // defaults"; empty actions then take the defaults' actions too.
    FMars_Trap_Spec Resolve_Spec(FMars_Trap_Spec InSpec, FMars_Trap_Spec InDefaults)
    {
        if (InSpec.Cycle.Phases.Num() > 0)
        { return InSpec; }

        auto Resolved = InSpec;
        Resolved.Cycle.Phases = InDefaults.Cycle.Phases;
        if (Resolved.Actions.Num() == 0)
        { Resolved.Actions = InDefaults.Actions; }

        return Resolved;
    }

    // Safe 2.0 / Warn 0.6 / Active 1.2: the part rises on Warn, the hazard arms on Active, Safe resets both.
    FMars_Trap_Spec Make_SpikeTrapSpec()
    {
        const auto Safe = GameplayTags::ResolveGameplayTag(n"Mechanism.Phase.Safe");
        const auto Warn = GameplayTags::ResolveGameplayTag(n"Mechanism.Phase.Warn");
        const auto Active = GameplayTags::ResolveGameplayTag(n"Mechanism.Phase.Active");

        auto Spec = FMars_Trap_Spec();
        Spec.Cycle.Phases.Add(FMars_CyclePhase(Safe, 2.0f));
        Spec.Cycle.Phases.Add(FMars_CyclePhase(Warn, 0.6f));
        Spec.Cycle.Phases.Add(FMars_CyclePhase(Active, 1.2f));

        auto WarnAction = FMars_Trap_PhaseAction();
        WarnAction.Phase = Warn;
        WarnAction.MoverAtEnd = TOptional<bool>(true);
        Spec.Actions.Add(WarnAction);

        auto ActiveAction = FMars_Trap_PhaseAction();
        ActiveAction.Phase = Active;
        ActiveAction.MoverAtEnd = TOptional<bool>(true);
        ActiveAction.HazardArmed = TOptional<bool>(true);
        Spec.Actions.Add(ActiveAction);

        auto SafeAction = FMars_Trap_PhaseAction();
        SafeAction.Phase = Safe;
        SafeAction.MoverAtEnd = TOptional<bool>(false);
        SafeAction.HazardArmed = TOptional<bool>(false);
        Spec.Actions.Add(SafeAction);

        return Spec;
    }

    // Idle 3.0 / Telegraph 1.0 / Fire 1.5: the hazard arms on Fire and disarms on Idle.
    FMars_Trap_Spec Make_VentSpec()
    {
        const auto Idle = GameplayTags::ResolveGameplayTag(n"Mechanism.Phase.Idle");
        const auto Telegraph = GameplayTags::ResolveGameplayTag(n"Mechanism.Phase.Telegraph");
        const auto Fire = GameplayTags::ResolveGameplayTag(n"Mechanism.Phase.Fire");

        auto Spec = FMars_Trap_Spec();
        Spec.Cycle.Phases.Add(FMars_CyclePhase(Idle, 3.0f));
        Spec.Cycle.Phases.Add(FMars_CyclePhase(Telegraph, 1.0f));
        Spec.Cycle.Phases.Add(FMars_CyclePhase(Fire, 1.5f));

        auto FireAction = FMars_Trap_PhaseAction();
        FireAction.Phase = Fire;
        FireAction.HazardArmed = TOptional<bool>(true);
        Spec.Actions.Add(FireAction);

        auto IdleAction = FMars_Trap_PhaseAction();
        IdleAction.Phase = Idle;
        IdleAction.HazardArmed = TOptional<bool>(false);
        Spec.Actions.Add(IdleAction);

        return Spec;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Cycle Get_Cycle(const FCk_Handle_Trap& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Trap).Cycle;
}

mixin FCk_Handle_Hazard Get_Hazard(const FCk_Handle_Trap& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Trap).Hazard;
}

mixin FCk_Handle_Mover Get_Mover(const FCk_Handle_Trap& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Trap).Mover;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnTriggered(FCk_Handle_Trap& Self, FMars_Delegate_Trap_OnTriggered InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Trap_Signals);
    Fragment.OnTriggered.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTriggered(FCk_Handle_Trap& Self, FMars_Delegate_Trap_OnTriggered InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Trap_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Trap_Signals).OnTriggered.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
