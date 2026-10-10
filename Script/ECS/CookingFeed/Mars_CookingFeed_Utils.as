namespace utils_cooking_feed
{
    // Composes the feed on InHandle (the station entity; the feature does not need the Station feature). The spec's Nodes are
    // built by the caller: Nodes.Release is sampled at every release, and the reserved piece rides Nodes.Hand from its grasp
    // to its release. The feed starts unsourced (control sets the source from the station's input dock) with the hand idle.
    // A rejected spec or a missing node ensures and returns an invalid handle.
    FCk_Handle_CookingFeed Add(FCk_Handle& InHandle, FMars_CookingFeed_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[CookingFeed] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_CookingFeed(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Release), f"[CookingFeed] [{InHandle.ToString()}] needs a release node"))
        { return FCk_Handle_CookingFeed(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Hand), f"[CookingFeed] [{InHandle.ToString()}] needs a hand node to carry its pieces"))
        { return FCk_Handle_CookingFeed(); }

        auto Params = FMars_Fragment_CookingFeed_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_CookingFeed());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_CookingFeed());
        return InHandle.As_CookingFeed();
    }

    // What the source holds (frozen, settling or about to drop: a pile re-settling after a piece left is still stock) less a
    // reserved piece still on it; 0 without a source. Once the feed has unloaded the reserved piece at its grasp it is
    // already off the count.
    int32 Get_Available(const FMars_Fragment_CookingFeed& InState)
    {
        if (ck::Is_NOT_Valid(InState.Source))
        { return 0; }

        const auto Reserved = InState.Active.IsSet() && Get_IsOnSource(InState.Active.GetValue().Piece, InState.Source) ? 1 : 0;
        return InState.Source.Get_Occupancy() - Reserved;
    }

    // The source has stock but its pile is settling: nothing is frozen to reach for, so a press is refused Busy until a
    // piece freezes.
    bool Get_IsSettling(const FMars_Fragment_CookingFeed& InState)
    {
        return Get_Available(InState) > 0 && InState.Source.Get_HeldCount() == 0;
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

    // A reserved piece the feed took off its source (unloading, or riding InHand) goes back onto it: detached from the hand
    // where it is, then loaded (a load queued behind a pending unload drains after it and lands it back). A piece that is
    // gone, released, re-parented off the hand or held by another ledger stays as it is; without a live source it stays
    // where it is. Issues requests only: the caller drops the reservation (Cancel_Active).
    void Return_Piece(const FMars_Fragment_CookingFeed& InState, const FCk_Handle_Transform& InHand)
    {
        if (InState.Active.IsSet() == false)
        { return; }

        const auto Reservation = InState.Active.GetValue();
        const auto IsTaken = Reservation.Hold == EMars_CookingFeed_PieceHold::Unloading || Reservation.Hold == EMars_CookingFeed_PieceHold::InHand;
        auto Piece = Reservation.Piece;
        if (IsTaken == false || ck::Is_NOT_Valid(Piece)
            || utils_entity_lifetime::Get_IsPendingDestroy(Piece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        if (Reservation.Hold == EMars_CookingFeed_PieceHold::InHand)
        {
            if (Get_IsUnderHand(Piece, InHand) == false)
            { return; }

            FCk_Handle Entity = Piece;
            auto Node = Entity.As_SceneNode();
            utils_scene_node::Request_Detach(Node);
        }

        const auto Holder = Piece.TryGet_Platter();
        if (ck::IsValid(Holder) && Holder != InState.Source)
        { return; }

        auto Source = InState.Source;
        if (ck::Is_NOT_Valid(Source) || utils_entity_lifetime::Get_IsPendingDestroy(Source, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            ck::Trace(f"[CookingFeed] [{Piece.ToString()}] stays where it is: no live source to put it back on");
            return;
        }

        Source.Request_Load(FMars_Request_Platter_Load(Piece));
        ck::Trace(f"[CookingFeed] [{Piece.ToString()}] goes back onto [{Source.ToString()}]");
    }

    // InPiece is scene-node attached directly under InHand.
    bool Get_IsUnderHand(const FCk_Handle_FoodPiece& InPiece, const FCk_Handle_Transform& InHand)
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Node) && ck::IsValid(InHand) && utils_scene_node::Get_Parent(Node) == InHand;
    }

    // Drops the reservation (if any) and idles the hand at once: the one cancel path (Reset, Cancel, SetSource, a reservation
    // whose piece left the source). True when a reservation was dropped; the caller read its id first and settles it
    // Cancelled (and, for a piece the feed took itself, Return_Piece first).
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

mixin bool Get_IsSettling(const FCk_Handle_CookingFeed& Self)
{
    return utils_cooking_feed::Get_IsSettling(Self.Get_Fragment(FMars_Fragment_CookingFeed));
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

mixin FCk_Handle_Transform Get_HandNode(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed_Params).Spec.Nodes.Hand;
}

// Where the reserved piece is; unset while idle.
mixin TOptional<EMars_CookingFeed_PieceHold> TryGet_PieceHold(const FCk_Handle_CookingFeed& Self)
{
    const auto& Active = Self.Get_Fragment(FMars_Fragment_CookingFeed).Active;
    if (Active.IsSet() == false)
    { return TOptional<EMars_CookingFeed_PieceHold>(); }

    return TOptional<EMars_CookingFeed_PieceHold>(Active.GetValue().Hold);
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
