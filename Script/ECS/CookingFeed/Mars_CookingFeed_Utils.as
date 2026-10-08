namespace utils_cooking_feed
{
    // Composes the feed on InHandle (the station entity; the feature does not need the Station feature). The spec's Nodes are
    // built by the caller: Nodes.Release is sampled at every release. The platter starts with Supply.InitialCount pieces, every
    // slot free and the hand idle. A rejected spec or a missing release node ensures and returns an invalid handle.
    FCk_Handle_CookingFeed Add(FCk_Handle& InHandle, FMars_CookingFeed_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[CookingFeed] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_CookingFeed(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Release), f"[CookingFeed] [{InHandle.ToString()}] needs a release node"))
        { return FCk_Handle_CookingFeed(); }

        auto Params = FMars_Fragment_CookingFeed_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_CookingFeed();
        State.Available = InSpec.Supply.InitialCount;
        for (int32 Slot = 0; Slot < InSpec.Supply.SlotCapacity; ++Slot)
        { State.SlotTaken.Add(false); }

        InHandle.Add_Fragment(FMars_Feature_CookingFeed());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_CookingFeed();
    }

    // A phase length the Tick can advance through: finite and not negative.
    bool Get_IsValidSeconds(float32 InSeconds)
    {
        return Math::IsFinite(InSeconds) && InSeconds >= 0.0f;
    }

    // The timed length of InPhase; zero for Idle and AwaitAdmission (no clock).
    float32 Get_PhaseDuration(const FMars_CookingFeed_TimingSpec& InTiming, EMars_CookingFeed_Phase InPhase)
    {
        switch (InPhase)
        {
            case EMars_CookingFeed_Phase::Reach: return InTiming.ReachSeconds;
            case EMars_CookingFeed_Phase::Grasp: return InTiming.GraspSeconds;
            case EMars_CookingFeed_Phase::Carry: return InTiming.CarrySeconds;
            case EMars_CookingFeed_Phase::Return: return InTiming.ReturnSeconds;
            default: return 0.0f;
        }
    }

    // The phases with a clock.
    bool Get_IsTimed(EMars_CookingFeed_Phase InPhase)
    {
        return InPhase == EMars_CookingFeed_Phase::Reach || InPhase == EMars_CookingFeed_Phase::Grasp
            || InPhase == EMars_CookingFeed_Phase::Carry || InPhase == EMars_CookingFeed_Phase::Return;
    }

    FString Get_PieceName(const FMars_CookingFeed_PieceId& InPieceId)
    {
        return f"g{InPieceId.Generation}#{InPieceId.StockIndex}";
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_CookingFeed_Spec Get_Spec(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed_Params).Spec;
}

mixin EMars_CookingFeed_Phase Get_Phase(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Phase;
}

mixin float32 Get_PhaseSeconds(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).PhaseSeconds;
}

// 0..1 within the current timed phase; 1 while idle or awaiting admission, and for a zero-length phase.
mixin float32 Get_PhaseProgress(const FCk_Handle_CookingFeed& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_CookingFeed);
    if (utils_cooking_feed::Get_IsTimed(State.Phase) == false)
    { return 1.0f; }

    const auto Duration = utils_cooking_feed::Get_PhaseDuration(Self.Get_Spec().Timing, State.Phase);
    if (Duration <= 0.0f)
    { return 1.0f; }

    return Math::Clamp(State.PhaseSeconds / Duration, 0.0f, 1.0f);
}

mixin int32 Get_Generation(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Generation;
}

// Unreserved stock: what a hint calls "left".
mixin int32 Get_Available(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Available;
}

mixin int32 Get_Admitted(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Admitted;
}

mixin int32 Get_InitialStock(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Spec().Supply.InitialCount;
}

mixin bool Get_IsBusy(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Phase != EMars_CookingFeed_Phase::Idle;
}

// Set from BeginTransfer until the admission answer (or a Cancel / Reset).
mixin TOptional<FMars_CookingFeed_PieceId> TryGet_ActivePiece(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Active;
}

// Reserved or spent; false outside [0, SlotCapacity).
mixin bool Get_IsSlotTaken(const FCk_Handle_CookingFeed& Self, int32 InSlot)
{
    const auto& SlotTaken = Self.Get_Fragment(FMars_Fragment_CookingFeed).SlotTaken;
    if (SlotTaken.IsValidIndex(InSlot) == false)
    { return false; }

    return SlotTaken[InSlot];
}

// The last release sampled (valid through AwaitAdmission; stale afterwards).
mixin FMars_CookingFeed_Release Get_PendingRelease(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).PendingRelease;
}

mixin FCk_Handle_Transform Get_ReleaseNode(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed_Params).Spec.Nodes.Release;
}

// InitialCount == Available + (an active reservation ? 1 : 0) + Admitted.
mixin bool Get_IsLedgerConsistent(const FCk_Handle_CookingFeed& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_CookingFeed);
    const auto Reserved = State.Active.IsSet() ? 1 : 0;
    return Self.Get_InitialStock() == State.Available + Reserved + State.Admitted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_BeginTransfer(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_BeginTransfer& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.BeginTransferRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_Cancel& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.CancelRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_ResolveAdmission(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_ResolveAdmission& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.ResolveAdmissionRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnStockChanged(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnStockChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnStockChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStockChanged(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnStockChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnStockChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPhaseChanged(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReleaseRequested(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnReleaseRequested InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnReleaseRequested.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReleaseRequested(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnReleaseRequested InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnReleaseRequested.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTransferSettled(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnTransferSettled InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnTransferSettled.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTransferSettled(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnTransferSettled InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferSettled.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTransferRefused(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnTransferRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnTransferRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTransferRefused(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnTransferRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
