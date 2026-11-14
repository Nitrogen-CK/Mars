namespace utils_health
{
    // Composes Health on InHandle: the FloatAttribute.Mars.Health attribute (MinMax 0..Max, starting at Start, or at Max
    // when Start is unset), the latch state and the ledger. A rejected spec ensures and returns an invalid handle with
    // nothing composed. The ledger always replicates (the drain marks it dirty on every write); on a host without a
    // replication driver it simply has nowhere to go. The attribute never replicates: a copy without authority reads the
    // ledger.
    FCk_Handle_Health Add(FCk_Handle& InHandle, FMars_Health_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Health] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Health(); }

        const auto Start = InSpec.Start.IsSet() ? InSpec.Start.GetValue() : InSpec.Max;

        auto State = FMars_Fragment_Health();
        State.Attribute = utils_float_attribute::Add(InHandle, GameplayTags::FloatAttribute_Mars_Health,
            Start, ECk_Replication::DoesNotReplicate, ECk_MinMax::MinMax, 0.0f, InSpec.Max);
        State.IsInvulnerable = InSpec.Invulnerability == ECk_EnableDisable::Enable;

        auto Params = FMars_Fragment_Health_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Health());
        InHandle.Add_Fragment(Params);
        auto Ledger = FMars_Fragment_Health_Net();
        Ledger.Current = Start;
        Ledger.Invulnerability = InSpec.Invulnerability;

        // The mirror compares what arrives against the ledger this machine composed, not one that already arrived.
        auto Local = FMars_Fragment_Health_Local();
        Local.Last = TOptional<FMars_Fragment_Health_Net>(Ledger);

        InHandle.Add_Fragment(State);

        // A client's copy can receive the replicated ledger before it composes: the arrived ledger stands then.
        if (InHandle.Has_Fragment(FMars_Fragment_Health_Net) == false)
        { InHandle.Add_Fragment(Ledger, ECk_Replication::Replicates); }

        InHandle.Add_Fragment(Local);
        InHandle.Add_Fragment(FMars_Tag_Health_NeedsMirror());
        return InHandle.As_Health();
    }

    // The ledger a copy without authority reads the Health through, from the live state and what the drain applied: the
    // current value, the invulnerability and the vitality as they stand, the serials advanced by the counts, the latest
    // damage (as plain data) and heal. Called only by the authority's drain, once, after its attribute write.
    void Publish(FCk_Handle_Health& InHealth, const FMars_Health_Answers& InAnswers)
    {
        const auto State = InHealth.Get_Fragment(FMars_Fragment_Health);
        auto Next = InHealth.Get_Fragment(FMars_Fragment_Health_Net);
        Next.Current = InAnswers.Current;
        Next.Invulnerability = State.IsInvulnerable ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
        Next.Vitality = State.IsDepleted ? EMars_Health_Vitality::Depleted : EMars_Health_Vitality::Standing;
        Next.DamageSerial += InAnswers.Damages;
        Next.HealSerial += InAnswers.Heals;
        Next.DepletionSerial += InAnswers.Depletions;

        if (InAnswers.LastDamage.IsSet())
        {
            Next.LastDamage = Make_NetHit(InAnswers.LastDamage.GetValue());
            Next.LastDamageApplied = InAnswers.LastDamageApplied;
        }

        if (InAnswers.Heals > 0)
        { Next.LastHealApplied = InAnswers.LastHealApplied; }

        InHealth.Get_Fragment(FMars_Fragment_Health_Net) = Next;
        FCk_Handle Entity = InHealth;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_Health_Net);
    }

    FMars_Health_NetHit Make_NetHit(const FMars_DamageEvent& InEvent)
    {
        auto NetHit = FMars_Health_NetHit();
        NetHit.Amount = InEvent.Amount;
        NetHit.DamageType = InEvent.DamageType;
        NetHit.Hit = InEvent.Hit;
        return NetHit;
    }

    // The hit as a copy without authority raises it: no instigator, causer or zone (their handles do not cross).
    FMars_DamageEvent Make_Event(const FMars_Health_NetHit& InNetHit)
    {
        auto Event = FMars_DamageEvent(InNetHit.Amount, InNetHit.DamageType);
        Event.Hit = InNetHit.Hit;
        return Event;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Health_Spec Get_Spec(const FCk_Handle_Health& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Health_Params).Spec;
}

// With authority, the attribute's current value: what the last drain wrote, once the attribute has applied it. Without,
// the ledger's: the attribute is this machine's own and does not replicate.
mixin float32 Get_Current(const FCk_Handle_Health& Self)
{
    if (utils_net::Get_HasAuthority(Self) == false)
    { return Self.Get_Fragment(FMars_Fragment_Health_Net).Current; }

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

// Unset until a hit applies damage.
mixin TOptional<FMars_DamageEvent> Get_LastHit(const FCk_Handle_Health& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Health).LastHit;
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
