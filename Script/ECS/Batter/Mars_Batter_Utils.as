namespace utils_batter
{
    // A coat this close to 1 is complete (the clock clamps at 1; this only absorbs float drift).
    const float32 k_CoatComplete = 0.9999f;

    // Composes the batter bowl on InStation (the station entity) and makes the station a receiver: its admission inbox and
    // its take-out readout. The spec's Nodes are built by the caller. The bowl starts Resting and empty: nothing is in it
    // until the inbox brings a piece. A rejected spec or a missing bowl node ensures and returns an invalid handle.
    FCk_Handle_Batter Add(FCk_Handle& InStation, FMars_Batter_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Batter] [{InStation.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Batter(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Bowl), f"[Batter] [{InStation.ToString()}] needs the bowl node"))
        { return FCk_Handle_Batter(); }

        auto Params = FMars_Fragment_Batter_Params();
        Params.Spec = InSpec;

        InStation.Add_Fragment(FMars_Feature_Batter());
        InStation.Add_Fragment(Params);
        InStation.Add_Fragment(FMars_Fragment_Batter());
        // The first drain arms the station's queue watch.
        InStation.Add_Fragment(FMars_Fragment_Batter_Requests());
        utils_cooking_feed::Add_Admission(InStation);
        utils_cooking_feed::Add_TakeOut(InStation);

        return InStation.As_Batter();
    }

    // The bowl takes a piece that is whole (never cut: a cut thing is not batterable) and whose food has a battered variant.
    // A bare piece (no food) is not batterable. The one rule for "this piece can wear a battered shell": the assembly's
    // Write_PieceLook reads it too.
    bool Get_IsBatterable(const FCk_Handle_FoodPiece& InPiece)
    {
        if (InPiece.Get_IsWhole() == false)
        { return false; }

        const UMars_Food_Def Food = InPiece.Get_Definition().Get();
        return ck::IsValid(Food) && Food.Get_IsBatterable();
    }

    // The ledger's dip: written 1 by the bowl's take-out, inherited by a cut half.
    bool Get_IsBattered(const FMars_FoodPiece_CookState& InCookState)
    {
        return InCookState.Battered >= 0.5f;
    }

    // Some piece on InPlatter (held, settling or queued) has a battered ledger; false with no platter. A fryer's add-food
    // gate reads it: a platter with nothing battered on it has nothing the fryer would admit.
    bool Get_HasBatteredPiece(const FCk_Handle_Platter& InPlatter)
    {
        if (ck::Is_NOT_Valid(InPlatter))
        { return false; }

        for (const auto& Piece : InPlatter.Get_Pieces())
        {
            if (ck::IsValid(Piece) && Get_IsBattered(Piece.Get_CookState()))
            { return true; }
        }

        return false;
    }

    // Why the bowl, as InState is, would not take InPiece (the piece rules only: identity and readiness are the drain's).
    // Unset = it would. Checked in order NotWhole, NotBatterable, AlreadyBattered, Full.
    TOptional<EMars_Batter_AdmissionRefusal> Get_PieceRefusal(const FMars_Fragment_Batter& InState, const FMars_Batter_Spec& InSpec,
        const FCk_Handle_FoodPiece& InPiece)
    {
        if (InPiece.Get_IsWhole() == false)
        { return TOptional<EMars_Batter_AdmissionRefusal>(EMars_Batter_AdmissionRefusal::NotWhole); }

        if (Get_IsBatterable(InPiece) == false)
        { return TOptional<EMars_Batter_AdmissionRefusal>(EMars_Batter_AdmissionRefusal::NotBatterable); }

        if (Get_IsBattered(InPiece.Get_CookState()))
        { return TOptional<EMars_Batter_AdmissionRefusal>(EMars_Batter_AdmissionRefusal::AlreadyBattered); }

        if (InState.Pieces.Num() >= InSpec.Bowl.Capacity)
        { return TOptional<EMars_Batter_AdmissionRefusal>(EMars_Batter_AdmissionRefusal::Full); }

        return TOptional<EMars_Batter_AdmissionRefusal>();
    }

    // The lowest slot no piece in InPieces sits in; -1 = none free.
    int32 Get_FreeSlot(const TArray<FMars_Batter_PieceState>& InPieces, int32 InCapacity)
    {
        for (int32 Slot = 0; Slot < InCapacity; ++Slot)
        {
            auto IsTaken = false;
            for (const auto& Piece : InPieces)
            {
                if (Piece.Slot == Slot)
                { IsTaken = true; }
            }

            if (IsTaken == false)
            { return Slot; }
        }

        return -1;
    }

    // Where slot InSlot puts a piece's bounds centre in the bowl node's frame at InImmersion (0 rest .. 1 fully dipped): on the
    // ring (the middle for a one-slot bowl), RestZ up, DipDepthCm lower when fully dipped.
    FVector Get_SlotPoint(const FMars_Batter_BowlSpec& InBowl, int32 InSlot, float32 InImmersion)
    {
        const auto Radius = InBowl.Capacity > 1 ? float64(InBowl.SlotRadius) : 0.0;
        const auto Angle = Math::DegreesToRadians(360.0 * float64(InSlot) / float64(Math::Max(1, InBowl.Capacity)));
        const auto Z = float64(InBowl.RestZ) - float64(InBowl.DipDepthCm) * float64(Math::Clamp(InImmersion, 0.0f, 1.0f));
        return FVector(Radius * Math::Cos(Angle), Radius * Math::Sin(Angle), Z);
    }

    // The piece's offset under the bowl node: upright, its bounds centre on its slot point.
    FTransform Get_PieceOffset(const FMars_Batter_BowlSpec& InBowl, const FMars_Batter_PieceState& InPiece)
    {
        const auto Centre = utils_foodpiece::Get_BoundsCentre(utils_runtime_mesh::Get_Metrics(InPiece.Piece.Get_Geometry()));
        return FTransform(FQuat::Identity, Get_SlotPoint(InBowl, InPiece.Slot, InPiece.Immersion) - Centre);
    }

    EMars_Batter_CoatStage Get_CoatStage(float32 InCoat)
    {
        if (InCoat >= k_CoatComplete)
        { return EMars_Batter_CoatStage::Coated; }

        if (InCoat > 0.0f)
        { return EMars_Batter_CoatStage::Coating; }

        return EMars_Batter_CoatStage::Bare;
    }

    bool Get_IsCoated(const FMars_Batter_PieceState& InPiece)
    {
        return InPiece.Coat >= k_CoatComplete;
    }

    // Fully coated and lifted back to rest: the kernel has stopped posing it, so nothing it asked of the piece's node is
    // still in flight when a take-out detaches it.
    bool Get_IsTakeable(const FMars_Batter_PieceState& InPiece)
    {
        return Get_IsCoated(InPiece) && InPiece.Immersion <= 0.0f;
    }

    // What a take-out would hand back now: every takeable piece (Get_IsTakeable), in admission order.
    TArray<FCk_Handle_FoodPiece> Get_Takeable(const TArray<FMars_Batter_PieceState>& InPieces)
    {
        TArray<FCk_Handle_FoodPiece> Takeable;
        for (const auto& Piece : InPieces)
        {
            if (ck::IsValid(Piece.Piece) && Get_IsTakeable(Piece))
            { Takeable.Add(Piece.Piece); }
        }

        return Takeable;
    }

    // The index of the piece carrying InPieceId; -1 = none. Internal to the kernel: callers outside it address pieces by
    // identity through the getters.
    int32 Find_PieceIndex(const TArray<FMars_Batter_PieceState>& InPieces, const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Id.Get_IsSame(InPieceId))
            { return Index; }
        }

        return -1;
    }

    // The index of the piece record holding InPiece; -1 = none.
    int32 Find_PieceIndexByHandle(const TArray<FMars_Batter_PieceState>& InPieces, const FCk_Handle_FoodPiece& InPiece)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Piece == InPiece)
            { return Index; }
        }

        return -1;
    }

    // The station's feed's phase (Idle without a feed): anything but Idle is a transfer in flight.
    EMars_CookingFeed_Phase Get_FeedPhase(const FCk_Handle& InStation)
    {
        const auto Feed = InStation.As_CookingFeed(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Feed))
        { return EMars_CookingFeed_Phase::Idle; }

        return Feed.Get_Phase();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Batter_Spec Get_Spec(const FCk_Handle_Batter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Batter_Params).Spec;
}

mixin EMars_Batter_Bowl Get_Bowl(const FCk_Handle_Batter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Batter).Bowl;
}

mixin int32 Get_PieceCount(const FCk_Handle_Batter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Batter).Pieces.Num();
}

// Pieces fully coated (what a take-out would hand back).
mixin int32 Get_CoatedCount(const FCk_Handle_Batter& Self)
{
    return utils_batter::Get_Takeable(Self.Get_Fragment(FMars_Fragment_Batter).Pieces).Num();
}

// Room in the bowl and no transfer in flight: the add-food press's gate.
mixin bool Get_CanLoad(const FCk_Handle_Batter& Self)
{
    return Self.Get_PieceCount() < Self.Get_Spec().Bowl.Capacity && utils_batter::Get_FeedPhase(Self) == EMars_CookingFeed_Phase::Idle;
}

// The bowl node's world transform.
mixin FTransform Get_BowlWorld(const FCk_Handle_Batter& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.Get_Spec().Nodes.Bowl);
}

//--------------------------------------------------------------------------------------------------------------------------
// Piece getters (by identity). An unknown Id ensures and answers the zero value; Get_HasPiece asks first.
//--------------------------------------------------------------------------------------------------------------------------

// Every piece in the bowl, in admission order.
mixin TArray<FMars_CookingFeed_PieceId> Get_PieceIds(const FCk_Handle_Batter& Self)
{
    TArray<FMars_CookingFeed_PieceId> Ids;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Batter).Pieces)
    { Ids.Add(Piece.Id); }

    return Ids;
}

mixin bool Get_HasPiece(const FCk_Handle_Batter& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_batter::Find_PieceIndex(Self.Get_Fragment(FMars_Fragment_Batter).Pieces, InPieceId) >= 0;
}

// A copy of the piece's state; an unknown Id ensures and answers a default state.
mixin FMars_Batter_PieceState Get_PieceState(const FCk_Handle_Batter& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_Batter).Pieces;
    const auto Index = utils_batter::Find_PieceIndex(Pieces, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Batter] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} ({Pieces.Num()} in the bowl)"))
    { return FMars_Batter_PieceState(); }

    return Pieces[Index];
}

mixin float32 Get_PieceCoat(const FCk_Handle_Batter& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Coat;
}

mixin float32 Get_PieceImmersion(const FCk_Handle_Batter& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Immersion;
}

mixin FCk_Handle_FoodPiece Get_PieceHandle(const FCk_Handle_Batter& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Piece;
}

mixin FCk_Handle Get_PieceEntity(const FCk_Handle_Batter& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Entity;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Reset(FCk_Handle_Batter& Self, const FMars_Request_Batter_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_Dip(FCk_Handle_Batter& Self, const FMars_Request_Batter_Dip& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Requests);
    Requests.DipRequests.Add(InRequest);
}

mixin void Request_Lift(FCk_Handle_Batter& Self, const FMars_Request_Batter_Lift& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Requests);
    Requests.LiftRequests.Add(InRequest);
}

mixin void Request_Readopt(FCk_Handle_Batter& Self, const FMars_Request_Batter_Readopt& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Requests);
    Requests.ReadoptRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnBowlChanged(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnBowlChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Signals);
    Fragment.OnBowlChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBowlChanged(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnBowlChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Batter_Signals).OnBowlChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdded(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnPieceAdded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Signals);
    Fragment.OnPieceAdded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdded(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnPieceAdded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Batter_Signals).OnPieceAdded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnAdmissionRefused(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnAdmissionRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Signals);
    Fragment.OnAdmissionRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnAdmissionRefused(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnAdmissionRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Batter_Signals).OnAdmissionRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCoatStage(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnCoatStage InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Signals);
    Fragment.OnCoatStage.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCoatStage(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnCoatStage InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Batter_Signals).OnCoatStage.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceTakenOut(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnPieceTakenOut InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Signals);
    Fragment.OnPieceTakenOut.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceTakenOut(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnPieceTakenOut InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Batter_Signals).OnPieceTakenOut.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTakeOutRefused(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnTakeOutRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Batter_Signals);
    Fragment.OnTakeOutRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTakeOutRefused(FCk_Handle_Batter& Self, FMars_Delegate_Batter_OnTakeOutRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Batter_Signals).OnTakeOutRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
