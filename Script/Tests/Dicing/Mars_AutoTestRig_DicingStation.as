// The dicing-station rig: the real station, spawned at an isolated origin with a given food, and a bare operator (no input,
// no display) that takes and leaves it, so the station's own state machine runs Idle and Operated and its cut bridge turns
// every chop into a board cut. Chops and nudges are the Dicing requests the operator's input task would issue. The handlers
// record the board's signals and every cut outcome of a piece the test watches.
UCLASS(Abstract)
class UMars_AutoTestRig_DicingStation : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    // Pieces farther than this from the station's origin are not the station's.
    protected const float64 k_StationRadius = 300.0;

    protected FVector _Origin;
    protected UMars_CuttableFood_Def _Food;
    protected FCk_Handle_Station _Station;
    protected FCk_Handle_Dicing _Dicing;
    protected FCk_Handle_FoodBoard _Board;
    protected FCk_Handle_Operator _Operator;

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

    protected void Spawn_Station(FCk_Handle InHandle, FVector InOrigin, UMars_CuttableFood_Def InFood)
    {
        _Origin = InOrigin;
        _Food = InFood;

        auto SpawnParams = UMars_DicingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        SpawnParams.Food = TWeakObjectPtr<UMars_CuttableFood_Def>(InFood);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_DicingStation_EntityScript, SpawnParams);
        // As the map's entity spawner does: the station is its own context, so its state machine's ck::Ctx is the station.
        auto Station = Pending.Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Operator = utils_operator::Add(OperatorEntity);
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
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_StationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Dicing) && ck::IsValid(_Board));
    }

    // One Ready, shown joint on the board.
    UFUNCTION()
    protected void Check_JointShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == 1 && Get_AllHeldShown());
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
    private void OnBoardPieceCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative)
    {
        ++_PieceCuts;
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
