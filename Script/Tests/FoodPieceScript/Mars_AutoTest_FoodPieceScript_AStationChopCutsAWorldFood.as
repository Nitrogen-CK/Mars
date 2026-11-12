// The real cutting station chops a whole food that replicates: the input platter's meat slab is a funnel world item, so
// its cut commits once both piece scripts have composed, frames after the slice resolved. The feed lays the joint on the
// board; a chop at the board's centre leaves two held pieces, both Ready with a replication driver and a display, of the
// joint's lineage with the joint as parent; the joint is gone; the board parts them (their centroids end farther apart
// than they were at the cut). With the hand at 8 cm a second chop cuts the positive half again: three held pieces, two of
// them the positive half's. Isolated origin (-152000, 30000, -30000).
class UMars_AutoTest_FoodPieceScript_AStationChopCutsAWorldFood : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(-152000.0, 30000.0, -30000.0);
    private const float32 k_SecondChopLateral = 8.0f;

    private FCk_Handle_FoodPiece _Joint;
    private FGuid _JointId;
    private FGuid _JointLineage;
    private FGuid _PositiveHalfId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());

        Add_Steps_FeedTheJoint();
        Add_Step("the joint on the board is a world food that replicates", n"Step_AssertJoint");
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", k_SlowPolls, 0);
        Add_Step_WaitFrames("the board has parted the halves", 5);
        Add_Step("two replicated halves of the joint, parted", n"Step_AssertTwo");
        Add_Step_WaitUntil("the cleaver is back up", n"Check_ChopDone", 0, 0);
        Add_Step("move the hand along the board", n"Step_MoveHand");
        Add_Step_WaitUntil("the hand reached the second chop", n"Check_HandAtSecondChop", 0, 0);
        Add_Step("chop again", n"Step_Chop");
        Add_Step_WaitUntil("the second cut committed and every piece is shown", n"Check_ThreeShown", k_SlowPolls, 0);
        Add_Step("the positive half was cut again", n"Step_AssertThree");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertJoint(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the board holds the joint");
        _Joint = _Board.Get_Held()[0];
        _JointId = _Joint.Get_Id();
        _JointLineage = _Joint.Get_Lineage();
        FCk_Handle Entity = _Joint;
        Assert_True(utils_entity_replication_driver::Has(Entity), "the joint has a replication driver");
        Assert_True(utils_foodpiece::Get_CutsIntoReplicatedPieces(_Joint), "the joint cuts into replicated pieces");
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _Board.Get_Held())
        { Watch(Piece); }

        Chop();
    }

    // The chop issued nothing, or a watched cut resolved other than Cut.
    private bool Get_HasSettledBadly() const
    {
        for (const auto& Issue : _Issues)
        {
            if (Issue.Issued == 0)
            { return true; }
        }

        for (const auto Outcome : _CutOutcomes)
        {
            if (Outcome != EMars_FoodPiece_CutOutcome::Cut)
            { return true; }
        }

        return false;
    }

    UFUNCTION()
    private void Check_TwoShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasSettledBadly() || (_PieceCuts >= 1 && _Board.Get_HeldCount() == 2 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Step_AssertTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_OutcomeCount(_Joint, EMars_FoodPiece_CutOutcome::Cut), 1, "the joint's cut resolved Cut");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "two halves are held");
        Assert_True(ck::Is_NOT_Valid(_Joint), "the joint is gone");
        if (_Board.Get_HeldCount() != 2)
        { return; }

        const auto Held = _Board.Get_Held();
        for (const auto& Half : Held)
        {
            FCk_Handle Entity = Half;
            Assert_True(Half.Get_Status() == EMars_FoodPiece_Status::Ready, f"[{Half.ToString()}] is Ready");
            Assert_True(utils_entity_replication_driver::Has(Entity), f"[{Half.ToString()}] has a replication driver");
            Assert_True(Get_IsShown(Half), f"[{Half.ToString()}] wears a display");
            Assert_True(Half.Get_Lineage() == _JointLineage, f"[{Half.ToString()}] keeps the joint's lineage");
            Assert_True(Half.Get_ParentId() == _JointId, f"[{Half.ToString()}] was cut from the joint");
        }

        // At the cut both halves stood at the joint's pose: their centroids were as far apart as their local centroids.
        const auto AtCutCm = (utils_runtime_mesh::Get_Metrics(Held[0].Get_Geometry()).Get_CentroidCm()
            - utils_runtime_mesh::Get_Metrics(Held[1].Get_Geometry()).Get_CentroidCm()).Size();
        const auto NowCm = (Get_WorldCentroid(Held[0]) - Get_WorldCentroid(Held[1])).Size();
        Assert_True(NowCm > AtCutCm + 0.5, f"the board parted the halves ({NowCm} cm apart now, {AtCutCm} cm at the cut)");

        _PositiveHalfId = Held[0].Get_Id();
    }

    UFUNCTION()
    private void Step_MoveHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveHandTo(k_SecondChopLateral);
    }

    UFUNCTION()
    private void Check_HandAtSecondChop(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Cutting.Get_HandLateral() - k_SecondChopLateral) < 0.01f);
    }

    UFUNCTION()
    private void Check_ThreeShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasSettledBadly() || (_PieceCuts >= 2 && _Board.Get_HeldCount() == 3 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Step_AssertThree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PieceCuts, 2, "two committed cuts");
        Assert_Equals_Int(_Board.Get_HeldCount(), 3, "three pieces are held");

        auto FromPositiveHalf = 0;
        auto Replicated = 0;
        for (const auto& Piece : _Board.Get_Held())
        {
            FCk_Handle Entity = Piece;
            FromPositiveHalf += Piece.Get_ParentId() == _PositiveHalfId ? 1 : 0;
            Replicated += utils_entity_replication_driver::Has(Entity) ? 1 : 0;
        }

        Assert_Equals_Int(FromPositiveHalf, 2, "the second chop cut the positive half");
        Assert_Equals_Int(Replicated, 3, "every held piece replicates");
    }
}
