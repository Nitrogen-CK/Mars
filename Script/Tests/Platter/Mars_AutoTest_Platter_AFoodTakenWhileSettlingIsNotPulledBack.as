// A food taken off a platter in the frame after its drop stays where it was taken. A meat slab lying on its floor is loaded
// onto a large platter (the kernel's way, no hand); the platter drops the joint, Dynamic, into Settling. A per-frame hook
// takes it in the first frame it sees the joint settling (the step timers run before the platter's processors: the frame
// after the drop, before the platter's next pass): the joint's body is asked for Kinematic and the joint is attached to the
// carrier's hand node where it is, which is all "taken" means to the platter's books. The platter forgets it silently (a
// first landing never landed), and past the longest settle the joint's parent is still the hand node: no freeze pulled it
// back onto the root. No OnLoaded, no OnUnloaded, no refusal. Isolated origin (24000, -21000, -30000).
class UMars_AutoTest_Platter_AFoodTakenWhileSettlingIsNotPulledBack : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(24000.0, -21000.0, -30000.0);
    private const FVector k_PlatterOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);
    // Physics settles and mount arrivals outrun the harness's default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    // Under construction until each is a WorldItem whose holder holds its item.
    private FCk_Handle _PlatterEntity;
    private FCk_Handle _FoodEntity;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _Joint;

    private TArray<FCk_Handle_FoodPiece> _Loaded;
    private TArray<FCk_Handle_FoodPiece> _Unloaded;
    private TArray<EMars_Platter_LoadRefusal> _Refusals;

    // Armed by the load; the take hook acts once, the first frame it sees the joint settling.
    private bool _IsTakeArmed = false;
    private bool _HasTaken = false;
    // The settling entry's age when the hand took the joint: zero while the platter has not watched it since the drop.
    private float32 _SettlingSecondsAtTake = -1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);

        auto Owner = InHandle;
        Spawn_Floor(Owner, k_Origin + k_PlatterOffset);
        _PlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(
            FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5)),
            mars_items::Platter_Large()));

        Spawn_Floor(Owner, k_Origin + k_FoodOffset);
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto PieceOwner = ck::TransientEntity();
        _FoodEntity = utils_entity_script::Request_SpawnEntity(PieceOwner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        utils_timer::Create_Tick(Owner, FCk_Delegate_Timer(this, n"OnTakeTick"));

        // Past the platter's longest settle (Settle.MaxSeconds) a freeze would have pulled the joint back.
        const auto PastTheLongestSettle = FMars_Platter_SettleTuners().MaxSeconds + 0.5f;

        Add_Step_WaitUntil("the platter and the food item are constructed", n"Check_Constructed", k_SlowPolls, 0);
        Add_Step("load the slab's joint onto the platter", n"Step_Load");
        Add_Step_WaitUntil("the hand takes the joint before the platter's next pass after its drop", n"Check_Taken", k_SlowPolls, 0);
        Add_Step("the platter had not watched the joint when it was taken", n"Step_AssertTakenAtTheDrop");
        Add_Step_WaitUntil("the platter forgot the joint", n"Check_Forgotten", 0, 0);
        Add_Step_WaitSeconds("past the longest settle", PastTheLongestSettle);
        Add_Step("the joint stayed on the hand node and the platter is empty", n"Step_AssertStayedInTheHand");
        Run_Steps(InHandle);
    }

    // A static slab whose top is at InTop.
    private void Spawn_Floor(FCk_Handle& InOwner, FVector InTop)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InOwner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(80.0, 80.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto PlatterReady = ck::IsValid(_PlatterEntity) && _PlatterEntity.Is_Platter()
            && ck::IsValid(_PlatterEntity.As_WorldItem().Get_HeldItem());
        const auto FoodReady = ck::IsValid(_FoodEntity) && _FoodEntity.Is_WorldItem()
            && ck::IsValid(_FoodEntity.As_WorldItem().Get_HeldItem());
        if (PlatterReady && FoodReady && ck::Is_NOT_Valid(_Platter))
        {
            _Platter = _PlatterEntity.As_Platter();
            _Joint = _FoodEntity.As_FoodPiece();
            _Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnLoaded"));
            _Platter.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded"));
            _Platter.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnLoadRefused"));
        }

        auto Res = OutResult;
        Res.Set(PlatterReady && FoodReady);
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _IsTakeArmed = true;
        _Platter.Request_Load(FMars_Request_Platter_Load(_Joint));
    }

    // Takes the joint the first frame it is settling: its body Kinematic (as a mount asks before it attaches: a Dynamic body
    // would fight the attach) and the joint a scene-node child of the hand node, keeping its world pose.
    UFUNCTION()
    private void OnTakeTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_IsTakeArmed == false || _HasTaken || ck::Is_NOT_Valid(_Platter))
        { return; }

        const auto Settling = TryGet_Settling();
        if (Settling.IsSet() == false)
        { return; }

        _HasTaken = true;
        _SettlingSecondsAtTake = Settling.GetValue().Seconds;

        FCk_Handle JointEntity = _Joint;
        auto Body = JointEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        { utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic)); }

        auto JointTransform = JointEntity.As_Transform();
        const auto JointWorld = utils_transform::Get_EntityCurrentTransform(JointTransform);
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
        utils_scene_node::Add(JointTransform, _HandNode, JointWorld.GetRelativeTransform(HandWorld));
    }

    UFUNCTION()
    private void Check_Taken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HasTaken || _Loaded.Num() > 0 || _Refusals.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertTakenAtTheDrop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_HasTaken, "the hand took the joint while it settled");
        Assert_True(_SettlingSecondsAtTake == 0.0f,
            f"the platter had not watched the joint since its drop when the hand took it (settling for {_SettlingSecondsAtTake} s)");
        Assert_Equals_Int(_Loaded.Num(), 0, "the joint had not landed when it was taken");
    }

    UFUNCTION()
    private void Check_Forgotten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Joint.TryGet_Platter()));
    }

    UFUNCTION()
    private void Step_AssertStayedInTheHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_JointParent() == _HandNode, "the joint's parent is the hand node, not the platter root");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter is empty");
        Assert_True(ck::Is_NOT_Valid(_Joint.TryGet_Platter()), "the joint is off the platter's books");
        Assert_Equals_Int(_Loaded.Num(), 0, "no OnLoaded: the joint never landed");
        Assert_Equals_Int(_Unloaded.Num(), 0, "no OnUnloaded: a first landing leaves silently");
        Assert_Equals_Int(_Refusals.Num(), 0, "no refusal: a taken piece is not refused");
    }

    UFUNCTION()
    private void OnLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        _Loaded.Add(InPiece);
    }

    UFUNCTION()
    private void OnUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        _Unloaded.Add(InPiece);
    }

    UFUNCTION()
    private void OnLoadRefused(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        _Refusals.Add(InRefusal);
    }

    // The joint's entry in the platter's Settling list; unset while it is queued, held or gone.
    private TOptional<FMars_Platter_Settling> TryGet_Settling() const
    {
        for (const auto& Settling : _Platter.Get_Fragment(FMars_Fragment_Platter).Settling)
        {
            if (Settling.Piece == _Joint)
            { return TOptional<FMars_Platter_Settling>(Settling); }
        }

        return TOptional<FMars_Platter_Settling>();
    }

    // Invalid while the joint is not scene-node attached.
    private FCk_Handle_Transform Get_JointParent() const
    {
        FCk_Handle Entity = _Joint;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }
}
