namespace utils_hit_zone
{
    // Composes the zone on InHandle, feeding InHandle's own Health. A rejected spec, or no Health on InHandle, ensures
    // and returns an invalid handle with nothing composed.
    FCk_Handle_HitZone Add(FCk_Handle& InHandle, FMars_HitZone_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[HitZone] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_HitZone(); }

        const auto Health = InHandle.As_Health(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Health), f"[HitZone] [{InHandle.ToString()}] has no Health to feed - compose utils_health::Add first"))
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

    // A zone where a Sever hit damages the part's condition and a Crush hit, x InCrushMultiplier, ruins it.
    FMars_HitZone_Spec Make_FleshZoneSpec(FGameplayTag InZoneTag, float32 InCrushMultiplier)
    {
        auto Spec = FMars_HitZone_Spec(InZoneTag);
        Spec.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Sever, 1.0f, EMars_HitZone_ConditionImpact::Damages));
        Spec.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Crush, InCrushMultiplier, EMars_HitZone_ConditionImpact::Ruins));
        return Spec;
    }

    // A box hurtbox node under InAttachTo (a scene node, so it rides the transform it hangs off): a Silent, Kinematic
    // Probe.Mars.HitZone probe with no filter, so it detects nothing and only sweeps filtering on that name find it,
    // registered through AttachHurtbox. Returns the node entity, which links back to InZone; invalid (after an ensure, with
    // nothing created) when InZone is not live or InAttachTo is outside the zone's tree (see AttachHurtbox).
    FCk_Handle AddHurtbox_Box(FCk_Handle_HitZone& InZone, FCk_Handle_Transform& InAttachTo, FMars_HitZone_Hurtbox InHurtbox)
    {
        if (ck::EnsureIfNot(ck::IsValid(InZone), "[HitZone] AddHurtbox_Box was given a zone that is not live"))
        { return FCk_Handle(); }

        const auto InZoneTree = Get_IsWithinZoneTree(InZone, InAttachTo);
        if (ck::EnsureIfNot(InZoneTree,
            f"[HitZone] [{InZone.ToString()}] AddHurtbox_Box rejected attach target [{InAttachTo.ToString()}]: the attach target is owned outside the zone's tree"))
        { return FCk_Handle(); }

        auto Node = utils_scene_node::Create(InAttachTo, InHurtbox.LocalOffset);

        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_HitZone);
        ProbeSpec.Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent)
                 .Set_MotionType(ECk_MotionType::Kinematic);
        auto Probe = utils_probe::Add_Box(Node.As_Transform(), InHurtbox.HalfExtents, ProbeSpec);

        const auto Hurtbox = AttachHurtbox(InZone, Probe);
        if (ck::Is_NOT_Valid(Hurtbox))
        { utils_entity_lifetime::Request_DestroyEntity(Node); }

        return Hurtbox;
    }

    // Registers InProbe, a live Probe.Mars.HitZone probe the caller created, as one of InZone's hurtboxes: a Link back to
    // InZone on the probe's entity and a unique Hurtboxes entry, both written at composition time. The probe's
    // lifetime-owner chain must reach InZone's entity or the zone entity's own lifetime owner (so a probe under a sibling
    // of the zone, as a crawler leg's segments are, qualifies, and one from an unrelated tree does not); a zone owned
    // directly by the transient entity accepts only probes below the zone itself. Registering the same probe on the same
    // zone again returns it and changes nothing. A dead zone or probe, a probe of another name, a probe already linked to
    // another zone, or one owned outside the zone's tree ensures and returns an invalid handle with nothing written.
    FCk_Handle AttachHurtbox(FCk_Handle_HitZone& InZone, FCk_Handle_Probe InProbe)
    {
        if (ck::EnsureIfNot(ck::IsValid(InZone), "[HitZone] AttachHurtbox was given a zone that is not live"))
        { return FCk_Handle(); }

        FCk_Handle ProbeEntity = InProbe;
        const auto ProbeIsLive = ck::IsValid(ProbeEntity) && ck::IsValid(ProbeEntity.As_Probe(ECk_SanityCheck::UnChecked));
        if (ck::EnsureIfNot(ProbeIsLive, f"[HitZone] [{InZone.ToString()}] AttachHurtbox was given a probe that is not live"))
        { return FCk_Handle(); }

        const auto ProbeName = utils_probe::Get_Name(InProbe);
        if (ck::EnsureIfNot(ProbeName == GameplayTags::Probe_Mars_HitZone,
            f"[HitZone] [{InZone.ToString()}] AttachHurtbox rejected [{ProbeEntity.ToString()}]: its probe is named [{ProbeName.ToString()}], not [Probe.Mars.HitZone]"))
        { return FCk_Handle(); }

        if (ProbeEntity.Has_Fragment(FMars_Fragment_HitZone_Link))
        {
            const auto LinkedZone = ProbeEntity.Get_Fragment(FMars_Fragment_HitZone_Link).Zone;
            if (ck::EnsureIfNot(LinkedZone == InZone,
                f"[HitZone] [{InZone.ToString()}] AttachHurtbox rejected [{ProbeEntity.ToString()}]: it is already linked to zone [{LinkedZone.ToString()}]"))
            { return FCk_Handle(); }

            return ProbeEntity;
        }

        const auto InZoneTree = Get_IsWithinZoneTree(InZone, ProbeEntity);
        if (ck::EnsureIfNot(InZoneTree,
            f"[HitZone] [{InZone.ToString()}] AttachHurtbox rejected [{ProbeEntity.ToString()}]: its lifetime owners reach neither the zone's entity nor the zone's owner"))
        { return FCk_Handle(); }

        auto Link = FMars_Fragment_HitZone_Link();
        Link.Zone = InZone;
        ProbeEntity.Add_Fragment(Link);

        // A composition-time write, like Add's.
        InZone.Get_Fragment(FMars_Fragment_HitZone).Hurtboxes.AddUnique(ProbeEntity);
        return ProbeEntity;
    }

    // Whether InEntity's lifetime-owner chain reaches InZone's entity, or the zone entity's own lifetime owner unless that
    // owner is the transient entity (every top-level entity shares it). Stops at the transient entity.
    bool Get_IsWithinZoneTree(const FCk_Handle_HitZone& InZone, FCk_Handle InEntity)
    {
        FCk_Handle ZoneEntity = InZone;
        auto ZoneOwner = utils_entity_lifetime::Get_LifetimeOwner(ZoneEntity);
        if (ck::IsValid(ZoneOwner) && utils_entity_lifetime::Get_IsTransientEntity(ZoneOwner))
        { ZoneOwner = FCk_Handle(); }

        // Bounds the walk should an ownership chain ever loop without passing the transient entity.
        const int32 MaxChainDepth = 64;
        FCk_Handle Current = InEntity;
        for (int32 Depth = 0; Depth < MaxChainDepth && ck::IsValid(Current); ++Depth)
        {
            if (Current == ZoneEntity || (ck::IsValid(ZoneOwner) && Current == ZoneOwner))
            { return true; }

            if (utils_entity_lifetime::Get_IsTransientEntity(Current))
            { return false; }

            const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(Current);
            if (Owner == Current)
            { return false; }

            Current = Owner;
        }

        return false;
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
