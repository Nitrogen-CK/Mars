// An empty platter world item lying at World.
struct FMars_Platter_SpawnSpec
{
    UPROPERTY()
    FTransform World;

    // Which platter item; null = the small one (mars_items::Platter()).
    UPROPERTY()
    TWeakObjectPtr<UCk_InventoryItem_Definition> Definition;

    FMars_Platter_SpawnSpec() {}

    FMars_Platter_SpawnSpec(const FTransform& InWorld)
    {
        World = InWorld;
    }

    FMars_Platter_SpawnSpec(const FTransform& InWorld, UCk_InventoryItem_Definition InDefinition)
    {
        World = InWorld;
        Definition = TWeakObjectPtr<UCk_InventoryItem_Definition>(InDefinition);
    }
}

// Where a dropped piece starts, in the platter root's frame.
struct FMars_Platter_DropPose
{
    FRotator Rotation;
    FVector Location;
}

namespace utils_platter
{
    // Composes the platter on InHandle, which must carry a Transform: the root the pile rides. It starts empty, with its four
    // walls built (kinematic boxes on the floor's edges, scene-node children of the root). A rejected spec or a missing
    // Transform ensures and returns an invalid handle.
    FCk_Handle_Platter Add(FCk_Handle& InHandle, FMars_Platter_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Platter] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Platter(); }

        const auto IsComposable = InHandle.Is_Transform() && InHandle.Is_Platter() == false;
        if (ck::EnsureIfNot(IsComposable, f"[Platter] [{InHandle.ToString()}] needs a Transform, and no Platter yet"))
        { return FCk_Handle_Platter(); }

        auto Params = FMars_Fragment_Platter_Params();
        Params.Spec = InSpec;

        auto Root = InHandle.As_Transform();
        auto State = FMars_Fragment_Platter();
        State.Walls = Add_Walls(Root, InSpec.Bounds);

        InHandle.Add_Fragment(FMars_Feature_Platter());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_Platter();
    }

    // The long walls (on the X edges) span the whole Y side, corners included; the short ones close the ends. Each stands
    // centred on its edge, lifted off the floor.
    TArray<FCk_Handle_JoltBody> Add_Walls(FCk_Handle_Transform& InRoot, const FMars_Platter_Bounds& InBounds)
    {
        const auto Half = InBounds.InnerHalfExtents;
        const auto HalfThickness = constants_platter::k_WallThicknessCm * 0.5;
        const auto HalfHeight = float64(InBounds.WallHeight) * 0.5;
        const auto CentreZ = constants_platter::k_WallLiftCm + HalfHeight;

        TArray<FCk_Handle_JoltBody> Walls;
        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            Walls.Add(Add_Wall(InRoot, FVector(float64(Side) * Half.X, 0.0, CentreZ), FVector(HalfThickness, Half.Y + HalfThickness, HalfHeight)));
            Walls.Add(Add_Wall(InRoot, FVector(0.0, float64(Side) * Half.Y, CentreZ), FVector(Half.X + HalfThickness, HalfThickness, HalfHeight)));
        }

        return Walls;
    }

    FCk_Handle_JoltBody Add_Wall(FCk_Handle_Transform& InRoot, FVector InCentre, FVector InHalfExtents)
    {
        auto Node = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, InCentre));

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Kinematic);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(constants_platter::k_WallMassKg);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(constants_platter::k_WallFriction);
        BodySpec.Set_Restitution(constants_platter::k_WallRestitution);
        BodySpec.Set_CollisionProfileName(constants_platter::k_WallCollisionProfile);
        return utils_jolt_body::Add(Node.H(), BodySpec);
    }

    // The profile the pile's bodies collide as: pawn-ignoring while InMounting is Mounted, else the piece's own
    // (FMars_FoodPiece_BodyTuners.CollisionProfileName). A piece without a body has nothing to switch. Called by the
    // Platter processors.
    void Apply_PileProfile(const FCk_Handle_FoodPiece& InPiece, EMars_Platter_Mounting InMounting)
    {
        FCk_Handle PieceEntity = InPiece;
        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Body))
        { return; }

        const auto Profile = InMounting == EMars_Platter_Mounting::Mounted
            ? constants_platter::k_PhysicalBodyProfile
            : InPiece.Get_BodyTuners().CollisionProfileName;
        utils_jolt_body::Request_SetCollisionProfile(Body, FCk_Request_JoltBody_SetCollisionProfile(Profile));
    }

    // Moved less than k_StillCm and turned less than k_StillDegrees between two passes.
    bool Get_IsStill(const FTransform& InLast, const FTransform& InNow)
    {
        const auto Moved = InLast.GetLocation().Distance(InNow.GetLocation());
        const auto A = InLast.GetRotation();
        const auto B = InNow.GetRotation();
        const auto Dot = Math::Min(1.0, Math::Abs(A.X * B.X + A.Y * B.Y + A.Z * B.Z + A.W * B.W));
        const auto Turned = Math::RadiansToDegrees(2.0 * Math::Acos(Dot));
        return Moved < constants_platter::k_StillCm && Turned < constants_platter::k_StillDegrees;
    }

    // A random pose for InPiece's drop, in the root's frame: its bounds centre over a random point of the floor its yawed
    // footprint fits inside the walls (the wall's thickness kept clear, an axis clamped to the middle when it does not fit),
    // its bottom DropHeight above the floor. A random yaw whose footprint does not fit gives way to the piece's better
    // axis-aligned yaw, so a long joint lies along the tray instead of across its walls.
    FMars_Platter_DropPose Make_DropPose(const FMars_Platter_Bounds& InBounds, const FCk_RuntimeMesh_Metrics& InMetrics)
    {
        const auto Min = InMetrics.Get_BoundsMinCm();
        const auto Max = InMetrics.Get_BoundsMaxCm();
        const auto Centre = (Min + Max) * 0.5;
        const auto HalfSize = (Max - Min) * 0.5;
        const auto Room = FVector2D(InBounds.InnerHalfExtents.X - constants_platter::k_WallThicknessCm * 0.5,
                                    InBounds.InnerHalfExtents.Y - constants_platter::k_WallThicknessCm * 0.5);

        auto Yaw = Math::RandRange(0.0, 360.0);
        if (Get_FitsAt(Room, HalfSize, Yaw) == false)
        {
            const auto Flip = Math::RandRange(0.0, 1.0) < 0.5 ? 0.0 : 180.0;
            Yaw = Get_Slack(Room, Get_Footprint(HalfSize, 0.0)) >= Get_Slack(Room, Get_Footprint(HalfSize, 90.0)) ? Flip : 90.0 + Flip;
        }

        const auto Footprint = Get_Footprint(HalfSize, Yaw);
        const auto RangeX = Math::Max(0.0, Room.X - Footprint.X);
        const auto RangeY = Math::Max(0.0, Room.Y - Footprint.Y);
        const auto Target = FVector(Math::RandRange(-RangeX, RangeX), Math::RandRange(-RangeY, RangeY),
                                    float64(InBounds.DropHeight) + HalfSize.Z);

        auto Pose = FMars_Platter_DropPose();
        Pose.Rotation = FRotator(0.0, Yaw, 0.0);
        Pose.Location = Target - Pose.Rotation.Quaternion().RotateVector(Centre);
        return Pose;
    }

    // The half extents in X and Y of a box of InHalfSize turned InYaw degrees about Z.
    FVector2D Get_Footprint(FVector InHalfSize, float64 InYaw)
    {
        const auto Cos = Math::Abs(Math::Cos(Math::DegreesToRadians(InYaw)));
        const auto Sin = Math::Abs(Math::Sin(Math::DegreesToRadians(InYaw)));
        return FVector2D(Cos * InHalfSize.X + Sin * InHalfSize.Y, Sin * InHalfSize.X + Cos * InHalfSize.Y);
    }

    bool Get_FitsAt(FVector2D InRoom, FVector InHalfSize, float64 InYaw)
    {
        return Get_Slack(InRoom, Get_Footprint(InHalfSize, InYaw)) >= 0.0;
    }

    // The tighter of the two axes' spare room; negative when the footprint pokes into a wall.
    float64 Get_Slack(FVector2D InRoom, FVector2D InFootprint)
    {
        return Math::Min(InRoom.X - InFootprint.X, InRoom.Y - InFootprint.Y);
    }

    // InPiece's bounds centre in the root's frame lies over the floor between the walls' centre lines and above the floor.
    bool Get_IsInside(const FMars_Platter_Bounds& InBounds, const FTransform& InRootWorld, const FCk_Handle_FoodPiece& InPiece)
    {
        const auto Metrics = utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
        const auto CentreLocal = (Metrics.Get_BoundsMinCm() + Metrics.Get_BoundsMaxCm()) * 0.5;
        FCk_Handle PieceEntity = InPiece;
        const auto CentreWorld = utils_transform::Get_EntityCurrentTransform(PieceEntity.As_Transform()).TransformPosition(CentreLocal);
        const auto CentreRoot = InRootWorld.InverseTransformPosition(CentreWorld);
        return Math::Abs(CentreRoot.X) <= InBounds.InnerHalfExtents.X && Math::Abs(CentreRoot.Y) <= InBounds.InnerHalfExtents.Y
            && CentreRoot.Z >= 0.0;
    }

    // InPiece leaves InPlatter's ledger: its membership goes, and so does its holder fact while InPlatter is the holder.
    // Called by the Platter processors wherever a piece leaves the books; a destroyed piece has nothing left to remove.
    void Leave_Ledger(FCk_Handle_FoodPiece& InPiece, const FCk_Handle_Platter& InPlatter)
    {
        if (ck::Is_NOT_Valid(InPiece))
        { return; }

        InPiece.Request_TryRemove(FMars_Fragment_Platter_Membership);
        utils_foodpiece::Clear_Holder(InPiece, InPlatter);
    }

    // A settling piece is detached (the drop and the re-settle detach it), and a queued one lies where whoever loaded it let
    // it go, so a scene-node parent means something else took it: a pickup's Carry attached it to a hand.
    bool Get_IsTaken(const FCk_Handle_FoodPiece& InPiece)
    {
        FCk_Handle PieceEntity = InPiece;
        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Node) && ck::IsValid(utils_scene_node::Get_Parent(Node));
    }

    // The held pieces frozen at or after InFrozenFrom (the ones that may lie on a piece that left) let go and settle again,
    // so nothing floats over a hole: detached where they are, Dynamic, back in Settling; the pieces frozen before stay put.
    // Called by the Platter processors after a landed piece left (Get_ResettleFrom); InRootWorld is the platter root's world
    // pose.
    void Resettle(FMars_Fragment_Platter& InState, const FTransform& InRootWorld, int32 InFrozenFrom)
    {
        TArray<FMars_Platter_Held> StillHeld;
        for (const auto& Held : InState.Held)
        {
            if (Held.FreezeIndex < InFrozenFrom)
            {
                StillHeld.Add(Held);
                continue;
            }

            auto Piece = Held.Piece;
            if (ck::Is_NOT_Valid(Piece) || utils_entity_lifetime::Get_IsPendingDestroy(Piece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            FCk_Handle PieceEntity = Piece;
            auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Node))
            { utils_scene_node::Request_Detach(Node); }

            auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Body))
            { utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic)); }

            const auto Location = utils_transform::Get_EntityCurrentTransform(PieceEntity.As_Transform()).GetLocation();
            auto Settling = FMars_Platter_Settling(Piece, EMars_Platter_SettleReason::Resettle, InRootWorld.InverseTransformPosition(Location));
            Settling.FreezeFloor = InState.NextFreezeIndex;
            InState.Settling.Add(Settling);
        }

        InState.Held = StillHeld;
    }

    // Lowers InOutFrom to the first freeze index a departed landed piece may have supported: a held piece's successors in
    // the freeze order (InHeldFreezeIndex + 1), or whatever froze since a re-settling piece let go (its FreezeFloor).
    void Lower_ResettleFrom(TOptional<int32>& InOutFrom, int32 InFrozenFrom)
    {
        if (InOutFrom.IsSet() == false || InFrozenFrom < InOutFrom.GetValue())
        { InOutFrom = TOptional<int32>(InFrozenFrom); }
    }

    // InPiece's index in InHeld; -1 when absent.
    int32 Find_Held(const TArray<FMars_Platter_Held>& InHeld, const FCk_Handle_FoodPiece& InPiece)
    {
        for (int32 Index = 0; Index < InHeld.Num(); ++Index)
        {
            if (InHeld[Index].Piece == InPiece)
            { return Index; }
        }

        return -1;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Platter_Spec Get_Spec(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter_Params).Spec;
}

mixin int32 Get_Capacity(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter_Params).Spec.Capacity;
}

// The frozen pile in freeze order: a station taking "the next piece" takes the last (the top).
mixin TArray<FCk_Handle_FoodPiece> Get_Held(const FCk_Handle_Platter& Self)
{
    TArray<FCk_Handle_FoodPiece> Pieces;
    for (const auto& Held : Self.Get_Fragment(FMars_Fragment_Platter).Held)
    { Pieces.Add(Held.Piece); }

    return Pieces;
}

// Every piece the platter holds: frozen (freeze order), settling, then queued. What a dock's policy judges.
mixin TArray<FCk_Handle_FoodPiece> Get_Pieces(const FCk_Handle_Platter& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Platter);
    auto Pieces = Self.Get_Held();
    for (const auto& Settling : State.Settling)
    { Pieces.Add(Settling.Piece); }

    Pieces.Append(State.Queue);
    return Pieces;
}

mixin int32 Get_HeldCount(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter).Held.Num();
}

// Accepted pieces not frozen yet: queued, dropping or re-settling.
mixin int32 Get_PendingCount(const FCk_Handle_Platter& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Platter);
    return State.Queue.Num() + State.Settling.Num();
}

// What a Load counts against the capacity: held, settling and queued.
mixin int32 Get_Occupancy(const FCk_Handle_Platter& Self)
{
    return Self.Get_HeldCount() + Self.Get_PendingCount();
}

mixin bool Get_IsFull(const FCk_Handle_Platter& Self)
{
    return Self.Get_Occupancy() >= Self.Get_Capacity();
}

mixin int32 Get_FreeCount(const FCk_Handle_Platter& Self)
{
    return Math::Max(0, Self.Get_Capacity() - Self.Get_Occupancy());
}

// The four kinematic wall bodies.
mixin TArray<FCk_Handle_JoltBody> Get_Walls(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter).Walls;
}

// Whether the platter rides a carrier, so its pile ignores pawns.
mixin EMars_Platter_Mounting Get_Mounting(const FCk_Handle_Platter& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Platter).Mounting;
}

// Whether every piece it holds (Get_Pieces) is a root (never cut); true for an empty platter.
mixin bool Get_IsWhole(const FCk_Handle_Platter& Self)
{
    for (const auto& Piece : Self.Get_Pieces())
    {
        if (Piece.Get_IsWhole() == false)
        { return false; }
    }

    return true;
}

// The union of the kinds of every piece it holds (Get_Pieces).
mixin FGameplayTagContainer Get_Kinds(const FCk_Handle_Platter& Self)
{
    auto Kinds = FGameplayTagContainer();
    for (const auto& Piece : Self.Get_Pieces())
    { Kinds.AppendTags(Piece.Get_Kind()); }

    return Kinds;
}

// The platter holding the piece, held, settling or queued; invalid for a piece no platter holds.
mixin FCk_Handle_Platter TryGet_Platter(const FCk_Handle_FoodPiece& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_Fragment(FMars_Fragment_Platter_Membership) == false)
    { return FCk_Handle_Platter(); }

    return Self.Get_Fragment(FMars_Fragment_Platter_Membership).Platter;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetMounted(FCk_Handle_Platter& Self, const FMars_Request_Platter_SetMounted& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Requests);
    Requests.SetMountedRequests.Add(InRequest);
}

mixin void Request_Load(FCk_Handle_Platter& Self, const FMars_Request_Platter_Load& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.Piece), f"[Platter] [{Self.ToString()}] was asked to load an invalid piece"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Requests);
    Requests.LoadRequests.Add(InRequest);
}

mixin void Request_Unload(FCk_Handle_Platter& Self, const FMars_Request_Platter_Unload& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.Piece), f"[Platter] [{Self.ToString()}] was asked to unload an invalid piece"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Requests);
    Requests.UnloadRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnLoaded(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoaded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Signals);
    Fragment.OnLoaded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLoaded(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoaded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Platter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoaded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnLoadAccepted(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoadAccepted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Signals);
    Fragment.OnLoadAccepted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLoadAccepted(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoadAccepted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Platter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoadAccepted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnLoadRefused(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoadRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Signals);
    Fragment.OnLoadRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLoadRefused(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnLoadRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Platter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoadRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnUnloaded(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnUnloaded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Platter_Signals);
    Fragment.OnUnloaded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnUnloaded(FCk_Handle_Platter& Self, FMars_Delegate_Platter_OnUnloaded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Platter_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Platter_Signals).OnUnloaded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
