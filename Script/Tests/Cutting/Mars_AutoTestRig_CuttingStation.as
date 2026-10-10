// The cutting-station rig: the real station, spawned at an isolated origin, and a bare operator (no display; input only when
// a test arms the add-food key) that takes and leaves it, so the station's own state machine runs Idle and Operated: its
// feed draws from the docked input platter and its feed bridge lays a released joint on the board, its cut bridge turns
// every chop into a board cut and its sweep bridge loads what a sweep hands off onto the docked finished tray. Add food,
// chops and nudges are the CookingFeed and Cutting requests the operator's input tasks would issue (Add_Food bypasses the
// station's board-busy gate; a test that needs the gate presses the real key: Arm_AddFoodKey); a sweep is the control's own
// utils_cutting::Request_Sweep. Platters are large World-mode platter world items under the test (a meat joint and its
// halves lie inside a large tray's walls), each lying on a static floor beside the station until a test docks it (a platter
// drops what it is given only while it lies still). The handlers record the board's and the feed's signals and every cut
// outcome of a piece the test watches.
UCLASS(Abstract)
class UMars_AutoTestRig_CuttingStation : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    // Pieces farther than this from the station's origin are not the station's.
    protected const float64 k_StationRadius = 300.0;
    // Where the platters lie before they dock, from the station's origin.
    protected const FVector k_InputPlatterOffset = FVector(0.0, -300.0, 0.0);
    protected const FVector k_OutputPlatterOffset = FVector(0.0, 300.0, 0.0);

    protected FVector _Origin;
    // The input platter's food.
    protected UMars_Food_Def _Food;
    private UMars_AutoTestHelper_FoodOnPlatter _FoodOnPlatter;
    protected FCk_Handle_Station _Station;
    protected FCk_Handle_Cutting _Cutting;
    protected FCk_Handle_FoodBoard _Board;
    protected FCk_Handle_CookingFeed _Feed;
    protected FCk_Handle_PlatterDock _InputDock;
    protected FCk_Handle_PlatterDock _OutputDock;
    protected FCk_Handle_Operator _Operator;

    // The operator's add-food key (Arm_AddFoodKey): its intents and a private input stack the test presses the key on.
    protected FCk_Handle_InputIntents _OperatorIntents;
    private FCk_Handle_InputSource _AddFoodSource;
    private FCk_Handle_InputButtonMap _AddFoodMap;
    private FCk_Handle_IntentSampler _AddFoodSampler;
    private FCk_Handle_IntentMatcher _AddFoodMatcher;
    private FKey _AddFoodKey;

    // Under construction until the Check_*PlatterReady that resolves them.
    protected FCk_Handle _InputPlatterEntity;
    protected FCk_Handle _OutputPlatterEntity;
    protected FCk_Handle_Platter _InputPlatter;
    protected FCk_Handle_Item _InputPlatterItem;
    protected FCk_Handle_Platter _OutputPlatter;
    protected FCk_Handle_Item _OutputPlatterItem;

    protected int32 _ChopsIssued = 0;
    protected int32 _ChopsLanded = 0;
    // One entry per OnTurned: its yaw.
    protected TArray<float32> _Turns;
    protected TArray<FCk_Handle_FoodPiece> _Placed;
    protected int32 _PieceCuts = 0;
    protected int32 _Cleared = 0;
    protected TArray<FMars_FoodBoard_CutIssue> _Issues;
    protected TArray<FCk_Handle_FoodPiece> _Released;
    // In parallel: one entry per OnCutResolved of a watched piece.
    protected TArray<FCk_Handle_FoodPiece> _CutSources;
    protected TArray<EMars_FoodPiece_CutOutcome> _CutOutcomes;
    // Every phase the feed entered, in order.
    protected TArray<EMars_CookingFeed_Phase> _FeedPhases;
    // Presses the feed itself refused (a press the station refused never reaches it).
    protected TArray<EMars_CookingFeed_Refusal> _FeedRefusals;

    protected void Spawn_Station(FCk_Handle InHandle, FVector InOrigin)
    {
        Spawn_StationOfClass(InHandle, InOrigin, UMars_CuttingStation_EntityScript);
    }

    // InClass is the station or a test's subclass of it with other class defaults (its docks' policies); the station's
    // spawn params fit both, as they are injected by property name.
    protected void Spawn_StationOfClass(FCk_Handle InHandle, FVector InOrigin, TSubclassOf<UMars_CuttingStation_EntityScript> InClass)
    {
        _Origin = InOrigin;

        auto SpawnParams = UMars_CuttingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, InClass, SpawnParams);
        // As the map's entity spawner does: the station is its own context, so its state machine's ck::Ctx is the station.
        auto Station = Pending.Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Operator = utils_operator::Add(OperatorEntity);
    }

    // The operator gets InputIntents and a private input stack (source, button map, sampler, layer, matcher) whose one level
    // row is StationAddFood on F10, as the player's input profile feeds the player's (after Spawn_Station, before the
    // station is taken: its input task reads the operator's intents on enter). Add_Steps_ArmTheAddFoodKey makes the row live.
    protected void Arm_AddFoodKey(FCk_Handle InHandle)
    {
        FCk_Handle OperatorEntity = _Operator;
        _OperatorIntents = utils_input_intents::Add(OperatorEntity);
        _AddFoodKey = EKeys::F10;

        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _AddFoodSource = utils_input_source::Add(Owner, FCk_InputSource_Spec(0));

        TArray<FKey> PhysicalButtons;
        PhysicalButtons.Add(_AddFoodKey);
        _AddFoodMap = utils_input_button_map::Add(Owner, FCk_InputButtonMap_Spec(PhysicalButtons));
        _AddFoodSampler = utils_intent_sampler::Add(Owner, FCk_IntentSampler_Spec(120));

        FCk_Handle LayerEntity = utils_input_layer::Create(Owner, FCk_InputLayer_Spec(_AddFoodSource, 50));
        _AddFoodMatcher = utils_intent_matcher::Add(LayerEntity, FCk_IntentMatcher_Spec());
    }

    protected void Add_Steps_ArmTheAddFoodKey()
    {
        Add_Step_WaitUntil("the add-food key is minted and the sampler records", n"Check_AddFoodKeyRecording", 0, 5.0f);
        Add_Step("bake the add-food level row and swap it in", n"Step_SwapAddFoodSet");
        Add_Step_WaitUntil("the add-food row is live on the matcher", n"Check_AddFoodSetActive", 0, 5.0f);
        Add_Step("the operator's intents read the matcher", n"Step_UseAddFoodMatcher");
        Add_Step_WaitUntil("the operator reads the matcher", n"Check_OperatorReadsMatcher", 0, 2.0f);
    }

    protected void Inject_AddFoodKey(ECk_InputSource_EventType InEventType)
    {
        auto Event = FCk_InputSource_RawEvent(ECk_InputSource_DeviceClass::Keyboard, _AddFoodKey, InEventType);
        utils_input_source::Request_InjectRawEvent(_AddFoodSource, FCk_Request_InputSource_InjectRawEvent(Event));
    }

    // A large platter on a floor beside the station (after Spawn_Station) with InFoodItem's whole joint loaded onto it (the
    // kernel path: no hand); Check_InputPlatterReady resolves it once the joint has landed.
    protected void Spawn_InputPlatter(FCk_Handle InHandle, UCk_InventoryItem_Definition InFoodItem)
    {
        _InputPlatterEntity = Spawn_LoadedPlatterAt(InHandle, k_InputPlatterOffset, InFoodItem);
    }

    // A large platter lying on a floor at InOffset from the station's origin, with InFoodItem's food item spawned above it
    // and loaded onto it once constructed; _Food names the food. Returns the platter entity under construction.
    protected FCk_Handle Spawn_LoadedPlatterAt(FCk_Handle InHandle, FVector InOffset, UCk_InventoryItem_Definition InFoodItem)
    {
        const UMars_ItemTrait_Food FoodTrait = InFoodItem.Get_ItemTraitByClass(UMars_ItemTrait_Food);
        _Food = FoodTrait.Food;

        auto PlatterEntity = Spawn_PlatterAt(InHandle, InOffset, FMars_Platter_SpawnSpec(FTransform::Identity, mars_items::Platter_Large()));
        if (ck::Is_NOT_Valid(_FoodOnPlatter))
        { _FoodOnPlatter = Cast<UMars_AutoTestHelper_FoodOnPlatter>(NewObject(this, UMars_AutoTestHelper_FoodOnPlatter)); }

        Track_ForCleanup(_FoodOnPlatter.Spawn_Onto(PlatterEntity, InFoodItem,
            FTransform(FRotator::ZeroRotator, _Origin + InOffset + FVector(0.0, 0.0, 60.0))));
        return PlatterEntity;
    }

    // An empty large platter on a floor beside the station (after Spawn_Station); Check_OutputPlatterReady resolves it.
    protected void Spawn_OutputPlatter(FCk_Handle InHandle)
    {
        Spawn_OutputPlatterOf(InHandle, mars_items::Platter_Large());
    }

    protected void Spawn_OutputPlatterOf(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
    {
        _OutputPlatterEntity = Spawn_PlatterAt(InHandle, k_OutputPlatterOffset, FMars_Platter_SpawnSpec(FTransform::Identity, InDefinition));
    }

    // InSpec's platter lying on a floor at InOffset from the station's origin (InSpec.World is replaced).
    protected FCk_Handle Spawn_PlatterAt(FCk_Handle InHandle, FVector InOffset, FMars_Platter_SpawnSpec InSpec)
    {
        auto Owner = InHandle;
        Spawn_PlatterFloor(Owner, _Origin + InOffset);

        auto Spec = InSpec;
        Spec.World = FTransform(FRotator::ZeroRotator, _Origin + InOffset + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5));
        return utils_platter::Request_SpawnWorld(Owner, Spec);
    }

    // A static slab whose top is at InTop, for a World-mode platter to lie still on (a platter drops what it is given only
    // while it lies still); a platter spawned at InTop + the tray's base height rests on it.
    protected void Spawn_PlatterFloor(FCk_Handle InHandle, FVector InTop)
    {
        auto Owner = InHandle;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(60.0, 60.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
    }


    protected void Dock_Input()
    {
        _InputDock.Request_Dock(FMars_Request_PlatterDock_Dock(_InputPlatterItem));
    }

    protected void Dock_Output()
    {
        _OutputDock.Request_Dock(FMars_Request_PlatterDock_Dock(_OutputPlatterItem));
    }

    // The FoodPiece rig's box fixture (a CPU-readable 1000 cm3 cube) with no kind and no definition: Transform, RuntimeMesh
    // and FoodPiece on a new entity under the world's transient entity, tracked for cleanup.
    protected FCk_Handle_FoodPiece Build_Box(FTransform InWorld)
    {
        auto Spec = FMars_FoodPiece_Spec();
        Spec.Data.MassKg = 0.8;
        Spec.Tuners = FMars_FoodPiece_Tuners(0.0001, 0.05);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(ck::TransientEntity());
        Track_ForCleanup(Entity);
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        utils_runtime_mesh::Add(Entity, FCk_RuntimeMesh_Spec(
            TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/CkTests/CkRuntimeMesh/Cooked/SM_Import_CPU.SM_Import_CPU"))));
        return utils_foodpiece::Add(Entity, Spec);
    }

    // The common opening: the station and the input platter's joint are ready, the platter docks and the feed draws from
    // it, an operator takes the station and adds food: the joint is on the board, its pose landed, the glove back at rest.
    protected void Add_Steps_FeedTheJoint()
    {
        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard, feed and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the input platter is constructed and its joint landed", n"Check_InputPlatterReady", 0, 10.0f);
        Add_Step("dock the input platter", n"Step_DockInput");
        Add_Step_WaitUntil("the input platter is docked", n"Check_InputDocked", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step_WaitUntil("the feed draws from the docked platter, its joint frozen", n"Check_FeedSourced", 0, 5.0f);
        Add_Step("add food", n"Step_AddFood");
        Add_Step_WaitUntil("the feed laid one shown joint on the board and the glove is back", n"Check_JointOnBoardAndFeedIdle", 0, 5.0f);
        Add_Step_WaitFrames("the pile pose has landed", 2);
    }

    // What the operator's add-food press issues once the station lets it through.
    protected void Add_Food()
    {
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    protected void Take()
    {
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    protected void Leave()
    {
        _Station.Request_Release(FMars_Request_Station_Release(_Operator, EMars_Station_ReleaseReason::OperatorRequested));
    }

    protected void Chop()
    {
        ++_ChopsIssued;
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
    }

    protected void MoveHandTo(float32 InLateral)
    {
        _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge((InLateral - _Cutting.Get_HandLateral()) / _Cutting.Get_Spec().LateralPerDegree));
    }

    protected void Watch(FCk_Handle_FoodPiece InPiece)
    {
        auto Piece = InPiece;
        Piece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnWatchedPieceCutResolved"));
    }

    protected FTransform Get_StationWorld() const
    {
        FCk_Handle Entity = _Station;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    protected FTransform Get_World(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    // The piece's mesh centroid in the world.
    protected FVector Get_WorldCentroid(FCk_Handle_FoodPiece InPiece) const
    {
        return Get_World(InPiece).TransformPosition(utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry()).Get_CentroidCm());
    }

    protected bool Get_IsShown(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        if (Entity.Is_RuntimeMeshDisplay() == false)
        { return false; }

        return utils_runtime_mesh_display::Get_SetupState(Entity.As_RuntimeMeshDisplay()) == ECk_RuntimeMesh_SetupState::Ready;
    }

    // Every held piece is Ready and shown.
    protected bool Get_AllHeldShown() const
    {
        for (const auto& Piece : _Board.Get_Held())
        {
            if (Piece.Get_Status() != EMars_FoodPiece_Status::Ready || Get_IsShown(Piece) == false)
            { return false; }
        }

        return true;
    }

    protected float Get_HeldMassKg() const
    {
        auto MassKg = 0.0;
        for (const auto& Piece : _Board.Get_Held())
        { MassKg += Piece.Get_MassKg(); }

        return MassKg;
    }

    protected float Get_HeldVolumeCm3() const
    {
        auto VolumeCm3 = 0.0;
        for (const auto& Piece : _Board.Get_Held())
        { VolumeCm3 += Piece.Get_VolumeCm3(); }

        return VolumeCm3;
    }

    // Live pieces near the station; roots only (a whole joint) when InRootsOnly.
    protected TArray<FCk_Handle_FoodPiece> Get_StationPieces(bool InRootsOnly) const
    {
        TArray<FCk_Handle_FoodPiece> Pieces;
        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(ck::TransientEntity()))
        {
            if (ck::Is_NOT_Valid(Dependent) || utils_entity_lifetime::Get_IsPendingDestroy(Dependent, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
                || Dependent.Is_FoodPiece() == false)
            { continue; }

            const auto Piece = Dependent.As_FoodPiece();
            if (InRootsOnly && Piece.Get_ParentId().IsValid())
            { continue; }

            if ((Get_World(Piece).GetLocation() - _Origin).Size() <= k_StationRadius)
            { Pieces.Add(Piece); }
        }

        return Pieces;
    }

    // A WorldItem and a Platter whose holder holds its item.
    protected bool Get_IsPlatterConstructed(FCk_Handle InEntity) const
    {
        return ck::IsValid(InEntity) && InEntity.Is_WorldItem() && InEntity.Is_Platter() && ck::IsValid(InEntity.As_WorldItem().Get_HeldItem());
    }

    // The node InPiece hangs off; invalid while it is not a scene node.
    protected FCk_Handle_Transform Get_Parent(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    // Carried and no longer lerping onto its carrier.
    protected bool Get_HasArrived(FCk_Handle_Platter InPlatter) const
    {
        FCk_Handle Entity = InPlatter;
        const auto WorldItem = Entity.As_WorldItem();
        return WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried && Entity.Has_Fragment(FMars_Fragment_WorldItem_Arrival) == false;
    }

    protected bool Get_HasBody(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        return Entity.Is_JoltBody();
    }

    protected int32 Get_LineageCount(FGuid InLineage) const
    {
        auto Count = 0;
        for (const auto& Piece : Get_StationPieces(false))
        {
            if (Piece.Get_Lineage() == InLineage)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_OutcomeCount(FCk_Handle_FoodPiece InSource, EMars_FoodPiece_CutOutcome InOutcome) const
    {
        auto Count = 0;
        for (int32 Index = 0; Index < _CutSources.Num(); ++Index)
        {
            if (_CutSources[Index] == InSource && _CutOutcomes[Index] == InOutcome)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_OutcomeCountFor(FCk_Handle_FoodPiece InSource) const
    {
        auto Count = 0;
        for (const auto& Source : _CutSources)
        {
            if (Source == InSource)
            { ++Count; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_DockInput(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock_Input();
    }

    UFUNCTION()
    protected void Step_DockOutput(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock_Output();
    }

    UFUNCTION()
    protected void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Take();
    }

    UFUNCTION()
    protected void Step_Leave(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Leave();
    }

    UFUNCTION()
    protected void Step_Sweep(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_cutting::Request_Sweep(_Station);
    }

    UFUNCTION()
    protected void Step_AddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Add_Food();
    }

    UFUNCTION()
    protected void Step_PressAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Inject_AddFoodKey(ECk_InputSource_EventType::Pressed);
    }

    UFUNCTION()
    protected void Step_ReleaseAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Inject_AddFoodKey(ECk_InputSource_EventType::Released);
    }

    UFUNCTION()
    protected void Step_SwapAddFoodSet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto AddFoodTag = GameplayTags::Mars_Intent_StationAddFood;
        auto Parsed = utils_intent_grammar::Parse("AF level", AddFoodTag.TagName, 0, AddFoodTag);
        if (Parsed.Get_Outcome() != ECk_SucceededFailed::Succeeded)
        {
            FinishFailure("the add-food level notation failed to parse");
            return;
        }

        TArray<FCk_Intent_Definition> Definitions;
        Definitions.Add(Parsed.Get_Definition());

        TArray<FCk_Intent_ButtonNameRow> Rows;
        Rows.Add(FCk_Intent_ButtonNameRow(n"AF", FCk_Input_ButtonId(ECk_Input_ButtonTier::Physical, _AddFoodKey.GetKeyName())));

        auto Baked = utils_intent_grammar::Bake(Definitions, Rows);
        if (Baked.Get_Outcome() != ECk_SucceededFailed::Succeeded)
        {
            FinishFailure("the add-food level row failed to bake");
            return;
        }

        utils_intent_matcher::Request_SwapSet(_AddFoodMatcher, FCk_Request_IntentMatcher_SwapSet(Baked.Get_CompiledSet()));
    }

    UFUNCTION()
    protected void Step_UseAddFoodMatcher(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _OperatorIntents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_AddFoodMatcher));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_StationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Cutting) && ck::IsValid(_Board) && ck::IsValid(_Feed) && ck::IsValid(_InputDock) && ck::IsValid(_OutputDock));
    }

    // Constructed, its holder holds its item, and its joint has landed.
    UFUNCTION()
    protected void Check_InputPlatterReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = Get_IsPlatterConstructed(_InputPlatterEntity) && _InputPlatterEntity.As_Platter().Get_HeldCount() == 1;
        if (IsReady && ck::Is_NOT_Valid(_InputPlatter))
        {
            _InputPlatter = _InputPlatterEntity.As_Platter();
            _InputPlatterItem = _InputPlatterEntity.As_WorldItem().Get_HeldItem();
            Track_ForCleanup(_InputPlatter.Get_Held()[0]);
        }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    protected void Check_OutputPlatterReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = Get_IsPlatterConstructed(_OutputPlatterEntity);
        if (IsReady && ck::Is_NOT_Valid(_OutputPlatter))
        {
            _OutputPlatter = _OutputPlatterEntity.As_Platter();
            _OutputPlatterItem = _OutputPlatterEntity.As_WorldItem().Get_HeldItem();
        }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    // Docked and arrived on the dock (the dock says so too): a station torn down under a platter still lerping onto its dock
    // leaves the arrival writing an offset under a dead parent.
    UFUNCTION()
    protected void Check_InputDocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_InputPlatter) && _InputDock.Get_Platter() == _InputPlatter && Get_HasArrived(_InputPlatter)
            && _InputDock.Get_HasArrived());
    }

    UFUNCTION()
    protected void Check_OutputDocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_OutputPlatter) && _OutputDock.Get_Platter() == _OutputPlatter && Get_HasArrived(_OutputPlatter)
            && _OutputDock.Get_HasArrived());
    }

    // One Ready, shown joint on the board (the feed bridge runs in Idle and Operated).
    UFUNCTION()
    protected void Check_JointOnBoard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == 1 && Get_AllHeldShown());
    }

    UFUNCTION()
    protected void Check_JointOnBoardAndFeedIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == 1 && Get_AllHeldShown() && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    // The feed draws from the docked input platter and a press finds a frozen top to reach for.
    UFUNCTION()
    protected void Check_FeedSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_InputPlatter) && _Feed.Get_Source() == _InputPlatter && _Feed.Get_Available() > 0
            && _Feed.Get_IsSettling() == false && _InputPlatter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    protected void Check_FeedIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    protected void Check_AddFoodKeyRecording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_input_button_map::Get_ButtonIdsForKey(_AddFoodMap, _AddFoodKey).Num() >= 1 &&
                utils_intent_sampler::Get_FrameCount(_AddFoodSampler) >= 1);
    }

    UFUNCTION()
    protected void Check_AddFoodSetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_intent_matcher::Get_ActiveIntentCount(_AddFoodMatcher) == 1 &&
                utils_intent_matcher::Get_RegisteredCaptureKeys(_AddFoodMatcher).Contains(_AddFoodKey));
    }

    UFUNCTION()
    protected void Check_OperatorReadsMatcher(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OperatorIntents.Get_Matcher() == _AddFoodMatcher);
    }

    UFUNCTION()
    protected void Check_AddFoodHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OperatorIntents.Get_IsIntentActive(GameplayTags::Mars_Intent_StationAddFood));
    }

    UFUNCTION()
    protected void Check_AddFoodReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OperatorIntents.Get_IsIntentActive(GameplayTags::Mars_Intent_StationAddFood) == false);
    }

    UFUNCTION()
    protected void Check_Idle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Cutting_Idle);
    }

    UFUNCTION()
    protected void Check_Operated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Cutting_Operated);
    }

    // Every chop landed and the cleaver is back up.
    UFUNCTION()
    protected void Check_ChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsLanded == _ChopsIssued && _Cutting.Get_IsChopping() == false);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave the station alive into later tests.
        Track_ForCleanup(InEntityScriptHandle);
        _Station = InEntityScriptHandle.As_Station();
        _Cutting = InEntityScriptHandle.As_Cutting();
        _Board = InEntityScriptHandle.As_FoodBoard();
        _Feed = InEntityScriptHandle.As_CookingFeed();
        _InputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Input);
        _OutputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Output);

        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));
        _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
        _Board.BindTo_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnBoardPieceCut"));
        _Board.BindTo_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
        _Board.BindTo_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnBoardCutIssued"));
        _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        _Board.BindTo_OnTurned(FMars_Delegate_FoodBoard_OnTurned(this, n"OnBoardTurned"));
        _Feed.BindTo_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnFeedPhaseChanged"));
        _Feed.BindTo_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnFeedTransferRefused"));
    }

    UFUNCTION()
    private void OnFeedPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase)
    {
        _FeedPhases.Add(InPhase);
    }

    UFUNCTION()
    private void OnFeedTransferRefused(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal)
    {
        _FeedRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnChopLanded(FCk_Handle_Cutting InCutting)
    {
        ++_ChopsLanded;
    }

    UFUNCTION()
    private void OnBoardTurned(FCk_Handle_FoodBoard InBoard, float32 InYawDegrees)
    {
        _Turns.Add(InYawDegrees);
    }

    UFUNCTION()
    private void OnBoardPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        _Placed.Add(InPiece);
    }

    UFUNCTION()
    // Pieces live under the world's transient entity: one that ends on a platter (owned by the test) would outlive the
    // test's leak check, so every half is tracked, as the joint is.
    private void OnBoardPieceCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative)
    {
        ++_PieceCuts;
        Track_ForCleanup(InPositive);
        Track_ForCleanup(InNegative);
    }

    UFUNCTION()
    private void OnBoardCleared(FCk_Handle_FoodBoard InBoard)
    {
        ++_Cleared;
    }

    UFUNCTION()
    private void OnBoardCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue)
    {
        _Issues.Add(InIssue);
        On_CutIssued(InIssue);
    }

    // A test's hook into the frame a chop's cuts are submitted, before RuntimeMesh slices them.
    protected void On_CutIssued(const FMars_FoodBoard_CutIssue& InIssue)
    {
    }

    UFUNCTION()
    private void OnBoardReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        _Released.Add(InPiece);
    }

    UFUNCTION()
    private void OnWatchedPieceCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        _CutSources.Add(InSource);
        _CutOutcomes.Add(InResult.Outcome);
    }
}
