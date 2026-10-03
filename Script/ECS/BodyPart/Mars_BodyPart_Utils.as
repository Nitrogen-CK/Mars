namespace utils_body_part
{
    // Composes a part on InPartEntity: its own Health, a HitZone feeding it, the condition ledger and the depletion
    // policy, then registers it on InSpec.Monster. For a DetachLeg part InPartEntity IS the procedural leg (the leg entity
    // carries the part; there is no separate part entity), and the leg must be attached. A rejected spec ensures and
    // returns an invalid handle with nothing composed.
    FCk_Handle_BodyPart Add(FCk_Handle& InPartEntity, FMars_BodyPart_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[BodyPart] [{InPartEntity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_BodyPart(); }

        auto Leg = FCk_Handle_ProceduralLeg();
        if (InSpec.Severance.OnDepleted == EMars_BodyPart_DepletionPolicy::DetachLeg)
        {
            Leg = InPartEntity.As_ProceduralLeg(ECk_SanityCheck::UnChecked);
            if (ck::EnsureIfNot(ck::IsValid(Leg) && utils_procedural_leg::Get_IsAttached(Leg),
                f"[BodyPart] [{InPartEntity.ToString()}] is a DetachLeg part but not an attached procedural leg"))
            { return FCk_Handle_BodyPart(); }
        }

        auto Health = utils_health::Add(InPartEntity, InSpec.Health);
        if (ck::Is_NOT_Valid(Health))
        { return FCk_Handle_BodyPart(); }

        // The part's zone always feeds the part's own Health.
        auto ZoneSpec = InSpec.Zone;
        ZoneSpec.Health = Health;
        auto Zone = utils_hit_zone::Add(InPartEntity, ZoneSpec);
        if (ck::Is_NOT_Valid(Zone))
        { return FCk_Handle_BodyPart(); }

        auto Params = FMars_Fragment_BodyPart_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_BodyPart();
        State.Leg = Leg;
        State.Health = Health;
        State.Zone = Zone;

        InPartEntity.Add_Fragment(FMars_Feature_BodyPart());
        InPartEntity.Add_Fragment(Params);
        InPartEntity.Add_Fragment(State);
        InPartEntity.Add_Fragment(FMars_Tag_BodyPart_NeedsSetup());

        auto Part = InPartEntity.As_BodyPart();
        auto Monster = InSpec.Monster;
        Monster.Request_RegisterPart(FMars_Request_Monster_RegisterPart(Part));
        return Part;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_BodyPart_Spec Get_Spec(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart_Params).Spec;
}

mixin FGameplayTag Get_PartTag(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart_Params).Spec.PartTag;
}

mixin EMars_BodyPart_Function Get_Function(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart_Params).Spec.Function;
}

mixin FCk_Handle_Health Get_Health(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart).Health;
}

mixin FCk_Handle_HitZone Get_Zone(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart).Zone;
}

// The part entity as a leg; invalid for a non-leg part.
mixin FCk_Handle_ProceduralLeg Get_Leg(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart).Leg;
}

mixin FCk_Handle_Monster Get_Monster(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart_Params).Spec.Monster;
}

mixin EMars_BodyPart_State Get_State(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart).State;
}

mixin EMars_BodyPart_Condition Get_Condition(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart).Condition;
}

mixin float32 Get_RuinDamageTaken(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart).RuinDamageTaken;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_RecordHit(FCk_Handle_BodyPart& Self, const FMars_Request_BodyPart_RecordHit& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_BodyPart_Requests);
    Requests.RecordHitRequests.Add(InRequest);
}

mixin void Request_Sever(FCk_Handle_BodyPart& Self, const FMars_Request_BodyPart_Sever& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_BodyPart_Requests);
    Requests.SeverRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnConditionChanged(FCk_Handle_BodyPart& Self, FMars_Delegate_BodyPart_OnConditionChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_BodyPart_Signals);
    Fragment.OnConditionChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnConditionChanged(FCk_Handle_BodyPart& Self, FMars_Delegate_BodyPart_OnConditionChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_BodyPart_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnConditionChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSevered(FCk_Handle_BodyPart& Self, FMars_Delegate_BodyPart_OnSevered InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_BodyPart_Signals);
    Fragment.OnSevered.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSevered(FCk_Handle_BodyPart& Self, FMars_Delegate_BodyPart_OnSevered InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_BodyPart_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnSevered.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBroken(FCk_Handle_BodyPart& Self, FMars_Delegate_BodyPart_OnBroken InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_BodyPart_Signals);
    Fragment.OnBroken.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBroken(FCk_Handle_BodyPart& Self, FMars_Delegate_BodyPart_OnBroken InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_BodyPart_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnBroken.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
