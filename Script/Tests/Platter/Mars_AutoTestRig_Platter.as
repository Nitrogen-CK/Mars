struct FMars_AutoTest_Platter_Loaded
{
    FCk_Handle_Platter Platter;
    FCk_Handle_FoodPiece Piece;
    int32 Slot = -1;

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
// and their halves tracked). Platters are plain Transform entities under the test entity, recorded per platter: every
// landing, refusal, unload and clear. Tests rotate and move their platters, so the slot-frame math is exercised.
UCLASS(Abstract)
class UMars_AutoTestRig_Platter : UMars_AutoTestRig_FoodPiece
{
    default _TimeoutSeconds = 20.0f;

    protected TArray<FMars_AutoTest_Platter_Loaded> _Loaded;
    protected TArray<FMars_AutoTest_Platter_Refusal> _Refused;
    protected TArray<FMars_AutoTest_Platter_Unloaded> _Unloaded;
    protected TArray<FCk_Handle_Platter> _Cleared;

    // InSlots slots in a row along Y at 20 cm pitch, Z 0, unrotated.
    protected FMars_Platter_Spec Make_PlatterSpec(int32 InSlots, float32 InArriveSeconds) const
    {
        TArray<FTransform> Slots;
        for (int32 Index = 0; Index < InSlots; ++Index)
        { Slots.Add(FTransform(FRotator::ZeroRotator, FVector(0.0, 20.0 * Index, 0.0))); }

        return FMars_Platter_Spec(Slots, InArriveSeconds);
    }

    protected FCk_Handle_Platter Build_Platter(FCk_Handle InOwner, FTransform InWorld, FMars_Platter_Spec InSpec)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        auto Platter = utils_platter::Add(Entity, InSpec);
        Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnPlatterLoaded"));
        Platter.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnPlatterLoadRefused"));
        Platter.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnPlatterUnloaded"));
        Platter.BindTo_OnCleared(FMars_Delegate_Platter_OnCleared(this, n"OnPlatterCleared"));
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

    protected void Load_From(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, FTransform InArriveFrom)
    {
        auto Platter = InPlatter;
        Platter.Request_Load(FMars_Request_Platter_Load(InPiece, InArriveFrom));
    }

    protected void Unload(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        auto Platter = InPlatter;
        Platter.Request_Unload(FMars_Request_Platter_Unload(InPiece));
    }

    protected void Clear(FCk_Handle_Platter InPlatter)
    {
        auto Platter = InPlatter;
        Platter.Request_Clear(FMars_Request_Platter_Clear());
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

    // Where InPiece rests in slot InSlot of InPlatter, in the world, by the kernel's own slot pose.
    protected FTransform Get_SlotWorld(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, int32 InSlot) const
    {
        const auto SlotLocal = InPlatter.Get_Spec().SlotsLocal[InSlot];
        return utils_platter::Get_SlotPose(Get_Metrics(InPiece), SlotLocal) * Get_PlatterWorld(InPlatter);
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

    protected int32 Get_ClearedCount(FCk_Handle_Platter InPlatter) const
    {
        auto Count = 0;
        for (const auto& Platter : _Cleared)
        {
            if (Platter == InPlatter)
            { ++Count; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPlatterLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, int32 InSlot)
    {
        auto Event = FMars_AutoTest_Platter_Loaded();
        Event.Platter = InPlatter;
        Event.Piece = InPiece;
        Event.Slot = InSlot;

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

    UFUNCTION()
    private void OnPlatterCleared(FCk_Handle_Platter InPlatter)
    {
        _Cleared.Add(InPlatter);
    }
}
