struct FMars_AutoTest_Platter_Loaded
{
    FCk_Handle_Platter Platter;
    FCk_Handle_FoodPiece Piece;

    // The piece's body motion type at the landing; unset for a piece without a body.
    TOptional<ECk_MotionType> BodyMotion;
}

struct FMars_AutoTest_Platter_Refusal
{
    FCk_Handle_Platter Platter;
    FCk_Handle_FoodPiece Piece;
    EMars_Platter_LoadRefusal Refusal = EMars_Platter_LoadRefusal::Full;
}

struct FMars_AutoTest_Platter_Unloaded
{
    FCk_Handle_Platter Platter;
    FCk_Handle_FoodPiece Piece;
}

// The Platter rig, on the FoodPiece rig (pieces under the world's transient entity, tracked for cleanup, their cuts recorded
// and their halves tracked). Platters are plain Transform entities under the test entity, each standing on a kinematic
// floor box that rides its root (a platter item's tray body plays that part), recorded per platter: every landing,
// refusal, unload and clear. Tests rotate and move their platters, so the root-frame math is exercised.
UCLASS(Abstract)
class UMars_AutoTestRig_Platter : UMars_AutoTestRig_FoodPiece
{
    default _TimeoutSeconds = 20.0f;

    protected TArray<FMars_AutoTest_Platter_Loaded> _Loaded;
    protected TArray<FMars_AutoTest_Platter_Refusal> _Refused;
    protected TArray<FMars_AutoTest_Platter_Unloaded> _Unloaded;
    private UMars_AutoTestHelper_CookingFixture _CookingFixture;
    // In parallel: one entry per piece whose freeze Record_Freezes saw, with its cause.
    protected TArray<FCk_Handle_FoodPiece> _FreezePieces;
    protected TArray<EMars_Platter_FreezeCause> _FreezeCauses;

    // A 30 x 30 floor between 40 cm walls (the box fixture is a 10 cm cube), the item's settle tuners.
    protected FMars_Platter_Spec Make_PlatterSpec(int32 InCapacity) const
    {
        return FMars_Platter_Spec(InCapacity, FMars_Platter_Bounds(FVector2D(15.0, 15.0), 40.0f, 25.0f));
    }

    protected FCk_Handle_Platter Build_Platter(FCk_Handle InOwner, FTransform InWorld, FMars_Platter_Spec InSpec)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        Get_CookingFixture().Add_PlatterFloorBox(Entity.As_Transform(), InSpec.Bounds);
        auto Platter = utils_platter::Add(Entity, InSpec);
        Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnPlatterLoaded"));
        Platter.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnPlatterLoadRefused"));
        Platter.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnPlatterUnloaded"));
        return Platter;
    }

    protected FCk_Handle_FoodPiece Build_BoxAt(FTransform InWorld, float InMassKg)
    {
        return Build_Piece(Get_BoxMesh(), InWorld, Make_Spec(InMassKg));
    }

    protected void Load(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        auto Platter = InPlatter;
        Platter.Request_Load(FMars_Request_Platter_Load(InPiece));
    }

    protected void Unload(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        auto Platter = InPlatter;
        Platter.Request_Unload(FMars_Request_Platter_Unload(InPiece));
    }

    protected FTransform Get_PlatterWorld(FCk_Handle_Platter InPlatter) const
    {
        FCk_Handle Entity = InPlatter;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    // Invalid while the piece is not a scene node.
    protected FCk_Handle_Transform Get_Parent(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    protected bool Get_IsSceneNode(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        return Entity.Is_SceneNode();
    }

    protected FCk_Handle_Transform Get_Root(FCk_Handle_Platter InPlatter) const
    {
        FCk_Handle Entity = InPlatter;
        return Entity.As_Transform();
    }

    // The piece's bounds centre lies between InPlatter's walls and above its floor.
    protected bool Get_IsInsideWalls(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece) const
    {
        return utils_platter::Get_IsInside(InPlatter.Get_Spec().Bounds, Get_PlatterWorld(InPlatter), InPiece);
    }

    // The piece lies on the platter's floor: its bounds centre stands over the floor (root frame) by half its own height along
    // the root's up, within InToleranceCm. A piece leaning on a wall or lying on another one does not.
    protected bool Get_RestsOnFloor(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, float64 InToleranceCm = 0.5) const
    {
        const auto RootWorld = Get_PlatterWorld(InPlatter);
        const auto PieceWorld = Get_World(InPiece);
        const auto CentreRoot = RootWorld.InverseTransformPosition(PieceWorld.TransformPosition(Get_BoundsCenter(InPiece)));

        const auto Metrics = Get_Metrics(InPiece);
        const auto Half = (Metrics.Get_BoundsMaxCm() - Metrics.Get_BoundsMinCm()) * 0.5;
        const auto Up = RootWorld.GetRotation().GetUpVector();
        const auto Rotation = PieceWorld.GetRotation();
        const auto HalfHeight = Math::Abs(Rotation.GetForwardVector().DotProduct(Up)) * Half.X
            + Math::Abs(Rotation.GetRightVector().DotProduct(Up)) * Half.Y
            + Math::Abs(Rotation.GetUpVector().DotProduct(Up)) * Half.Z;

        return Math::Abs(CentreRoot.Z - HalfHeight) <= InToleranceCm;
    }

    // InPiece is dropped and settling on InPlatter (past its queue, not yet frozen into the pile).
    protected bool Get_IsSettling(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece) const
    {
        for (const auto& Settling : InPlatter.Get_Fragment(FMars_Fragment_Platter).Settling)
        {
            if (Settling.Piece == InPiece)
            { return true; }
        }

        return false;
    }

    // Records the freeze cause of every piece InPlatter is settling whose freeze is newly set. A wait predicate calls it every
    // poll while the pieces settle: the settle record goes once the piece lands.
    protected void Record_Freezes(FCk_Handle_Platter InPlatter)
    {
        const auto& State = InPlatter.Get_Fragment(FMars_Fragment_Platter);
        for (const auto& Settling : State.Settling)
        {
            if (Settling.Freeze.IsSet() && _FreezePieces.Contains(Settling.Piece) == false)
            {
                _FreezePieces.Add(Settling.Piece);
                _FreezeCauses.Add(Settling.Freeze.GetValue());
            }
        }
    }

    // The cause Record_Freezes saw InPiece freeze with; unset when it saw no freeze.
    protected TOptional<EMars_Platter_FreezeCause> TryGet_FreezeCause(FCk_Handle_FoodPiece InPiece) const
    {
        const auto Index = _FreezePieces.FindIndex(InPiece);
        if (Index < 0)
        { return TOptional<EMars_Platter_FreezeCause>(); }

        return TOptional<EMars_Platter_FreezeCause>(_FreezeCauses[Index]);
    }

    // The piece's body motion type; unset while it has no body.
    protected TOptional<ECk_MotionType> TryGet_Motion(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        if (Entity.Is_JoltBody() == false)
        { return TOptional<ECk_MotionType>(); }

        return TOptional<ECk_MotionType>(utils_jolt_body::Get_MotionType(Entity.As_JoltBody()));
    }

    // Frozen into the pile: held, Kinematic and a scene-node child of the root.
    protected bool Get_IsFrozenOn(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece) const
    {
        return InPlatter.Get_Held().Contains(InPiece) && TryGet_Motion(InPiece) == ECk_MotionType::Kinematic
            && Get_Parent(InPiece) == Get_Root(InPlatter);
    }

    private UMars_AutoTestHelper_CookingFixture Get_CookingFixture()
    {
        if (ck::Is_NOT_Valid(_CookingFixture))
        { _CookingFixture = Cast<UMars_AutoTestHelper_CookingFixture>(NewObject(this, UMars_AutoTestHelper_CookingFixture)); }

        return _CookingFixture;
    }

    // A dynamic convex body of the piece's own mesh and mass, as a board's sweep gives a released piece.
    protected FCk_Handle_JoltBody Give_Body(FCk_Handle_FoodPiece InPiece)
    {
        auto Convex = FCk_JoltBody_RuntimeConvexSpec();
        Convex.Set_PointsCm(utils_runtime_mesh::Copy_LocalVerticesCm(InPiece.Get_Geometry()));

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::RuntimeConvex);
        BodySpec.Set_RuntimeConvex(Convex);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(float32(InPiece.Get_MassKg()));
        BodySpec.Set_CollisionProfileName(n"PhysicsActor");

        FCk_Handle Entity = InPiece;
        return utils_jolt_body::Add(Entity, BodySpec);
    }

    protected void Move_Platter(FCk_Handle_Platter InPlatter, FVector InWorldLocation)
    {
        utils_transform::Request_SetLocation(Get_Root(InPlatter), FCk_Request_Transform_SetLocation(InWorldLocation));
    }

    protected bool Get_IsEnding(FCk_Handle_FoodPiece InPiece) const
    {
        return ck::Is_NOT_Valid(InPiece) || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    protected int32 Get_LoadedCountOf(FCk_Handle_FoodPiece InPiece) const
    {
        auto Count = 0;
        for (const auto& Event : _Loaded)
        {
            if (Event.Piece == InPiece)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_LoadedCount(FCk_Handle_Platter InPlatter) const
    {
        auto Count = 0;
        for (const auto& Event : _Loaded)
        {
            if (Event.Platter == InPlatter)
            { ++Count; }
        }

        return Count;
    }

    // The landing of InPiece; unset when it has not landed.
    protected TOptional<FMars_AutoTest_Platter_Loaded> TryGet_Loaded(FCk_Handle_FoodPiece InPiece) const
    {
        for (const auto& Event : _Loaded)
        {
            if (Event.Piece == InPiece)
            { return TOptional<FMars_AutoTest_Platter_Loaded>(Event); }
        }

        return TOptional<FMars_AutoTest_Platter_Loaded>();
    }

    protected int32 Get_RefusalCount(FCk_Handle_Platter InPlatter, EMars_Platter_LoadRefusal InRefusal) const
    {
        auto Count = 0;
        for (const auto& Event : _Refused)
        {
            if (Event.Platter == InPlatter && Event.Refusal == InRefusal)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_AllRefusalCount(FCk_Handle_Platter InPlatter) const
    {
        auto Count = 0;
        for (const auto& Event : _Refused)
        {
            if (Event.Platter == InPlatter)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_UnloadedCount(FCk_Handle_Platter InPlatter) const
    {
        auto Count = 0;
        for (const auto& Event : _Unloaded)
        {
            if (Event.Platter == InPlatter)
            { ++Count; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPlatterLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        auto Event = FMars_AutoTest_Platter_Loaded();
        Event.Platter = InPlatter;
        Event.Piece = InPiece;

        FCk_Handle Entity = InPiece;
        if (Entity.Is_JoltBody())
        { Event.BodyMotion = TOptional<ECk_MotionType>(utils_jolt_body::Get_MotionType(Entity.As_JoltBody())); }

        _Loaded.Add(Event);
    }

    UFUNCTION()
    private void OnPlatterLoadRefused(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        auto Event = FMars_AutoTest_Platter_Refusal();
        Event.Platter = InPlatter;
        Event.Piece = InPiece;
        Event.Refusal = InRefusal;
        _Refused.Add(Event);
    }

    UFUNCTION()
    private void OnPlatterUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        auto Event = FMars_AutoTest_Platter_Unloaded();
        Event.Platter = InPlatter;
        Event.Piece = InPiece;
        _Unloaded.Add(Event);
    }
}
