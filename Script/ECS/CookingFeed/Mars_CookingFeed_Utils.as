namespace utils_cooking_feed
{
    // Composes the feed on InHandle (the station entity; the feature does not need the Station feature). The spec's Nodes are
    // built by the caller: Nodes.Release is sampled at every release. The feed starts unsourced (control sets the source
    // from the station's input dock) with the hand idle. A rejected spec or a missing release node ensures and returns an
    // invalid handle.
    FCk_Handle_CookingFeed Add(FCk_Handle& InHandle, FMars_CookingFeed_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[CookingFeed] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_CookingFeed(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Release), f"[CookingFeed] [{InHandle.ToString()}] needs a release node"))
        { return FCk_Handle_CookingFeed(); }

        auto Params = FMars_Fragment_CookingFeed_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_CookingFeed());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_CookingFeed());
        return InHandle.As_CookingFeed();
    }

    // What the source holds less a reserved piece still on it; 0 without a source. Once the bridge has unloaded the
    // reserved piece for its release it is already off the count.
    int32 Get_Available(const FMars_Fragment_CookingFeed& InState)
    {
        if (ck::Is_NOT_Valid(InState.Source))
        { return 0; }

        const auto Reserved = InState.Active.IsSet() && Get_IsOnSource(InState.Active.GetValue().Piece, InState.Source) ? 1 : 0;
        return InState.Source.Get_HeldCount() - Reserved;
    }

    // InPiece is alive and InSource (a valid platter) holds it, landed or pending.
    bool Get_IsOnSource(const FCk_Handle_FoodPiece& InPiece, const FCk_Handle_Platter& InSource)
    {
        if (ck::Is_NOT_Valid(InPiece) || ck::Is_NOT_Valid(InSource))
        { return false; }

        if (utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return false; }

        return InPiece.TryGet_Platter() == InSource;
    }

    // Drops the reservation (if any) and idles the hand at once: the one cancel path (Reset, Cancel, SetSource, a reservation
    // whose piece left the source). True when a reservation was dropped; the caller read its id first and settles it
    // Cancelled.
    bool Cancel_Active(FMars_Fragment_CookingFeed& InState)
    {
        const auto HadReservation = InState.Active.IsSet();
        InState.Active.Reset();
        InState.Phase = EMars_CookingFeed_Phase::Idle;
        InState.PhaseSeconds = 0.0f;
        return HadReservation;
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

// Unreserved stock on the source: what a hint calls "left". Derived, never stored (utils_cooking_feed::Get_Available).
mixin int32 Get_Available(const FCk_Handle_CookingFeed& Self)
{
    return utils_cooking_feed::Get_Available(Self.Get_Fragment(FMars_Fragment_CookingFeed));
}

// Admissions since the last Reset.
mixin int32 Get_Admitted(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Admitted;
}

// The platter the stock is drawn from; invalid while unsourced.
mixin FCk_Handle_Platter Get_Source(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Source;
}

mixin bool Get_IsSourced(const FCk_Handle_CookingFeed& Self)
{
    return ck::IsValid(Self.Get_Source());
}

mixin bool Get_IsBusy(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Phase != EMars_CookingFeed_Phase::Idle;
}

// Set from BeginTransfer until the admission answer (or a Cancel / Reset / SetSource).
mixin TOptional<FMars_CookingFeed_PieceId> TryGet_ActivePiece(const FCk_Handle_CookingFeed& Self)
{
    const auto& Active = Self.Get_Fragment(FMars_Fragment_CookingFeed).Active;
    if (Active.IsSet() == false)
    { return TOptional<FMars_CookingFeed_PieceId>(); }

    return TOptional<FMars_CookingFeed_PieceId>(Active.GetValue().Id);
}

// The reserved piece; invalid while idle.
mixin FCk_Handle_FoodPiece TryGet_ActiveFoodPiece(const FCk_Handle_CookingFeed& Self)
{
    const auto& Active = Self.Get_Fragment(FMars_Fragment_CookingFeed).Active;
    if (Active.IsSet() == false)
    { return FCk_Handle_FoodPiece(); }

    return Active.GetValue().Piece;
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

mixin void Request_SetSource(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_SetSource& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.SetSourceRequests.Add(InRequest);
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
