namespace utils_monster
{
    // Composes the creature root on InRoot: its team, the body Health and a body zone feeding it, the Dead byte attribute
    // and the parts roster (parts register themselves through utils_body_part::Add). A rejected spec ensures and returns
    // an invalid handle with nothing composed.
    FCk_Handle_Monster Add(FCk_Handle& InRoot, FMars_Monster_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Monster] [{InRoot.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Monster(); }

        auto BodyHealth = utils_health::Add(InRoot, InSpec.BodyHealth);
        if (ck::Is_NOT_Valid(BodyHealth))
        { return FCk_Handle_Monster(); }

        auto ZoneSpec = InSpec.BodyZone;
        ZoneSpec.Health = BodyHealth;
        auto BodyZone = utils_hit_zone::Add(InRoot, ZoneSpec);
        if (ck::Is_NOT_Valid(BodyZone))
        { return FCk_Handle_Monster(); }

        utils_team::Add(InRoot, InSpec.Team, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InRoot, n"TAG_MarsMonster");

        auto DeadSpec = FCk_ByteAttribute_Spec(GameplayTags::ResolveGameplayTag(n"ByteAttribute.Mars.Monster.Dead"), 0);
        DeadSpec.Set_MinMax(ECk_MinMax::MinMax).Set_MinValue(0).Set_MaxValue(1);

        auto Params = FMars_Fragment_Monster_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Monster();
        State.BodyHealth = BodyHealth;
        State.BodyZone = BodyZone;
        State.Dead = utils_byte_attribute::Add(InRoot, DeadSpec, ECk_Replication::DoesNotReplicate);

        InRoot.Add_Fragment(FMars_Feature_Monster());
        InRoot.Add_Fragment(Params);
        InRoot.Add_Fragment(State);
        InRoot.Add_Fragment(FMars_Tag_Monster_NeedsSetup());
        return InRoot.As_Monster();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Monster_Spec Get_Spec(const FCk_Handle_Monster& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Monster_Params).Spec;
}

mixin FCk_Handle_Health Get_BodyHealth(const FCk_Handle_Monster& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Monster).BodyHealth;
}

mixin FCk_Handle_HitZone Get_BodyZone(const FCk_Handle_Monster& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Monster).BodyZone;
}

mixin FCk_Handle_ByteAttribute Get_DeadAttribute(const FCk_Handle_Monster& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Monster).Dead;
}

// Every registered part, severed ones included until their entity dies.
mixin TArray<FCk_Handle_BodyPart> Get_Parts(const FCk_Handle_Monster& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Monster).Parts;
}

// Parts whose State is Attached. Validity only guards the read: a severed part is still valid until its debris timer.
mixin int32 Get_AttachedPartCount(const FCk_Handle_Monster& Self)
{
    auto Count = 0;
    for (auto Part : Self.Get_Fragment(FMars_Fragment_Monster).Parts)
    {
        if (ck::IsValid(Part) && Part.Get_State() == EMars_BodyPart_State::Attached)
        { ++Count; }
    }
    return Count;
}

mixin bool Get_IsDead(const FCk_Handle_Monster& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Monster).IsDead;
}

// Unset while alive.
mixin TOptional<FMars_DamageEvent> Get_DeathCause(const FCk_Handle_Monster& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Monster);
    if (State.IsDead == false)
    { return TOptional<FMars_DamageEvent>(); }

    return TOptional<FMars_DamageEvent>(State.DeathCause);
}

mixin float32 Get_CorpseSeconds(const FCk_Handle_Monster& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Monster_Params).Spec.CorpseSeconds;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_RegisterPart(FCk_Handle_Monster& Self, const FMars_Request_Monster_RegisterPart& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Monster_Requests);
    Requests.RegisterPartRequests.Add(InRequest);
}

mixin void Request_Die(FCk_Handle_Monster& Self, const FMars_Request_Monster_Die& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Monster_Requests);
    Requests.DieRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPartRegistered(FCk_Handle_Monster& Self, FMars_Delegate_Monster_OnPartRegistered InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Monster_Signals);
    Fragment.OnPartRegistered.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPartRegistered(FCk_Handle_Monster& Self, FMars_Delegate_Monster_OnPartRegistered InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Monster_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Monster_Signals).OnPartRegistered.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPartSevered(FCk_Handle_Monster& Self, FMars_Delegate_Monster_OnPartSevered InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Monster_Signals);
    Fragment.OnPartSevered.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPartSevered(FCk_Handle_Monster& Self, FMars_Delegate_Monster_OnPartSevered InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Monster_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Monster_Signals).OnPartSevered.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnDied(FCk_Handle_Monster& Self, FMars_Delegate_Monster_OnDied InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Monster_Signals);
    Fragment.OnDied.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDied(FCk_Handle_Monster& Self, FMars_Delegate_Monster_OnDied InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Monster_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Monster_Signals).OnDied.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
