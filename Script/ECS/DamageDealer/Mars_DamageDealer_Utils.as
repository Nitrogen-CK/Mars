namespace utils_damage_dealer
{
    // Composes the dealer on InHandle. A rejected spec ensures and returns an invalid handle with nothing composed.
    FCk_Handle_DamageDealer Add(FCk_Handle& InHandle, FMars_DamageDealer_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[DamageDealer] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_DamageDealer(); }

        auto Params = FMars_Fragment_DamageDealer_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_DamageDealer());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_DamageDealer());
        return InHandle.As_DamageDealer();
    }

    // An event dealt by InDealer: Instigator and Causer are the dealer's entity. Callers overwrite Causer (the item or
    // hazard), the hit location and normal, and the impulse.
    FMars_DamageEvent Make_Event(FCk_Handle_DamageDealer InDealer, float32 InAmount, FGameplayTag InDamageType)
    {
        auto Event = FMars_DamageEvent(InAmount, InDamageType);
        Event.Instigator = FCk_Handle(InDealer);
        Event.Causer = Event.Instigator;
        return Event;
    }

    // One melee swing: a sphere sweep along InSweep filtered on Probe.Mars.HitZone, Blocking world policy (a wall in
    // front of a hurtbox stops the swing) and Silent overlap notify (an aim query must not ping the hurtboxes), traced
    // as InDealer's entity (its own bodies are skipped). A hurtbox hit is dealt through InDealer as InTemplate with the
    // hit location and surface normal stamped; the dealer resolves the hurtbox to its zone. Returns the trace result: a
    // miss is a default result whose HitKind reads Probe, so callers test the hit entity's validity.
    FCk_ShapeCast_Result Request_StrikeSweep(FCk_Handle_DamageDealer& InDealer, FMars_DamageDealer_Sweep InSweep, FMars_DamageEvent InTemplate)
    {
        auto Settings = FCk_ShapeCast_Settings(
            InSweep.Start,
            InSweep.End,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InSweep.Radius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Probe.Mars.HitZone")));
        Settings.Set_WorldHitPolicy(ECk_ProbeTrace_WorldHitPolicy::Blocking);
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);

        const auto Result = utils_probe_trace::Request_SingleShapeTrace(FCk_Handle(InDealer), Settings);
        if (Result.Get_HitKind() != ECk_ProbeTrace_HitKind::Probe || ck::Is_NOT_Valid(Result.Get_HitEntity()))
        { return Result; }

        auto Event = InTemplate;
        Event.HitLocation = Result.Get_HitLocation();
        Event.HitNormal = Result.Get_SurfaceNormal();
        InDealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(Result.Get_HitEntity(), Event));
        return Result;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_DamageDealer_Spec Get_Spec(const FCk_Handle_DamageDealer& Self)
{
    return Self.Get_Fragment(FMars_Fragment_DamageDealer_Params).Spec;
}

mixin int32 Get_HitsDealt(const FCk_Handle_DamageDealer& Self)
{
    return Self.Get_Fragment(FMars_Fragment_DamageDealer).HitsDealt;
}

mixin int32 Get_HitsRejected(const FCk_Handle_DamageDealer& Self)
{
    return Self.Get_Fragment(FMars_Fragment_DamageDealer).HitsRejected;
}

// Unset until a hit is dealt.
mixin TOptional<FMars_DamageEvent> Get_LastDealt(const FCk_Handle_DamageDealer& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_DamageDealer);
    if (State.HitsDealt <= 0)
    { return TOptional<FMars_DamageEvent>(); }

    return TOptional<FMars_DamageEvent>(State.LastDealt);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_DealDamage(FCk_Handle_DamageDealer& Self, const FMars_Request_DamageDealer_DealDamage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_DamageDealer_Requests);
    Requests.DealDamageRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnDamageDealt(FCk_Handle_DamageDealer& Self, FMars_Delegate_DamageDealer_OnDamageDealt InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_DamageDealer_Signals);
    Fragment.OnDamageDealt.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDamageDealt(FCk_Handle_DamageDealer& Self, FMars_Delegate_DamageDealer_OnDamageDealt InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_DamageDealer_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_DamageDealer_Signals).OnDamageDealt.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnDamageRejected(FCk_Handle_DamageDealer& Self, FMars_Delegate_DamageDealer_OnDamageRejected InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_DamageDealer_Signals);
    Fragment.OnDamageRejected.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDamageRejected(FCk_Handle_DamageDealer& Self, FMars_Delegate_DamageDealer_OnDamageRejected InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_DamageDealer_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_DamageDealer_Signals).OnDamageRejected.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
