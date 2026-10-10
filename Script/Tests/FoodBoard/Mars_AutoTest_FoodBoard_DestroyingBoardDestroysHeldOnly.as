// A board's held pieces end with it; a piece it handed off does not. Board A hands one box off and holds two; destroying the
// board destroys the two held and leaves the handed-off one. Board B is destroyed from inside its piece's OnCutResolved(Cut),
// after the cut's ResolveCut is queued but before the board drains it: the halves that cut made are destroyed with the board
// too, and no piece of that lineage survives.
class UMars_AutoTest_FoodBoard_DestroyingBoardDestroysHeldOnly : UMars_AutoTestRig_FoodBoard
{
    private FCk_Handle_FoodBoard _BoardA;
    private FCk_Handle_FoodPiece _HandedOff;
    private FCk_Handle_FoodPiece _HeldFirst;
    private FCk_Handle_FoodPiece _HeldSecond;

    private FCk_Handle_FoodBoard _BoardB;
    private FCk_Handle_FoodPiece _PieceB;
    private FGuid _LineageB;
    private bool _DestroyedFromCut = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _BoardA = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(6800.0, 3000.0, -42000.0)), Make_Tuners());
        _HandedOff = Build_BoxOn(_BoardA, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 0.0)), 0.5);
        _HeldFirst = Build_BoxOn(_BoardA, FTransform(FRotator::ZeroRotator, FVector(15.0, 0.0, 0.0)), 0.5);
        _HeldSecond = Build_BoxOn(_BoardA, FTransform(FRotator::ZeroRotator, FVector(30.0, 0.0, 0.0)), 0.5);
        Place(_BoardA, _HandedOff);

        _BoardB = Build_Board(InHandle, FTransform(FRotator(0.0, 160.0, 0.0), FVector(6800.0, 3400.0, -42000.0)), Make_Tuners());
        _PieceB = Build_BoxOn(_BoardB, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 0.0)), 1.0);
        Place(_BoardB, _PieceB);

        Add_Step_WaitUntil("the first boxes are Ready and placed", n"Check_FirstPlaced");
        Add_Step("hand board A's box off", n"Step_Release");
        Add_Step_WaitUntil("the box is handed off", n"Check_Released");
        Add_Step("place two more on board A", n"Step_PlaceTwo");
        Add_Step_WaitUntil("board A holds two", n"Check_TwoHeld");
        Add_Step("destroy board A", n"Step_DestroyA");
        Add_Step_WaitUntil("board A's held pieces are destroyed", n"Check_HeldDestroyed");
        Add_Step("chop board B, destroying it from inside its piece's cut", n"Step_ChopB");
        Add_Step_WaitUntil("board B's piece was cut as the board went away", n"Check_DestroyedFromCut");
        Add_Step_WaitSeconds("a surviving half or a late destroy would show in this window", 0.3f);
        Add_Step("held pieces and uncommitted halves ended with their boards; the handed-off piece lives", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_FirstPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_BoardA) == 1 && Get_PlacedCount(_BoardB) == 1 && Get_HasReadied(_HandedOff) && Get_HasReadied(_PieceB));
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Board = _BoardA;
        Board.Request_Release(FMars_Request_FoodBoard_Release());
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_BoardA).Num() >= 1);
    }

    UFUNCTION()
    private void Step_PlaceTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Place(_BoardA, _HeldFirst);
        Place(_BoardA, _HeldSecond);
    }

    UFUNCTION()
    private void Check_TwoHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_BoardA) >= 3);
    }

    UFUNCTION()
    private void Step_DestroyA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_BoardA.Get_HeldCount(), 2, "board A holds two pieces");
        Assert_True(Get_ReleasedEvents(_BoardA).Num() == 1 && Get_ReleasedEvents(_BoardA)[0] == _HandedOff, "board A handed one piece off");
        utils_entity_lifetime::Request_DestroyEntity(_BoardA);
    }

    UFUNCTION()
    private void Check_HeldDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_HeldFirst) && ck::Is_NOT_Valid(_HeldSecond));
    }

    UFUNCTION()
    private void Step_ChopB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LineageB = _PieceB.Get_Lineage();

        // Bound after the board's own handler, so the cut's ResolveCut is already queued when the board is destroyed.
        auto Piece = _PieceB;
        Piece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnPieceBCutResolved"));
        Chop(_BoardB, Make_WorldPlane(Get_WorldBoundsCenter(_PieceB), Get_BoardWorld(_BoardB).TransformVectorNoScale(FVector::ForwardVector)));
    }

    // A chop that issued nothing, or another outcome than Cut, settles at once so the assertions report it.
    UFUNCTION()
    private void Check_DestroyedFromCut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Issues = Get_Issues(_BoardB);
        Res.Set(_DestroyedFromCut || _Cuts.Num() > 0 || (Issues.Num() > 0 && Issues[0].Issued == 0));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::Is_NOT_Valid(_BoardA), "board A is destroyed");
        Assert_True(ck::Is_NOT_Valid(_HeldFirst) && ck::Is_NOT_Valid(_HeldSecond), "board A's held pieces were destroyed with it");
        Assert_True(ck::IsValid(_HandedOff) && utils_entity_lifetime::Get_IsPendingDestroy(_HandedOff, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false,
            "board A's handed-off piece lives on");

        Assert_True(_DestroyedFromCut, "board B's piece was cut and the board destroyed from inside the cut");
        Assert_True(ck::Is_NOT_Valid(_BoardB), "board B is destroyed");
        if (_Cuts.Num() > 0)
        {
            Assert_True(ck::Is_NOT_Valid(_Cuts[0].Positive) && ck::Is_NOT_Valid(_Cuts[0].Negative), "the uncommitted halves were destroyed with board B");
        }

        Assert_Equals_Int(Get_PieceCuts(_BoardB).Num(), 0, "board B never committed the cut");
        Assert_Equals_Int(Get_LineagePieces(_LineageB).Num(), 0, "no piece of board B's lineage survives");
    }

    UFUNCTION()
    private void OnPieceBCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        _DestroyedFromCut = true;
        utils_entity_lifetime::Request_DestroyEntity(_BoardB);
    }
}
