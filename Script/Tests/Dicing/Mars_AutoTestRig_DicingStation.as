// The dicing-station rig: the real station, spawned at an isolated origin, and a bare operator (no input, no display) that
// takes and leaves it, so the station's own state machine runs Idle and Operated: its intake takes the joint off the docked
// input platter, its cut bridge turns every chop into a board cut and its sweep bridge loads what a sweep hands off onto
// the docked finished tray. Chops and nudges are the Dicing requests the operator's input task would issue; a sweep is the
// control's own utils_dicing::Request_Sweep. Platters are World-mode platter world items under the test, lying beside the
// station until a test docks them. The handlers record the board's signals and every cut outcome of a piece the test
// watches.
UCLASS(Abstract)
class UMars_AutoTestRig_DicingStation : UCk_AutoTest_Base
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
    protected FCk_Handle_Station _Station;
    protected FCk_Handle_Dicing _Dicing;
    protected FCk_Handle_FoodBoard _Board;
    protected FCk_Handle_PlatterDock _InputDock;
    protected FCk_Handle_PlatterDock _OutputDock;
    protected FCk_Handle_Operator _Operator;

    // Under construction until the Check_*PlatterReady that resolves them.
    protected FCk_Handle _InputPlatterEntity;
    protected FCk_Handle _OutputPlatterEntity;
    protected FCk_Handle_Platter _InputPlatter;
    protected FCk_Handle_Item _InputPlatterItem;
    protected FCk_Handle_Platter _OutputPlatter;
    protected FCk_Handle_Item _OutputPlatterItem;

    protected int32 _ChopsIssued = 0;
    protected int32 _ChopsResolved = 0;
    protected TArray<FCk_Handle_FoodPiece> _Placed;
    protected int32 _PieceCuts = 0;
    protected int32 _Cleared = 0;
    protected TArray<FMars_FoodBoard_CutIssue> _Issues;
    protected TArray<FCk_Handle_FoodPiece> _Released;
    // In parallel: one entry per OnCutResolved of a watched piece.
    protected TArray<FCk_Handle_FoodPiece> _CutSources;
    protected TArray<EMars_FoodPiece_CutOutcome> _CutOutcomes;

    protected void Spawn_Station(FCk_Handle InHandle, FVector InOrigin)
    {
        Spawn_StationOfClass(InHandle, InOrigin, UMars_DicingStation_EntityScript);
    }

    // InClass is the station or a test's subclass of it with other class defaults (its docks' policies); the station's
    // spawn params fit both, as they are injected by property name.
    protected void Spawn_StationOfClass(FCk_Handle InHandle, FVector InOrigin, TSubclassOf<UMars_DicingStation_EntityScript> InClass)
    {
        _Origin = InOrigin;

        auto SpawnParams = UMars_DicingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, InClass, SpawnParams);
        // As the map's entity spawner does: the station is its own context, so its state machine's ck::Ctx is the station.
        auto Station = Pending.Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Operator = utils_operator::Add(OperatorEntity);
    }

    // A platter with InFood's whole joint on it, beside the station (after Spawn_Station); Check_InputPlatterReady resolves
    // it once the joint has landed.
    protected void Spawn_InputPlatter(FCk_Handle InHandle, UMars_Food_Def InFood)
    {
        _Food = InFood;

        auto Owner = InHandle;
        _InputPlatterEntity = utils_platter::Request_SpawnWorld(Owner,
            FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, _Origin + k_InputPlatterOffset), InFood));
    }

    // An empty platter beside the station (after Spawn_Station); Check_OutputPlatterReady resolves it.
    protected void Spawn_OutputPlatter(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        _OutputPlatterEntity = utils_platter::Request_SpawnWorld(Owner,
            FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, _Origin + k_OutputPlatterOffset)));
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

    // The common opening: the station and the input platter's joint are ready, the platter docks (the intake lays the joint
    // on the board whoever operates), an operator takes the station and the joint is on the board, its pose landed.
    protected void Add_Steps_IntakeTheJoint()
    {
        Add_Step_WaitUntil("the station composed its Dicing, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the input platter is constructed and its joint landed", n"Check_InputPlatterReady", 0, 10.0f);
        Add_Step("dock the input platter", n"Step_DockInput");
        Add_Step_WaitUntil("the input platter is docked", n"Check_InputDocked", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step_WaitUntil("the intake laid one shown joint on the board", n"Check_JointOnBoard", 0, 5.0f);
        Add_Step_WaitFrames("the pile pose has landed", 2);
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
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
    }

    protected void MoveHandTo(float32 InLateral)
    {
        _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge((InLateral - _Dicing.Get_HandLateral()) / _Dicing.Get_Spec().LateralPerDegree));
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
        utils_dicing::Request_Sweep(_Station);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_StationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Dicing) && ck::IsValid(_Board) && ck::IsValid(_InputDock) && ck::IsValid(_OutputDock));
    }

    // Constructed, its holder holds its item, and its joint has landed (the input dock takes only a platter with food).
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

    // Docked and arrived on the dock: a station torn down under a platter still lerping onto its dock leaves the arrival
    // writing an offset under a dead parent.
    UFUNCTION()
    protected void Check_InputDocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_InputPlatter) && _InputDock.Get_Platter() == _InputPlatter && Get_HasArrived(_InputPlatter));
    }

    UFUNCTION()
    protected void Check_OutputDocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_OutputPlatter) && _OutputDock.Get_Platter() == _OutputPlatter && Get_HasArrived(_OutputPlatter));
    }

    // One Ready, shown joint on the board (the intake runs in Idle and Operated).
    UFUNCTION()
    protected void Check_JointOnBoard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == 1 && Get_AllHeldShown());
    }

    UFUNCTION()
    protected void Check_Idle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Dicing_Idle);
    }

    UFUNCTION()
    protected void Check_Operated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Dicing_Operated);
    }

    // Every chop resolved and the cleaver is back up.
    UFUNCTION()
    protected void Check_ChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsResolved == _ChopsIssued && _Dicing.Get_IsChopping() == false);
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
        _Dicing = InEntityScriptHandle.As_Dicing();
        _Board = InEntityScriptHandle.As_FoodBoard();
        _InputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Input);
        _OutputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Output);

        _Dicing.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
        _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
        _Board.BindTo_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnBoardPieceCut"));
        _Board.BindTo_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
        _Board.BindTo_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnBoardCutIssued"));
        _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        ++_ChopsResolved;
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
