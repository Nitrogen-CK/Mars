namespace utils_foodboard
{
    // RuntimeMesh drains two slices a frame from a world-wide queue of 16: one chop may take half of it.
    const int32 k_MaxCutsPerChop = 8;

    // A corner this close to the plane is on it: a piece the plane only touches is not a candidate.
    const float k_StraddleToleranceCm = 0.01;

    // Composes the board on InHandle (the station entity), which must carry a Transform: the release velocity is in its frame.
    // The board starts empty and untouched. A rejected spec or a missing Transform ensures and returns an invalid handle.
    FCk_Handle_FoodBoard Add(FCk_Handle& InHandle, FMars_FoodBoard_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[FoodBoard] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_FoodBoard(); }

        const auto IsComposable = InHandle.Is_Transform() && InHandle.Is_FoodBoard() == false;
        if (ck::EnsureIfNot(IsComposable, f"[FoodBoard] [{InHandle.ToString()}] needs a Transform, and no FoodBoard yet"))
        { return FCk_Handle_FoodBoard(); }

        auto Params = FMars_Fragment_FoodBoard_Params();
        Params.Tuners = InSpec.Tuners;

        InHandle.Add_Fragment(FMars_Feature_FoodBoard());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_FoodBoard());
        return InHandle.As_FoodBoard();
    }

    // InPlane with a unit normal and a unit tangent orthogonal to it (the tangent fixes the cap UVs); unset for a non-finite
    // position, a degenerate normal, or a tangent parallel to the normal.
    TOptional<FMars_FoodPiece_WorldPlane> Get_UnitPlane(const FMars_FoodPiece_WorldPlane& InPlane)
    {
        const auto Normal = InPlane.Normal.GetSafeNormal();
        if (Get_IsFinite(InPlane.PositionCm) == false || Get_IsFinite(Normal) == false || Normal.IsNearlyZero())
        { return TOptional<FMars_FoodPiece_WorldPlane>(); }

        const auto Tangent = (InPlane.Tangent - Normal * InPlane.Tangent.DotProduct(Normal)).GetSafeNormal();
        if (Get_IsFinite(Tangent) == false || Tangent.IsNearlyZero())
        { return TOptional<FMars_FoodPiece_WorldPlane>(); }

        return TOptional<FMars_FoodPiece_WorldPlane>(FMars_FoodPiece_WorldPlane(InPlane.PositionCm, Normal, Tangent));
    }

    // Whether InA and InB are the same plane: one chop's plane, shared by every piece it cut.
    bool Get_IsSamePlane(const FMars_FoodPiece_WorldPlane& InA, const FMars_FoodPiece_WorldPlane& InB)
    {
        return InA.PositionCm.Equals(InB.PositionCm, 0.0001) && InA.Normal.Equals(InB.Normal, 0.000001);
    }

    // Whether InPlane (unit normal) has corners of InMetrics' bounds, placed at InPieceWorld, on both of its sides. The
    // bounds are conservative: a plane through a bounds corner the mesh does not fill is a candidate whose cut misses.
    bool Get_IsStraddling(const FTransform& InPieceWorld, const FCk_RuntimeMesh_Metrics& InMetrics, const FMars_FoodPiece_WorldPlane& InPlane)
    {
        const auto Min = InMetrics.Get_BoundsMinCm();
        const auto Max = InMetrics.Get_BoundsMaxCm();

        auto HasPositive = false;
        auto HasNegative = false;
        for (int32 Corner = 0; Corner < 8; ++Corner)
        {
            const auto Local = FVector((Corner & 1) != 0 ? Max.X : Min.X, (Corner & 2) != 0 ? Max.Y : Min.Y, (Corner & 4) != 0 ? Max.Z : Min.Z);
            const auto Distance = (InPieceWorld.TransformPosition(Local) - InPlane.PositionCm).DotProduct(InPlane.Normal);
            HasPositive = HasPositive || Distance > k_StraddleToleranceCm;
            HasNegative = HasNegative || Distance < -k_StraddleToleranceCm;
        }

        return HasPositive && HasNegative;
    }

    // InPiece's index in InPieces; -1 when absent.
    int32 Find_Piece(const TArray<FCk_Handle_FoodPiece>& InPieces, const FCk_Handle_FoodPiece& InPiece)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index] == InPiece)
            { return Index; }
        }

        return -1;
    }

    bool Get_IsFinite(const FVector& InVector)
    {
        return Math::IsFinite(InVector.X) && Math::IsFinite(InVector.Y) && Math::IsFinite(InVector.Z);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_FoodBoard_Tuners Get_Tuners(const FCk_Handle_FoodBoard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodBoard_Params).Tuners;
}

// Board order. A piece destroyed elsewhere leaves the ledger at the board's next drain.
mixin TArray<FCk_Handle_FoodPiece> Get_Held(const FCk_Handle_FoodBoard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodBoard).Held;
}

mixin int32 Get_HeldCount(const FCk_Handle_FoodBoard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodBoard).Held.Num();
}

// Oldest first.
mixin TArray<FCk_Handle_FoodPiece> Get_Released(const FCk_Handle_FoodBoard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodBoard).Released;
}

mixin bool Get_IsUntouched(const FCk_Handle_FoodBoard& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodBoard).IsUntouched;
}

// What a Place or a chop counts against MaxHeldPieces: the held pieces plus the second half of every cut the board has in
// flight.
mixin int32 Get_Occupancy(const FCk_Handle_FoodBoard& Self)
{
    auto Occupancy = 0;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_FoodBoard).Held)
    {
        ++Occupancy;
        if (Piece.Get_HasBoardCutPending())
        { ++Occupancy; }
    }

    return Occupancy;
}

// The board holding the piece; invalid for a piece no board holds (never placed, or released).
mixin FCk_Handle_FoodBoard TryGet_FoodBoard(const FCk_Handle_FoodPiece& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_Fragment(FMars_Fragment_FoodBoard_Membership) == false)
    { return FCk_Handle_FoodBoard(); }

    return Self.Get_Fragment(FMars_Fragment_FoodBoard_Membership).Board;
}

// Whether a cut its board submitted for the piece awaits its answer.
mixin bool Get_HasBoardCutPending(const FCk_Handle_FoodPiece& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_Fragment(FMars_Fragment_FoodBoard_Membership) == false)
    { return false; }

    return Self.Get_Fragment(FMars_Fragment_FoodBoard_Membership).PendingCutPlane.IsSet();
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Clear(FCk_Handle_FoodBoard& Self, const FMars_Request_FoodBoard_Clear& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests);
    Requests.ClearRequests.Add(InRequest);
}

mixin void Request_Place(FCk_Handle_FoodBoard& Self, const FMars_Request_FoodBoard_Place& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.Piece), f"[FoodBoard] [{Self.ToString()}] was asked to place an invalid piece"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests);
    Requests.PlaceRequests.Add(InRequest);
}

mixin void Request_Cut(FCk_Handle_FoodBoard& Self, const FMars_Request_FoodBoard_Cut& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests);
    Requests.CutRequests.Add(InRequest);
}

mixin void Request_Release(FCk_Handle_FoodBoard& Self, const FMars_Request_FoodBoard_Release& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests);
    Requests.ReleaseRequests.Add(InRequest);
}

// A rejected Turn ensures and is dropped: nothing moves.
mixin void Request_Turn(FCk_Handle_FoodBoard& Self, const FMars_Request_FoodBoard_Turn& InRequest)
{
    const auto Validation = InRequest.Validate();
    if (ck::EnsureIfNot(Validation.IsValid(), f"[FoodBoard] [{Self.ToString()}] rejected a Turn: {Validation.Get_Error()}"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests);
    Requests.TurnRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPlaced(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnPlaced InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Signals);
    Fragment.OnPlaced.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPlaced(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnPlaced InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodBoard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnPlaced.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPlaceRefused(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnPlaceRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Signals);
    Fragment.OnPlaceRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPlaceRefused(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnPlaceRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodBoard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnPlaceRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCutIssued(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnCutIssued InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Signals);
    Fragment.OnCutIssued.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCutIssued(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnCutIssued InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodBoard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnCutIssued.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceCut(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnPieceCut InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Signals);
    Fragment.OnPieceCut.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceCut(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnPieceCut InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodBoard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnPieceCut.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReleased(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnReleased InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Signals);
    Fragment.OnReleased.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReleased(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnReleased InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodBoard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnReleased.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCleared(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnCleared InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Signals);
    Fragment.OnCleared.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCleared(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnCleared InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodBoard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnCleared.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTurned(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnTurned InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Signals);
    Fragment.OnTurned.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTurned(FCk_Handle_FoodBoard& Self, FMars_Delegate_FoodBoard_OnTurned InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodBoard_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnTurned.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
