namespace utils_tumbler
{
    // Composes the minigame on InStation (the station entity, which carries the root transform). The spec's Nodes are built
    // by the caller: the hand starts Free at the workspace centre, the hatch and the drum in whatever state their Movers are
    // in. Nothing is in the drum until the first AddPiece. A rejected spec, a missing node, a lever that is not a
    // ManuallyCompleted Control with a Mover, or a hand node not on the station root ensures and returns an invalid handle.
    FCk_Handle_Tumbler Add(FCk_Handle& InStation, FMars_Tumbler_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Tumbler] [{InStation.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Tumbler(); }

        const auto& Nodes = InSpec.Nodes;
        const auto NodesAreValid = ck::IsValid(Nodes.Hand) && ck::IsValid(Nodes.HatchTab) && ck::IsValid(Nodes.LeverGrip)
            && ck::IsValid(Nodes.Lever) && ck::IsValid(Nodes.Hatch) && ck::IsValid(Nodes.Drum) && ck::IsValid(Nodes.View);
        if (ck::EnsureIfNot(NodesAreValid,
            f"[Tumbler] [{InStation.ToString()}] needs the hand, hatch tab, lever grip, lever, hatch, drum and view nodes"))
        { return FCk_Handle_Tumbler(); }

        if (ck::EnsureIfNot(ck::IsValid(Nodes.Lever.Get_Mover()),
            f"[Tumbler] [{InStation.ToString()}] needs a lever Control with a Mover (the drum)"))
        { return FCk_Handle_Tumbler(); }

        if (ck::EnsureIfNot(Nodes.Lever.Get_CompletionPolicy() == ECk_Interaction_CompletionPolicy::ManuallyCompleted,
            f"[Tumbler] [{InStation.ToString()}] needs a ManuallyCompleted lever (it is gripped), not {Nodes.Lever.Get_CompletionPolicy() :n}"))
        { return FCk_Handle_Tumbler(); }

        // The kernel writes the hand's offset in the station frame.
        const FCk_Handle HandParent = utils_scene_node::Get_Parent(Nodes.Hand);
        if (ck::EnsureIfNot(HandParent == InStation,
            f"[Tumbler] [{InStation.ToString()}] needs the hand node on the station root (its offset is the station-frame hand pose)"))
        { return FCk_Handle_Tumbler(); }

        auto Params = FMars_Fragment_Tumbler_Params();
        Params.Spec = InSpec;

        InStation.Add_Fragment(FMars_Feature_Tumbler());
        InStation.Add_Fragment(Params);

        auto Drum = Nodes.Lever.Get_Mover();
        auto State = FMars_Fragment_Tumbler();
        State.Hand.HandLocal = InSpec.Hand.WorkspaceCentreLocal;
        State.Hand.HandRotationLocal = Get_FreeRotation();
        State.Hatch = Get_HatchFromMover(Nodes.Hatch);
        State.Drum = Get_DrumAtRest(Drum) ? EMars_Tumbler_Drum::Home : EMars_Tumbler_Drum::Returning;
        State.DrumDegrees = Drum.Get_Alpha() * InSpec.Drum.ArcDegrees;
        InStation.Add_Fragment(State);

        ck::Trace(f"[Tumbler] [{InStation.ToString()}] composed: hatch {State.Hatch :n}, drum {State.Drum :n}, capacity {InSpec.Drum.Capacity}");
        return InStation.As_Tumbler();
    }

    // The cursor's point on the reach plane, station frame.
    FVector Get_PlanePoint(const FMars_Tumbler_HandSpec& InHand, FVector2D InCursor)
    {
        return InHand.WorkspaceCentreLocal + FVector(0.0, InCursor.X, InCursor.Y);
    }

    // The world angle a piece in InSlot settles toward: the batch fanned 7 degrees apart about the bottom.
    float32 Get_RestOffsetDegrees(int32 InSlot, int32 InCapacity)
    {
        return (float32(Get_Wrapped(InSlot, InCapacity)) - float32(InCapacity - 1) * 0.5f) * 7.0f;
    }

    // Three lanes along the axle, by slot.
    float32 Get_AxialCm(int32 InSlot, float32 InHalfLength)
    {
        return float32(Get_Wrapped(InSlot, 3) - 1) * InHalfLength * 0.8f;
    }

    // A piece node's offset in the drum frame: on the orbit circle at InOrbitDegrees from the bottom, rolled by the same angle.
    FTransform Get_PieceOffset(float32 InOrbitDegrees, float32 InAxialCm, float32 InRadius)
    {
        const auto Angle = Math::DegreesToRadians(float64(InOrbitDegrees));
        const auto Radius = float64(InRadius);
        const auto Location = FVector(Radius * Math::Sin(Angle), float64(InAxialCm), -Radius * Math::Cos(Angle));
        return FTransform(FRotator(float64(InOrbitDegrees), 0.0, 0.0), Location);
    }

    // The free pointing frame (station frame): fingers at the station, palm down.
    FQuat Get_FreeRotation()
    {
        return FQuat(FRotator::MakeFromXZ(FVector::ForwardVector, -FVector::UpVector));
    }

    // 0..1 eased in and out.
    float32 Get_InOutSine(float32 InAlpha)
    {
        const auto Alpha = Math::Clamp(float64(InAlpha), 0.0, 1.0);
        return float32(0.5 - 0.5 * Math::Cos(Alpha * Math::DegreesToRadians(180.0)));
    }

    // The index of the piece carrying InPieceId; -1 = none. Internal to the kernel: callers outside it address pieces by
    // identity through the getters.
    int32 Find_PieceIndex(const TArray<FMars_Tumbler_PieceState>& InPieces, const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Id.Get_IsSame(InPieceId))
            { return Index; }
        }

        return -1;
    }

    // The hatch state its Mover shows: resting at a pose, or moving toward one.
    EMars_Tumbler_Hatch Get_HatchFromMover(const FCk_Handle_Mover& InHatch)
    {
        const auto ToOpen = InHatch.Get_Target() == EMars_Mover_Pose::End;
        if (InHatch.Get_IsResting())
        { return ToOpen ? EMars_Tumbler_Hatch::Open : EMars_Tumbler_Hatch::Closed; }

        return ToOpen ? EMars_Tumbler_Hatch::Opening : EMars_Tumbler_Hatch::Closing;
    }

    // The axle Mover rests at its start pose (home).
    bool Get_DrumAtRest(const FCk_Handle_Mover& InDrum)
    {
        return InDrum.Get_IsResting() && InDrum.Get_Target() == EMars_Mover_Pose::Start;
    }

    // The hatch toggles only at home, settled, with a free hand, and not shut on a piece in flight.
    bool Get_CanToggleHatch(const FMars_Fragment_Tumbler& InState)
    {
        const auto Settled = InState.Hatch == EMars_Tumbler_Hatch::Closed || InState.Hatch == EMars_Tumbler_Hatch::Open;
        const auto ClosingOnTransfer = InState.Hatch == EMars_Tumbler_Hatch::Open && InState.Loading == EMars_Tumbler_Loading::InFlight;
        return InState.Drum == EMars_Tumbler_Drum::Home && Settled && ClosingOnTransfer == false
            && InState.Hand.Mode == EMars_Tumbler_HandMode::Free;
    }

    // A regrip while Returning is allowed: BeginManipulation scrubs from the current alpha.
    bool Get_CanGrip(const FMars_Fragment_Tumbler& InState)
    {
        return InState.Hatch == EMars_Tumbler_Hatch::Closed && InState.Loading == EMars_Tumbler_Loading::Idle
            && InState.Hand.Mode == EMars_Tumbler_HandMode::Free;
    }

    bool Get_CanLoad(const FMars_Fragment_Tumbler& InState, int32 InCapacity)
    {
        return InState.Hatch == EMars_Tumbler_Hatch::Open && InState.Drum == EMars_Tumbler_Drum::Home
            && InState.Loading == EMars_Tumbler_Loading::Idle && InState.Pieces.Num() < InCapacity;
    }

    // Why a hatch press is refused; only meaningful when Get_CanToggleHatch is false.
    EMars_Tumbler_Refusal Get_HatchRefusal(const FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hand.Mode != EMars_Tumbler_HandMode::Free)
        { return EMars_Tumbler_Refusal::HandBusy; }

        if (InState.Drum != EMars_Tumbler_Drum::Home)
        { return EMars_Tumbler_Refusal::NotHome; }

        if (InState.Hatch == EMars_Tumbler_Hatch::Opening || InState.Hatch == EMars_Tumbler_Hatch::Closing)
        { return EMars_Tumbler_Refusal::HatchMoving; }

        return EMars_Tumbler_Refusal::LoadingInFlight;
    }

    // Why a lever press is refused; only meaningful when Get_CanGrip is false.
    EMars_Tumbler_Refusal Get_GripRefusal(const FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hand.Mode != EMars_Tumbler_HandMode::Free)
        { return EMars_Tumbler_Refusal::HandBusy; }

        if (InState.Hatch == EMars_Tumbler_Hatch::Opening || InState.Hatch == EMars_Tumbler_Hatch::Closing)
        { return EMars_Tumbler_Refusal::HatchMoving; }

        if (InState.Hatch == EMars_Tumbler_Hatch::Open)
        { return EMars_Tumbler_Refusal::HatchOpen; }

        return EMars_Tumbler_Refusal::LoadingInFlight;
    }

    // InValue wrapped into [0, InCount): a slot index past the capacity reuses the fan.
    int32 Get_Wrapped(int32 InValue, int32 InCount)
    {
        if (InCount <= 0)
        { return 0; }

        return ((InValue % InCount) + InCount) % InCount;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Tumbler_Spec Get_Spec(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler_Params).Spec;
}

mixin EMars_Tumbler_HandMode Get_HandMode(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hand.Mode;
}

// Station frame.
mixin FVector Get_HandLocal(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hand.HandLocal;
}

// (Y, Z) on the reach plane relative to the workspace centre, clamped to the half extents.
mixin FVector2D Get_Cursor(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hand.Cursor;
}

mixin EMars_Tumbler_Target Get_Hovered(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hovered;
}

mixin EMars_Tumbler_Hatch Get_Hatch(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hatch;
}

mixin EMars_Tumbler_Drum Get_Drum(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Drum;
}

mixin EMars_Tumbler_Loading Get_Loading(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Loading;
}

mixin float32 Get_DrumDegrees(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).DrumDegrees;
}

mixin int32 Get_PieceCount(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Pieces.Num();
}

mixin bool Get_CanToggleHatch(const FCk_Handle_Tumbler& Self)
{
    return utils_tumbler::Get_CanToggleHatch(Self.Get_Fragment(FMars_Fragment_Tumbler));
}

mixin bool Get_CanGrip(const FCk_Handle_Tumbler& Self)
{
    return utils_tumbler::Get_CanGrip(Self.Get_Fragment(FMars_Fragment_Tumbler));
}

mixin bool Get_CanLoad(const FCk_Handle_Tumbler& Self)
{
    return utils_tumbler::Get_CanLoad(Self.Get_Fragment(FMars_Fragment_Tumbler), Self.Get_Spec().Drum.Capacity);
}

// The station root's world transform (the station frame).
mixin FTransform Get_RootWorld(const FCk_Handle_Tumbler& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

//--------------------------------------------------------------------------------------------------------------------------
// Piece getters (by identity). An unknown Id ensures and answers the zero value; Get_HasPiece asks first.
//--------------------------------------------------------------------------------------------------------------------------

// Every piece in the drum, in admission order.
mixin TArray<FMars_CookingFeed_PieceId> Get_PieceIds(const FCk_Handle_Tumbler& Self)
{
    TArray<FMars_CookingFeed_PieceId> Ids;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Tumbler).Pieces)
    { Ids.Add(Piece.Id); }

    return Ids;
}

mixin bool Get_HasPiece(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_tumbler::Find_PieceIndex(Self.Get_Fragment(FMars_Fragment_Tumbler).Pieces, InPieceId) >= 0;
}

// A copy of the piece's state; an unknown Id ensures and answers a default state.
mixin FMars_Tumbler_PieceState Get_PieceState(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_Tumbler).Pieces;
    const auto Index = utils_tumbler::Find_PieceIndex(Pieces, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Tumbler] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} ({Pieces.Num()} in the drum)"))
    { return FMars_Tumbler_PieceState(); }

    return Pieces[Index];
}

mixin float32 Get_PieceCoverage(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Coverage;
}

// Drum frame, 0 = the drum's bottom at home.
mixin float32 Get_PieceOrbitDegrees(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).OrbitDegrees;
}

mixin int32 Get_PiecePresetIndex(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).PresetIndex;
}

mixin FCk_Handle Get_PieceEntity(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Entity;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Reset(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Cancel& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.CancelRequests.Add(InRequest);
}

mixin void Request_SetLoading(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_SetLoading& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.SetLoadingRequests.Add(InRequest);
}

mixin void Request_AddPiece(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_AddPiece& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.AddPieceRequests.Add(InRequest);
}

mixin void Request_Press(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Press& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.PressRequests.Add(InRequest);
}

mixin void Request_Release(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Release& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.ReleaseRequests.Add(InRequest);
}

mixin void Request_Look(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Look& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.LookRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHandModeChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHandModeChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnHandModeChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHandModeChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHandModeChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHandModeChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHoverChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHoverChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnHoverChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHoverChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHoverChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHoverChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHatchChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHatchChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnHatchChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHatchChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHatchChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHatchChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnDrumChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnDrumChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnDrumChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDrumChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnDrumChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnDrumChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPressRefused(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPressRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnPressRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPressRefused(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPressRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPressRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdmission(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceAdmission InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnPieceAdmission.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdmission(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceAdmission InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceAdmission.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdded(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceAdded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnPieceAdded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdded(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceAdded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceAdded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCoverageChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnCoverageChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnCoverageChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCoverageChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnCoverageChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnCoverageChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
