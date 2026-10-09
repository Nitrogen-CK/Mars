// A Clear that meets a cut in flight leaves nothing of it. In flight: filler slices queued ahead keep board A's cut waiting
// in RuntimeMesh's queue while the board is cleared, so the piece is destroyed before its slice runs and no half is ever made.
// Same frame: board B is cleared from inside its piece's OnCutResolved(Cut), so the Clear and the cut's ResolveCut share a
// drain; the Clear goes first and the halves the piece already made are destroyed. Either way: no OnPieceCut, Held empty,
// OnCleared once, and no piece of either lineage survives.
class UMars_AutoTest_FoodBoard_ClearWhileCuttingCommitsNothing : UMars_AutoTestRig_FoodBoard
{
    private int32 _FillerCount = 8;

    private FCk_Handle_FoodBoard _BoardA;
    private FCk_Handle_FoodPiece _PieceA;
    private FGuid _LineageA;
    private FCk_Handle_RuntimeMesh _Filler;
    private FCk_Handle _FillerOwner;
    private int32 _FillersResolved = 0;

    private FCk_Handle_FoodBoard _BoardB;
    private FCk_Handle_FoodPiece _PieceB;
    private FGuid _LineageB;
    private bool _ClearedFromCut = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _BoardA = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(6400.0, 3000.0, -42000.0)), Make_Tuners());
        _PieceA = Build_BoxOn(_BoardA, FTransform(FRotator(0.0, 15.0, 0.0), FVector(2.0, 3.0, 0.0)), 1.0);
        Place(_BoardA, _PieceA);

        _BoardB = Build_Board(InHandle, FTransform(FRotator(0.0, -45.0, 0.0), FVector(6400.0, 3400.0, -42000.0)), Make_Tuners());
        _PieceB = Build_BoxOn(_BoardB, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 0.0)), 1.0);
        Place(_BoardB, _PieceB);

        auto FillerEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Filler = utils_runtime_mesh::Add(FillerEntity, FCk_RuntimeMesh_Spec(Get_BoxMesh()));
        _FillerOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);

        Add_Step_WaitUntil("both boxes and the filler mesh are Ready, both boxes placed", n"Check_Ready");
        Add_Step("queue filler slices, then chop board A", n"Step_QueueThenChopA");
        Add_Step_WaitUntil("board A's cut is in flight", n"Check_CuttingA");
        Add_Step("clear board A while its cut waits in the queue", n"Step_ClearA");
        Add_Step_WaitUntil("every filler resolved and the piece's slice was let go", n"Check_SettledA");
        Add_Step("chop board B, clearing it from inside its piece's cut", n"Step_ChopB");
        Add_Step_WaitUntil("board B's piece was cut and board B cleared", n"Check_SettledB");
        Add_Step_WaitSeconds("a late OnPieceCut or a surviving half would show in this window", 0.3f);
        Add_Step("neither clear let anything of its cut reach the board", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_BoardA) == 1 && Get_PlacedCount(_BoardB) == 1 && Get_HasReadied(_PieceA) && Get_HasReadied(_PieceB)
            && utils_runtime_mesh::Get_SetupState(_Filler) == ECk_RuntimeMesh_SetupState::Ready);
    }

    UFUNCTION()
    private void Step_QueueThenChopA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < _FillerCount; ++Index)
        {
            auto Slice = FCk_Request_RuntimeMesh_Slice();
            Slice.Set_OperationID(FGuid::NewGuid());
            Slice.Set_ResultOwner(_FillerOwner);
            Slice.Set_Plane(Make_Plane(FVector(5.0, 5.0, 5.0), FVector::ForwardVector));
            utils_runtime_mesh::Request_Slice(_Filler, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnFillerResolved"));
        }

        Assert_Equals_Int(_FillersResolved, 0, "every filler slice was queued, none rejected on submission");

        _LineageA = _PieceA.Get_Lineage();
        Chop(_BoardA, Make_WorldPlane(Get_WorldBoundsCenter(_PieceA), Get_BoardWorld(_BoardA).TransformVectorNoScale(FVector::ForwardVector)));
    }

    // A chop that issued nothing, or a cut already resolved, settles at once so the next step's assertions report it.
    UFUNCTION()
    private void Check_CuttingA(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Issues = Get_Issues(_BoardA);
        Res.Set(_PieceA.Get_IsCutting() || _Cuts.Num() > 0 || (Issues.Num() > 0 && Issues[0].Issued == 0));
    }

    UFUNCTION()
    private void Step_ClearA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PieceA.Get_IsCutting(), "board A's piece is cutting when the board is cleared");
        Assert_True(_PieceA.Get_HasBoardCutPending(), "the board's cut is the one pending");
        Assert_True(utils_foodpiece::Get_HasPendingCut(ck::TransientEntity(), _PieceA), "the slice is still in the queue when the board is cleared");
        Assert_True(_FillersResolved < _FillerCount, "filler slices are still queued ahead of the piece's");

        auto Board = _BoardA;
        Board.Request_Clear(FMars_Request_FoodBoard_Clear());
    }

    UFUNCTION()
    private void Check_SettledA(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FillersResolved == _FillerCount && utils_foodpiece::Get_HasPendingCut(ck::TransientEntity(), _PieceA) == false
            && Get_ClearedCount(_BoardA) >= 1);
    }

    UFUNCTION()
    private void Step_ChopB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LineageB = _PieceB.Get_Lineage();

        // Bound after the board's own handler, so the cut's ResolveCut is already queued when this Clear is.
        auto Piece = _PieceB;
        Piece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnPieceBCutResolved"));
        Chop(_BoardB, Make_WorldPlane(Get_WorldBoundsCenter(_PieceB), Get_BoardWorld(_BoardB).TransformVectorNoScale(FVector::RightVector)));
    }

    // A chop that issued nothing, or a piece B outcome other than Cut, settles at once so the assertions report it.
    UFUNCTION()
    private void Check_SettledB(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Issues = Get_Issues(_BoardB);
        if (Issues.Num() > 0 && Issues[0].Issued == 0)
        {
            Res.Set(true);
            return;
        }

        if (Get_HasNonCutOutcome(_PieceB))
        {
            Res.Set(true);
            return;
        }

        Res.Set(_ClearedFromCut && Get_ClearedCount(_BoardB) >= 1);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_PieceCuts(_BoardA).Num(), 0, "[in flight] no OnPieceCut");
        Assert_False(Get_HasOutcome(_PieceA), "[in flight] the piece destroyed mid-cut resolved nothing");
        Assert_True(ck::Is_NOT_Valid(_PieceA), "[in flight] the held piece is destroyed");
        Assert_Equals_Int(_BoardA.Get_HeldCount(), 0, "[in flight] Held is empty");
        Assert_Equals_Int(Get_ClearedCount(_BoardA), 1, "[in flight] OnCleared fired once");
        Assert_Equals_Int(Get_LineagePieces(_LineageA).Num(), 0, "[in flight] no piece of the lineage survives");

        Assert_True(_ClearedFromCut, "[same frame] the piece's cut committed and the board was cleared from inside it");
        const auto CutB = Get_CutFor(_PieceB);
        Assert_True(ck::Is_NOT_Valid(CutB.Positive) && ck::Is_NOT_Valid(CutB.Negative), "[same frame] the cut's halves are destroyed");
        Assert_Equals_Int(Get_PieceCuts(_BoardB).Num(), 0, "[same frame] no OnPieceCut");
        Assert_Equals_Int(_BoardB.Get_HeldCount(), 0, "[same frame] Held is empty");
        Assert_Equals_Int(Get_ClearedCount(_BoardB), 1, "[same frame] OnCleared fired once");
        Assert_True(_BoardB.Get_IsUntouched(), "[same frame] the cleared board is untouched");
        Assert_Equals_Int(Get_LineagePieces(_LineageB).Num(), 0, "[same frame] no piece of the lineage survives");
    }

    // InSource's OnCutResolved with a Cut outcome; a default result when there is none.
    private FMars_FoodPiece_CutResult Get_CutFor(FCk_Handle_FoodPiece InSource) const
    {
        for (int32 Index = 0; Index < _Cuts.Num(); ++Index)
        {
            if (_CutSources[Index] == InSource && _Cuts[Index].Outcome == EMars_FoodPiece_CutOutcome::Cut)
            { return _Cuts[Index]; }
        }

        return FMars_FoodPiece_CutResult();
    }

    private bool Get_HasOutcome(FCk_Handle_FoodPiece InSource) const
    {
        for (const auto& Source : _CutSources)
        {
            if (Source == InSource)
            { return true; }
        }

        return false;
    }

    private bool Get_HasNonCutOutcome(FCk_Handle_FoodPiece InSource) const
    {
        for (int32 Index = 0; Index < _Cuts.Num(); ++Index)
        {
            if (_CutSources[Index] == InSource && _Cuts[Index].Outcome != EMars_FoodPiece_CutOutcome::Cut)
            { return true; }
        }

        return false;
    }

    UFUNCTION()
    private void OnPieceBCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        _ClearedFromCut = true;
        auto Board = _BoardB;
        Board.Request_Clear(FMars_Request_FoodBoard_Clear());
    }

    UFUNCTION()
    private void OnFillerResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        ++_FillersResolved;
    }
}
