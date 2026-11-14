namespace utils_devour
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Devour Add(FCk_Handle& InHandle, FMars_Devour_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Devour] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Devour(); }

        auto Params = FMars_Fragment_Devour_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Devour());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Devour());

        // The mirror compares what arrives against the ledger this machine composed, not one that already arrived.
        auto Ledger = FMars_Fragment_Devour_Net();
        Ledger.Victim = InHandle;
        auto Local = FMars_Fragment_Devour_Local();
        Local.Last = TOptional<FMars_Fragment_Devour_Net>(Ledger);

        // A client's copy can receive the replicated ledger before it composes: the arrived ledger stands then.
        if (InHandle.Has_Fragment(FMars_Fragment_Devour_Net) == false)
        { InHandle.Add_Fragment(Ledger, ECk_Replication::Replicates); }

        InHandle.Add_Fragment(Local);
        InHandle.Add_Fragment(FMars_Tag_Devour_NeedsMirror());

        return InHandle.As_Devour();
    }

    // The devourer holding InVictim; invalid when nothing holds it, or when the devourer that held it is gone (a devourer
    // destroyed mid-run never releases its victim's marker).
    FCk_Handle_Devour TryGet_Devourer(const FCk_Handle& InVictim)
    {
        if (ck::Is_NOT_Valid(InVictim) || InVictim.Has_Fragment(FMars_Fragment_Devour_Victim) == false)
        { return FCk_Handle_Devour(); }

        return InVictim.Get_Fragment(FMars_Fragment_Devour_Victim).Devourer;
    }

    // The ledger's only writer, called by the authority's request drain and at the end of its tick: the phase, the
    // serial, the victim (the devourer itself while Idle) and how the last run ended, written and marked dirty only
    // when they differ from the stored ledger.
    void Publish(FCk_Handle_Devour& InSelf)
    {
        const auto& State = InSelf.Get_Fragment(FMars_Fragment_Devour);
        auto Next = FMars_Fragment_Devour_Net();
        Next.Phase = State.Phase;
        Next.Serial = State.Serial;
        Next.Victim = State.Phase == EMars_Devour_Phase::Idle ? InSelf.H() : State.Victim;
        Next.LastEnd = State.LastEnd;

        auto& Ledger = InSelf.Get_Fragment(FMars_Fragment_Devour_Net);
        if (Get_IsSameLedger(Ledger, Next))
        { return; }

        Ledger = Next;
        FCk_Handle Entity = InSelf;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_Devour_Net);
    }

    bool Get_IsSameLedger(const FMars_Fragment_Devour_Net& InA, const FMars_Fragment_Devour_Net& InB)
    {
        return InA.Phase == InB.Phase && InA.Serial == InB.Serial && InA.Victim == InB.Victim && InA.LastEnd == InB.LastEnd;
    }

    // The ledger's victim as this machine knows it: invalid while Idle, when this machine cannot resolve the handle,
    // and when it names InDevourer (the Idle value, which a machine that cannot resolve a new victim keeps).
    FCk_Handle Get_KnownVictim(const FMars_Fragment_Devour_Net& InLedger, const FCk_Handle& InDevourer)
    {
        if (InLedger.Phase == EMars_Devour_Phase::Idle || ck::Is_NOT_Valid(InLedger.Victim) || InLedger.Victim == InDevourer)
        { return FCk_Handle(); }

        return InLedger.Victim;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_Devour_Phase Get_Phase(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour).Phase;
}

// A victim is held.
mixin bool Get_IsActive(const FCk_Handle_Devour& Self)
{
    return Self.Get_Phase() != EMars_Devour_Phase::Idle;
}

// Whether a Begin for InVictim would be taken now: nobody is held, and the victim is valid, is not the devourer itself
// and is not held by a live devourer. The authority's question: on a copy without it, it decides nothing.
mixin bool Get_CanSeize(const FCk_Handle_Devour& Self, const FCk_Handle& InVictim)
{
    if (Self.Get_IsActive() || ck::Is_NOT_Valid(InVictim))
    { return false; }

    if (InVictim == Self.H())
    { return false; }

    return ck::Is_NOT_Valid(utils_devour::TryGet_Devourer(InVictim));
}

// Invalid while Idle, and on a machine that does not know the victim (it cannot see it).
mixin FCk_Handle Get_Victim(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour).Victim;
}

// This machine's own: on a copy without authority it is measured from the phase's arrival, capped at its length.
mixin float32 Get_PhaseSeconds(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour).PhaseSeconds;
}

// How far through the current phase, 0..1; 0 while Idle. This machine's own, as Get_PhaseSeconds.
mixin float32 Get_PhaseAlpha(const FCk_Handle_Devour& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Devour);
    const auto Seconds = Self.Get_Timing().Get_Seconds(State.Phase);
    if (Seconds <= 0.0f)
    { return 0.0f; }

    return Math::Clamp(State.PhaseSeconds / Seconds, 0.0f, 1.0f);
}

mixin FMars_Devour_Spec Get_Spec(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour_Params).Spec;
}

mixin FMars_Devour_Timing Get_Timing(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour_Params).Spec.Timing;
}

// The node a held victim's view is given to; invalid when the spec named none.
mixin FCk_Handle_Transform Get_View(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour_Params).Spec.View;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Begin(FCk_Handle_Devour& Self, const FMars_Request_Devour_Begin& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Devour_Requests);
    Requests.BeginRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_Devour& Self, const FMars_Request_Devour_Cancel& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Devour_Requests);
    Requests.CancelRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_Devour& Self, FMars_Delegate_Devour_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Devour_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_Devour& Self, FMars_Delegate_Devour_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Devour_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnEnded(FCk_Handle_Devour& Self, FMars_Delegate_Devour_OnEnded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Devour_Signals);
    Fragment.OnEnded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEnded(FCk_Handle_Devour& Self, FMars_Delegate_Devour_OnEnded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Devour_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnEnded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
