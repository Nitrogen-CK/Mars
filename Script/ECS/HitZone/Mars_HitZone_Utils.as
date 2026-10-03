namespace utils_hit_zone
{
    // Composes the zone on InHandle, feeding InSpec.Health when valid and InHandle's own Health otherwise. A rejected spec,
    // or neither Health being valid, ensures and returns an invalid handle with nothing composed.
    FCk_Handle_HitZone Add(FCk_Handle& InHandle, FMars_HitZone_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[HitZone] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_HitZone(); }

        auto Health = InSpec.Health;
        if (ck::Is_NOT_Valid(Health))
        { Health = InHandle.As_Health(ECk_SanityCheck::UnChecked); }

        if (ck::EnsureIfNot(ck::IsValid(Health),
            f"[HitZone] [{InHandle.ToString()}] has no Health to feed - compose utils_health::Add first or name one in the spec"))
        { return FCk_Handle_HitZone(); }

        auto Params = FMars_Fragment_HitZone_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_HitZone();
        State.Health = Health;

        InHandle.Add_Fragment(FMars_Feature_HitZone());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_HitZone();
    }

    // A box hurtbox node under InAttachTo (a scene node, so it rides the transform it hangs off): a Silent, Kinematic
    // Probe.Mars.HitZone probe with no filter, so it detects nothing and only sweeps filtering on that name find it.
    // Returns the node entity, which links back to InZone.
    FCk_Handle AddHurtbox_Box(FCk_Handle_HitZone& InZone, FCk_Handle_Transform& InAttachTo, FMars_HitZone_Hurtbox InHurtbox)
    {
        auto Node = utils_scene_node::Create(InAttachTo, InHurtbox.LocalOffset);
        auto NodeEntity = FCk_Handle(Node);

        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::ResolveGameplayTag(n"Probe.Mars.HitZone"));
        ProbeSpec.Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent)
                 .Set_MotionType(ECk_MotionType::Kinematic);
        utils_probe::Add_Box(Node.As_Transform(), InHurtbox.HalfExtents, ProbeSpec);

        auto Link = FMars_Fragment_HitZone_Link();
        Link.Zone = InZone;
        NodeEntity.Add_Fragment(Link);

        // A composition-time write, like Add's.
        InZone.Get_Fragment(FMars_Fragment_HitZone).Hurtboxes.Add(NodeEntity);
        return NodeEntity;
    }

    // The zone a swept or overlapped entity belongs to: the entity itself when it is a zone, else the zone its hurtbox
    // link names; invalid otherwise (including a link whose zone has died).
    FCk_Handle_HitZone TryGet_Zone(FCk_Handle InHitEntity)
    {
        if (ck::Is_NOT_Valid(InHitEntity))
        { return FCk_Handle_HitZone(); }

        auto Zone = InHitEntity.As_HitZone(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Zone))
        { return Zone; }

        if (InHitEntity.Has_Fragment(FMars_Fragment_HitZone_Link) == false)
        { return FCk_Handle_HitZone(); }

        auto Linked = InHitEntity.Get_Fragment(FMars_Fragment_HitZone_Link).Zone;
        if (ck::Is_NOT_Valid(Linked))
        { return FCk_Handle_HitZone(); }

        return Linked;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_HitZone_Spec Get_Spec(const FCk_Handle_HitZone& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HitZone_Params).Spec;
}

mixin FGameplayTag Get_ZoneTag(const FCk_Handle_HitZone& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HitZone_Params).Spec.ZoneTag;
}

mixin FCk_Handle_Health Get_Health(const FCk_Handle_HitZone& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HitZone).Health;
}

mixin bool Get_IsEnabled(const FCk_Handle_HitZone& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HitZone).IsEnabled;
}

// Skips nodes that died since they were added.
mixin TArray<FCk_Handle> Get_Hurtboxes(const FCk_Handle_HitZone& Self)
{
    auto Result = TArray<FCk_Handle>();
    for (auto Hurtbox : Self.Get_Fragment(FMars_Fragment_HitZone).Hurtboxes)
    {
        if (ck::IsValid(Hurtbox))
        { Result.Add(Hurtbox); }
    }
    return Result;
}

mixin int32 Get_HitCount(const FCk_Handle_HitZone& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HitZone).HitCount;
}

// The first row naming InDamageType; with none, a row of DefaultMultiplier and Impact None for that type.
mixin FMars_HitZone_Reaction Get_Reaction(const FCk_Handle_HitZone& Self, FGameplayTag InDamageType)
{
    const auto& Spec = Self.Get_Fragment(FMars_Fragment_HitZone_Params).Spec;
    for (const auto& Reaction : Spec.Reactions)
    {
        if (Reaction.DamageType == InDamageType)
        { return Reaction; }
    }

    return FMars_HitZone_Reaction(InDamageType, Spec.DefaultMultiplier, EMars_HitZone_ConditionImpact::None);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetEnabled(FCk_Handle_HitZone& Self, const FMars_Request_HitZone_SetEnabled& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HitZone_Requests);
    Requests.SetEnabledRequests.Add(InRequest);
}

mixin void Request_ReleaseHurtboxes(FCk_Handle_HitZone& Self, const FMars_Request_HitZone_ReleaseHurtboxes& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HitZone_Requests);
    Requests.ReleaseHurtboxesRequests.Add(InRequest);
}

mixin void Request_Hit(FCk_Handle_HitZone& Self, const FMars_Request_HitZone_Hit& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HitZone_Requests);
    Requests.HitRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHit(FCk_Handle_HitZone& Self, FMars_Delegate_HitZone_OnHit InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_HitZone_Signals);
    Fragment.OnHit.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHit(FCk_Handle_HitZone& Self, FMars_Delegate_HitZone_OnHit InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_HitZone_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_HitZone_Signals).OnHit.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
