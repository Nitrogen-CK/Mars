namespace utils_health
{
    // Composes Health on InHandle: the FloatAttribute.Mars.Health attribute (MinMax 0..Max, starting at Start or Max when
    // Start <= 0) and the latch state. A rejected spec ensures and returns an invalid handle with nothing composed.
    FCk_Handle_Health Add(FCk_Handle& InHandle, FMars_Health_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Health] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Health(); }

        const auto Start = InSpec.Start <= 0.0f ? InSpec.Max : InSpec.Start;

        auto State = FMars_Fragment_Health();
        State.Attribute = utils_float_attribute::Add(InHandle, GameplayTags::ResolveGameplayTag(n"FloatAttribute.Mars.Health"),
            Start, ECk_Replication::DoesNotReplicate, ECk_MinMax::MinMax, 0.0f, InSpec.Max);
        State.IsInvulnerable = InSpec.StartInvulnerable;

        auto Params = FMars_Fragment_Health_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Health());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_Health();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Health_Spec Get_Spec(const FCk_Handle_Health& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Health_Params).Spec;
}

// The attribute's current value: what the last drain wrote, once the attribute has applied it.
mixin float32 Get_Current(const FCk_Handle_Health& Self)
{
    return utils_float_attribute::Get_FinalValue(Self.Get_Fragment(FMars_Fragment_Health).Attribute, ECk_MinMaxCurrent::Current);
}

mixin float32 Get_Max(const FCk_Handle_Health& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Health_Params).Spec.Max;
}

mixin bool Get_IsDepleted(const FCk_Handle_Health& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Health).IsDepleted;
}

mixin bool Get_IsInvulnerable(const FCk_Handle_Health& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Health).IsInvulnerable;
}

mixin FCk_Handle_FloatAttribute Get_Attribute(const FCk_Handle_Health& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Health).Attribute;
}

// Unset until a hit applies damage.
mixin TOptional<FMars_DamageEvent> Get_LastHit(const FCk_Handle_Health& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Health);
    if (State.HasLastHit == false)
    { return TOptional<FMars_DamageEvent>(); }

    return TOptional<FMars_DamageEvent>(State.LastHit);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetInvulnerable(FCk_Handle_Health& Self, const FMars_Request_Health_SetInvulnerable& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Health_Requests);
    Requests.SetInvulnerableRequests.Add(InRequest);
}

mixin void Request_Heal(FCk_Handle_Health& Self, const FMars_Request_Health_Heal& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Health_Requests);
    Requests.HealRequests.Add(InRequest);
}

mixin void Request_ApplyDamage(FCk_Handle_Health& Self, const FMars_Request_Health_ApplyDamage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Health_Requests);
    Requests.ApplyDamageRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnDamaged(FCk_Handle_Health& Self, FMars_Delegate_Health_OnDamaged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Health_Signals);
    Fragment.OnDamaged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDamaged(FCk_Handle_Health& Self, FMars_Delegate_Health_OnDamaged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Health_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Health_Signals).OnDamaged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHealed(FCk_Handle_Health& Self, FMars_Delegate_Health_OnHealed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Health_Signals);
    Fragment.OnHealed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHealed(FCk_Handle_Health& Self, FMars_Delegate_Health_OnHealed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Health_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Health_Signals).OnHealed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnDepleted(FCk_Handle_Health& Self, FMars_Delegate_Health_OnDepleted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Health_Signals);
    Fragment.OnDepleted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDepleted(FCk_Handle_Health& Self, FMars_Delegate_Health_OnDepleted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Health_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Health_Signals).OnDepleted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
