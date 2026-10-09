namespace utils_searing
{
    const int32 k_FaceCount = 6;
    const int32 k_SearSignalSteps = 10;
    // The cooking surface's height in the pan body's frame: the pan node sits at the centre of that surface (the pan mesh's
    // pivot), so a piece is judged relative to Z 0.
    const float32 k_PanSurfaceZ = 0.0f;
    // The pan body's mass: see Add_PanBody.
    const float32 k_PanBodyMassKg = 1.0f;
    // How long a new down face must stay down on the pan before it is the resting face (a flip): a tumbling cube passes
    // other faces down for a frame or two, and neither the liftoff nor the first contact shows the face it settles on.
    const float32 k_FaceSettleSeconds = 0.1f;
    // How far an adopted piece's transform may read from its release location and count as arrived.
    const float64 k_ArrivalToleranceCm = 5.0;
    // How long an adopted piece may take to arrive: past it the kernel ensures (its pose never got there) and judges it
    // where it is, so a piece is never left unjudged.
    const float32 k_ArrivalMaxSeconds = 1.0f;

    // Composes the minigame on InHandle (the station entity; the feature does not need the Station feature). The spec's
    // Nodes are built by the caller: Nodes.Pan is the Implement on the pan node (the kernel makes it Driven while hot and
    // forwards the looks to it), and a piece counts as on the pan only while it rests on Nodes.PanBaseBody. The pan starts
    // empty: pieces arrive only through Request_AddPiece. A rejected spec or a missing node ensures and returns an invalid
    // handle.
    FCk_Handle_Searing Add(FCk_Handle& InHandle, FMars_Searing_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Searing] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Searing(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Pan) && ck::IsValid(InSpec.Nodes.PanBaseBody),
            f"[Searing] [{InHandle.ToString()}] needs a pan implement and a pan base body"))
        { return FCk_Handle_Searing(); }

        auto Params = FMars_Fragment_Searing_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Searing());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Searing());
        return InHandle.As_Searing();
    }

    // The kinematic pan body on its own child node at the pan node's origin (a body needs its own entity). The body is
    // created after its mesh preloads: callers that need it read utils_jolt_body::Get_IsBodyAdded. A rejected spec ensures
    // and returns an invalid handle.
    FCk_Handle_JoltBody Add_PanBody(FCk_Handle_SceneNode& InPanNode, const FMars_Searing_PanBodySpec& InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Searing] [{InPanNode.ToString()}] rejected the pan body spec: {Validation.Get_Error()}"))
        { return FCk_Handle_JoltBody(); }

        auto BodyNode = utils_scene_node::Create(InPanNode.As_Transform(), FTransform::Identity);

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::StaticMeshAsset);
        BodySpec.Set_StaticMesh(InSpec.Mesh);
        BodySpec.Set_ShapeScale(FVector(InSpec.Scale, InSpec.Scale, InSpec.Scale));
        BodySpec.Set_MotionType(ECk_MotionType::Kinematic);
        // Jolt asserts a positive mass even on a kinematic body, and a mesh shape computes none; the value is never used.
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(k_PanBodyMassKg);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(InSpec.Friction);
        BodySpec.Set_Restitution(InSpec.Restitution);
        BodySpec.Set_CollisionProfileName(n"BlockAll");
        return utils_jolt_body::Add(BodyNode.H(), BodySpec);
    }

    // The index of the piece carrying InPieceId (lingering lost ones included); -1 = none. Internal to the kernel: callers
    // outside it address pieces by identity through the getters.
    int32 Find_PieceIndex(const TArray<FMars_Searing_PieceState>& InPieces, const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Id.Get_IsSame(InPieceId))
            { return Index; }
        }

        return -1;
    }

    // The index of the piece whose entity is InPiece (lingering lost ones included); -1 = none.
    int32 Find_PieceIndexByHandle(const TArray<FMars_Searing_PieceState>& InPieces, const FCk_Handle_FoodPiece& InPiece)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Piece == InPiece)
            { return Index; }
        }

        return -1;
    }

    // Pieces not Lost (cooking or ready).
    int32 Get_LivePieceCount(const TArray<FMars_Searing_PieceState>& InPieces)
    {
        auto Count = 0;
        for (const auto& Piece : InPieces)
        {
            if (Piece.Status != EMars_Searing_PieceStatus::Lost)
            { Count += 1; }
        }

        return Count;
    }

    int32 Get_SearedFaceCount(const TArray<float32>& InFaceSear)
    {
        auto Count = 0;
        for (const auto Sear : InFaceSear)
        {
            if (Sear >= 1.0f)
            { Count += 1; }
        }

        return Count;
    }

    // The face's outward normal in the piece's own frame.
    FVector Get_FaceNormal(EMars_Searing_Face InFace)
    {
        switch (InFace)
        {
            case EMars_Searing_Face::PosX: return FVector(1.0, 0.0, 0.0);
            case EMars_Searing_Face::NegX: return FVector(-1.0, 0.0, 0.0);
            case EMars_Searing_Face::PosY: return FVector(0.0, 1.0, 0.0);
            case EMars_Searing_Face::NegY: return FVector(0.0, -1.0, 0.0);
            case EMars_Searing_Face::PosZ: return FVector(0.0, 0.0, 1.0);
            default: return FVector(0.0, 0.0, -1.0);
        }
    }

    EMars_Searing_Face Get_OppositeFace(EMars_Searing_Face InFace)
    {
        switch (InFace)
        {
            case EMars_Searing_Face::PosX: return EMars_Searing_Face::NegX;
            case EMars_Searing_Face::NegX: return EMars_Searing_Face::PosX;
            case EMars_Searing_Face::PosY: return EMars_Searing_Face::NegY;
            case EMars_Searing_Face::NegY: return EMars_Searing_Face::PosY;
            case EMars_Searing_Face::PosZ: return EMars_Searing_Face::NegZ;
            default: return EMars_Searing_Face::PosZ;
        }
    }

    // The face whose world normal (InPieceRotation applied to its body normal) has the smallest dot with InPanUp.
    EMars_Searing_Face Get_DownFace(const FQuat& InPieceRotation, const FVector& InPanUp)
    {
        auto Best = EMars_Searing_Face::NegZ;
        auto BestDot = 2.0;
        for (int32 Index = 0; Index < k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            const auto Dot = InPieceRotation.RotateVector(Get_FaceNormal(Face)).DotProduct(InPanUp);
            if (Dot < BestDot)
            {
                BestDot = Dot;
                Best = Face;
            }
        }

        return Best;
    }

    // The piece rotation that lays InFace against -Z. MakeFromXZ(X, -N) turns the body's +Z onto -N (X is any body axis
    // perpendicular to N); its inverse is the rotation that turns N onto -Z.
    FRotator Make_FaceDownRotation(EMars_Searing_Face InFace)
    {
        const auto Normal = Get_FaceNormal(InFace);
        const auto Perpendicular = Math::Abs(Normal.X) > 0.5 ? FVector(0.0, 0.0, 1.0) : FVector(1.0, 0.0, 0.0);
        const auto Basis = FTransform(FQuat(FRotator::MakeFromXZ(Perpendicular, -Normal)), FVector::ZeroVector, FVector::OneVector);
        return Basis.InverseTransformRotation(FQuat::Identity).Rotator();
    }

    FString Get_FaceName(EMars_Searing_Face InFace)
    {
        switch (InFace)
        {
            case EMars_Searing_Face::PosX: return "+X";
            case EMars_Searing_Face::NegX: return "-X";
            case EMars_Searing_Face::PosY: return "+Y";
            case EMars_Searing_Face::NegY: return "-Y";
            case EMars_Searing_Face::PosZ: return "+Z";
            default: return "-Z";
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Piece geometry: a piece is its mesh's bounds box in its own frame, its middle CentreLocal and its half sizes HalfExtents
    // (a cut half's origin is the uncut piece's, not its own middle). Shared with Fry.
    //----------------------------------------------------------------------------------------------------------------------

    FVector Get_BoundsCentre(const FCk_RuntimeMesh_Metrics& InMetrics)
    {
        return (InMetrics.Get_BoundsMinCm() + InMetrics.Get_BoundsMaxCm()) * 0.5;
    }

    FVector Get_BoundsHalfExtents(const FCk_RuntimeMesh_Metrics& InMetrics)
    {
        return (InMetrics.Get_BoundsMaxCm() - InMetrics.Get_BoundsMinCm()) * 0.5;
    }

    // InPieceTransform (in any frame) moved to the piece's middle: the frame its faces are measured from.
    FTransform Get_CentreFrame(const FTransform& InPieceTransform, const FVector& InCentreLocal)
    {
        return FTransform(InPieceTransform.GetRotation(), InPieceTransform.TransformPosition(InCentreLocal));
    }

    // The middle of InFace in InCentreFrame's parent frame: the face's normal picks the half extent it lies out.
    FVector Get_FaceCentre(const FTransform& InCentreFrame, EMars_Searing_Face InFace, const FVector& InHalfExtents)
    {
        const auto Normal = Get_FaceNormal(InFace);
        const auto Out = FVector(Normal.X * InHalfExtents.X, Normal.Y * InHalfExtents.Y, Normal.Z * InHalfExtents.Z);
        return InCentreFrame.GetLocation() + InCentreFrame.GetRotation().RotateVector(Out);
    }

    // The half height of the rotated box along its parent frame's Z: how far its bottom lies under its middle.
    float64 Get_WorldHalfExtentZ(const FQuat& InRotation, const FVector& InHalfExtents)
    {
        return Math::Abs(InRotation.RotateVector(FVector::ForwardVector).Z) * InHalfExtents.X
            + Math::Abs(InRotation.RotateVector(FVector::RightVector).Z) * InHalfExtents.Y
            + Math::Abs(InRotation.RotateVector(FVector::UpVector).Z) * InHalfExtents.Z;
    }

    // An adopted piece has arrived once its body is in the simulation and its transform reads the release location (within
    // k_ArrivalToleranceCm: a released piece may already have moved a frame's worth).
    bool Get_HasArrived(const FCk_Handle_JoltBody& InBody, const FCk_Handle& InEntity, const FVector& InReleaseLocation)
    {
        if (utils_jolt_body::Get_IsBodyAdded(InBody) == false)
        { return false; }

        return Get_ArrivalDistance(InEntity, InReleaseLocation) <= k_ArrivalToleranceCm;
    }

    // How far an adopted piece's transform reads from its release location.
    float64 Get_ArrivalDistance(const FCk_Handle& InEntity, const FVector& InReleaseLocation)
    {
        return (utils_transform::Get_EntityCurrentLocation(InEntity.As_Transform()) - InReleaseLocation).Size();
    }

    // How far the piece may reach from its middle sideways, whatever its rotation about the vertical (conservative).
    float64 Get_RadialExtent(const FVector& InHalfExtents)
    {
        return InHalfExtents.GetMax();
    }

    // The cook state InPiece's sear makes of InSeed (the state the piece arrived with): the face sears are the pan's, the
    // crust's penetration their sum (up to 1) and the silhouette their mean. Everything else is the seed's.
    FMars_CookState Get_CookState(const FMars_Searing_PieceState& InPiece, const FMars_CookState& InSeed)
    {
        auto CookState = InSeed;
        CookState.FaceSear.Empty();
        auto SearSum = 0.0f;
        for (const auto Sear : InPiece.FaceSear)
        {
            CookState.FaceSear.Add(Sear);
            SearSum += Sear;
        }

        CookState.Penetration = Math::Min(1.0f, SearSum);
        CookState.Shape = SearSum / float32(k_FaceCount);
        return CookState;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Searing_Spec Get_Spec(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing_Params).Spec;
}

mixin EMars_Searing_Heat Get_Heat(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Heat;
}

mixin bool Get_IsHot(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Heat == EMars_Searing_Heat::Hot;
}

// The Implement the pan node carries.
mixin FCk_Handle_Implement Get_Pan(const FCk_Handle_Searing& Self)
{
    return Self.Get_Spec().Nodes.Pan;
}

// FRotator(Pitch, 0, Roll), degrees, on top of the pan's rest rotation.
mixin FRotator Get_PanTilt(const FCk_Handle_Searing& Self)
{
    return Self.Get_Pan().Get_Tilt();
}

mixin float32 Get_PanLift(const FCk_Handle_Searing& Self)
{
    return Self.Get_Pan().Get_Lift();
}

// The pan base body's world transform as of the last transform update.
mixin FTransform Get_PanBaseWorld(const FCk_Handle_Searing& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.Get_Spec().Nodes.PanBaseBody.As_Transform());
}

mixin FVector Get_PanUp(const FCk_Handle_Searing& Self)
{
    return Self.Get_PanBaseWorld().GetRotation().GetUpVector();
}

// Aggregate over every piece.
mixin EMars_Searing_Sizzle Get_Sizzle(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Sizzle;
}

mixin FMars_Searing_Tally Get_Tally(const FCk_Handle_Searing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Searing).Tally;
}

// Admitted = Cooking + Ready (on the pan) + Lost + TakenOut (since the last reset; a lost piece stays counted after its
// body is destroyed).
mixin FMars_Searing_Summary Get_Summary(const FCk_Handle_Searing& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Searing);
    auto Summary = FMars_Searing_Summary();
    for (const auto& Piece : State.Pieces)
    {
        if (Piece.Status == EMars_Searing_PieceStatus::Cooking)
        { Summary.Cooking += 1; }
        else if (Piece.Status == EMars_Searing_PieceStatus::Ready)
        { Summary.Ready += 1; }
    }

    Summary.Lost = State.Tally.Losses;
    Summary.TakenOut = State.Tally.TakenOut;
    Summary.Admitted = Summary.Cooking + Summary.Ready + Summary.Lost + Summary.TakenOut;
    return Summary;
}

// The Ready pieces a TakeOut without a named piece would hand back.
mixin int32 Get_TakeableCount(const FCk_Handle_Searing& Self)
{
    auto Count = 0;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Searing).Pieces)
    {
        if (Piece.Status == EMars_Searing_PieceStatus::Ready)
        { Count += 1; }
    }

    return Count;
}

//--------------------------------------------------------------------------------------------------------------------------
// Piece getters (by identity). An unknown Id ensures and answers the zero value; Get_HasPiece asks first.
//--------------------------------------------------------------------------------------------------------------------------

// Every piece on the pan in admission order, the lingering lost ones included.
mixin TArray<FMars_CookingFeed_PieceId> Get_PieceIds(const FCk_Handle_Searing& Self)
{
    TArray<FMars_CookingFeed_PieceId> Ids;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Searing).Pieces)
    { Ids.Add(Piece.Id); }

    return Ids;
}

// From admission until the piece is taken out or destroyed (a lost one, at the end of its linger).
mixin bool Get_HasPiece(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_searing::Find_PieceIndex(Self.Get_Fragment(FMars_Fragment_Searing).Pieces, InPieceId) >= 0;
}

// A copy of the piece's state; an unknown Id ensures and answers a default state.
mixin FMars_Searing_PieceState Get_PieceState(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_Searing).Pieces;
    const auto Index = utils_searing::Find_PieceIndex(Pieces, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Searing] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} ({Pieces.Num()} on the pan)"))
    { return FMars_Searing_PieceState(); }

    return Pieces[Index];
}

mixin FCk_Handle Get_PieceEntity(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Entity;
}

mixin FCk_Handle_FoodPiece Get_PieceHandle(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Piece;
}

// Half the piece's bounds along its own axes, as read at admission.
mixin FVector Get_PieceHalfExtents(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).HalfExtents;
}

// The middle of the piece's bounds in the world; zero once its entity is gone.
mixin FVector Get_PieceCentre(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    if (ck::Is_NOT_Valid(Piece.Entity))
    { return FVector::ZeroVector; }

    const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Piece.Entity.As_Transform());
    return PieceWorld.TransformPosition(Piece.CentreLocal);
}

mixin FCk_Handle_JoltBody Get_PieceBody(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Body;
}

mixin EMars_Searing_PieceStatus Get_PieceStatus(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Status;
}

mixin EMars_Searing_Contact Get_PieceContact(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Contact;
}

// 0 raw .. 1 seared.
mixin float32 Get_FaceSear(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId, EMars_Searing_Face InFace)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    const auto Index = int32(InFace);
    if (Piece.FaceSear.IsValidIndex(Index) == false)
    { return 0.0f; }

    return Piece.FaceSear[Index];
}

mixin int32 Get_SearedFaceCount(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_searing::Get_SearedFaceCount(Self.Get_PieceState(InPieceId).FaceSear);
}

// The middle of the piece's bounds in the pan base body's frame (the cooking surface is at Z = utils_searing::k_PanSurfaceZ);
// zero once its entity is gone.
mixin FVector Get_PiecePanLocal(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Entity = Self.Get_PieceEntity(InPieceId);
    if (ck::Is_NOT_Valid(Entity))
    { return FVector::ZeroVector; }

    return Self.Get_PanBaseWorld().InverseTransformPosition(Self.Get_PieceCentre(InPieceId));
}

// The piece face pointing most against the pan's up; NegZ once its entity is gone.
mixin EMars_Searing_Face Get_DownFace(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Entity = Self.Get_PieceEntity(InPieceId);
    if (ck::Is_NOT_Valid(Entity))
    { return EMars_Searing_Face::NegZ; }

    const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    return utils_searing::Get_DownFace(PieceWorld.GetRotation(), Self.Get_PanUp());
}

mixin bool Get_IsDownFaceSeared(const FCk_Handle_Searing& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_FaceSear(InPieceId, Self.Get_DownFace(InPieceId)) >= 1.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Look(FCk_Handle_Searing& Self, const FMars_Request_Searing_Look& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.LookRequests.Add(InRequest);
}

mixin void Request_SetHeat(FCk_Handle_Searing& Self, const FMars_Request_Searing_SetHeat& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.SetHeatRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Searing& Self, const FMars_Request_Searing_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_AddPiece(FCk_Handle_Searing& Self, const FMars_Request_Searing_AddPiece& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.AddPieceRequests.Add(InRequest);
}

mixin void Request_TakeOut(FCk_Handle_Searing& Self, const FMars_Request_Searing_TakeOut& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Requests);
    Requests.TakeOutRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHeatChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnHeatChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnHeatChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHeatChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnHeatChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnHeatChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdmission(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceAdmission InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceAdmission.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdmission(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceAdmission InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdmission.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdded(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceAdded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceAdded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdded(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceAdded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPanContactChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPanContactChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPanContactChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPanContactChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPanContactChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPanContactChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSearProgress(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSearProgress InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnSearProgress.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSearProgress(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSearProgress InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnSearProgress.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnFaceSeared(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnFaceSeared InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnFaceSeared.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFaceSeared(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnFaceSeared InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnFaceSeared.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceReady(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceReady InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceReady.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceReady(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceReady InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceReady.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceLost(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceLost InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceLost.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceLost(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceLost InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceLost.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSizzleChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSizzleChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnSizzleChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSizzleChanged(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnSizzleChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnSizzleChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceTakenOut(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceTakenOut InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Searing_Signals);
    Fragment.OnPieceTakenOut.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceTakenOut(FCk_Handle_Searing& Self, FMars_Delegate_Searing_OnPieceTakenOut InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceTakenOut.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
