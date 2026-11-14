namespace utils_body_part
{
    // Composes a part on InPartEntity: its own Health, a HitZone feeding it, the condition ledger and the depletion
    // policy, then registers it on InSpec.Monster: last in the monster's part roster (every machine's own), and, with
    // authority over the monster, with a default entry in its replicated ledger. Its zone is addressed through the
    // monster. For a DetachLeg part InPartEntity IS the procedural leg (the leg entity carries the part; there is no
    // separate part entity), and the leg must be attached. A rejected spec ensures and returns an invalid handle with
    // nothing composed.
    FCk_Handle_BodyPart Add(FCk_Handle& InPartEntity, FMars_BodyPart_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[BodyPart] [{InPartEntity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_BodyPart(); }

        auto Leg = FCk_Handle_ProceduralLeg();
        if (InSpec.Severance.OnDepleted == EMars_BodyPart_DepletionPolicy::DetachLeg)
        {
            Leg = InPartEntity.As_ProceduralLeg(ECk_SanityCheck::UnChecked);
            if (ck::EnsureIfNot(ck::IsValid(Leg) && utils_procedural_leg::Get_IsAttached(Leg),
                f"[BodyPart] [{InPartEntity.ToString()}] is a DetachLeg part but not an attached procedural leg"))
            { return FCk_Handle_BodyPart(); }
        }

        // Each Add ensures on its own rejection; the zone feeds the Health beside it.
        auto Health = utils_health::Add(InPartEntity, InSpec.Health);
        if (ck::Is_NOT_Valid(Health))
        { return FCk_Handle_BodyPart(); }

        // Known through its monster, so its address crosses the wire: the monster's body zone is that root's zone 0 and
        // the parts follow in the order they are added.
        auto ZoneSpec = InSpec.Zone;
        ZoneSpec.Root = InSpec.Monster;
        auto Zone = utils_hit_zone::Add(InPartEntity, ZoneSpec);
        if (ck::Is_NOT_Valid(Zone))
        { return FCk_Handle_BodyPart(); }

        auto Monster = InSpec.Monster;
        FCk_Handle MonsterEntity = Monster;

        // The mirror compares what arrives against an empty ledger, not one that already arrived.
        if (MonsterEntity.Has_Fragment(FMars_Fragment_BodyPart_Roster) == false)
        {
            auto Roster = FMars_Fragment_BodyPart_Roster();
            Roster.Last = TOptional<FMars_Fragment_BodyPart_Net>(FMars_Fragment_BodyPart_Net());
            MonsterEntity.Add_Fragment(Roster);
            MonsterEntity.Add_Fragment(FMars_Tag_BodyPart_RosterNeedsMirror());
        }

        // A client's copy can receive the replicated ledger before it composes: the arrived ledger stands then.
        if (MonsterEntity.Has_Fragment(FMars_Fragment_BodyPart_Net) == false)
        {
            auto Ledger = FMars_Fragment_BodyPart_Net();
            MonsterEntity.Add_Fragment(Ledger, ECk_Replication::Replicates);
        }

        const auto RosterIndex = MonsterEntity.Get_Fragment(FMars_Fragment_BodyPart_Roster).Parts.Num();

        auto Params = FMars_Fragment_BodyPart_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_BodyPart();
        State.Leg = Leg;
        State.Health = Health;
        State.Zone = Zone;
        State.RosterIndex = RosterIndex;

        InPartEntity.Add_Fragment(FMars_Feature_BodyPart());
        InPartEntity.Add_Fragment(Params);
        InPartEntity.Add_Fragment(State);
        InPartEntity.Add_Fragment(FMars_Tag_BodyPart_NeedsSetup());

        auto Part = InPartEntity.As_BodyPart();
        // Re-fetched: the adds above may move the storage.
        MonsterEntity.Get_Fragment(FMars_Fragment_BodyPart_Roster).Parts.Add(Part);

        if (utils_net::Get_HasAuthority(MonsterEntity))
        { Write_Ledger(Monster, RosterIndex, TOptional<FMars_BodyPart_NetEntry>()); }

        Monster.Request_RegisterPart(FMars_Request_Monster_RegisterPart(Part));
        return Part;
    }

    // Writes InPart's state and condition at its index in its monster's ledger. Called only by the part's processors, with
    // authority over the part; a severed limb can outlive its monster, and then there is no ledger to write.
    void Publish(FCk_Handle_BodyPart& InPart)
    {
        auto Monster = InPart.Get_Monster();
        if (ck::Is_NOT_Valid(Monster))
        { return; }

        const auto State = InPart.Get_Fragment(FMars_Fragment_BodyPart);
        auto Entry = FMars_BodyPart_NetEntry();
        Entry.State = State.State;
        Entry.Condition = State.Condition;
        Write_Ledger(Monster, State.RosterIndex, TOptional<FMars_BodyPart_NetEntry>(Entry));
    }

    // The ledger's only writer, on the authority: grows InMonster's ledger to cover InIndex (new entries default) and, with
    // InEntry set, writes it at InIndex.
    void Write_Ledger(FCk_Handle_Monster InMonster, int32 InIndex, TOptional<FMars_BodyPart_NetEntry> InEntry)
    {
        FCk_Handle Entity = InMonster;
        if (ck::EnsureIfNot(Entity.Has_Fragment(FMars_Fragment_BodyPart_Net), f"[BodyPart] [{Entity.ToString()}] has no part ledger: its parts were not composed through utils_body_part::Add"))
        { return; }

        auto& Ledger = Entity.Get_Fragment(FMars_Fragment_BodyPart_Net);
        while (Ledger.Parts.Num() <= InIndex)
        { Ledger.Parts.Add(FMars_BodyPart_NetEntry()); }

        if (InEntry.IsSet())
        { Ledger.Parts[InIndex] = InEntry.GetValue(); }

        Entity.Request_MarkReplicationDirty(FMars_Fragment_BodyPart_Net);
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

mixin int32 Get_RosterIndex(const FCk_Handle_BodyPart& Self)
{
    return Self.Get_Fragment(FMars_Fragment_BodyPart).RosterIndex;
}

// The entry at InIndex; a default entry (Attached, Pristine) where the array does not reach.
mixin FMars_BodyPart_NetEntry Get_Entry(const FMars_Fragment_BodyPart_Net& Self, int32 InIndex)
{
    if (Self.Parts.IsValidIndex(InIndex) == false)
    { return FMars_BodyPart_NetEntry(); }

    return Self.Parts[InIndex];
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
