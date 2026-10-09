// The real dicing station, fed the meat on a docked input platter. Once an operator takes it, the intake has laid one whole,
// untouched, shown joint of the definition's mass and the slab's volume on the board, at the pile point, yawed 90, unscaled.
// A chop at the board's centre goes through the station's cut bridge: two shown halves of the joint's lineage replace it,
// parted 1.5 cm along the blade's normal (positive half on its side), conserving its mass exactly and its volume within
// RuntimeMesh's tolerance (a closed, Ready half is a capped one). With the hand at 8 cm a second chop cuts the positive half
// only: three pieces, mass still exact. When the operator leaves, Idle clears nothing: the three pieces stay on the board.
class UMars_AutoTest_DicingStation_ChopsCutTheJoint : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(12000.0, -9000.0, -30000.0);
    private const float32 k_SecondChopLateral = 8.0f;
    // The board's top in the station frame: the counter and the 4 cm board.
    private const float64 k_BoardTopCm = constants_station::k_CounterHeight + 4.0;
    private const float64 k_SlabVolumeCm3 = 6927.34;
    private const float64 k_SeparationCm = 1.5;

    private FCk_Handle_FoodPiece _Joint;
    private FGuid _JointId;
    private FGuid _FirstLineage;
    private float _JointVolumeCm3 = 0.0;
    private FGuid _PositiveHalfId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars::Food_MeatSlab_Mars);

        Add_Steps_IntakeTheJoint();
        Add_Step("the joint is whole and untouched, of the meat's mass and volume, at the pile point", n"Step_AssertJoint");
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", 0, 5.0f);
        Add_Step("two halves conserve the joint and part along the blade", n"Step_AssertTwo");
        Add_Step_WaitUntil("the cleaver is back up", n"Check_ChopDone", 0, 2.0f);
        Add_Step("move the hand along the board", n"Step_MoveHand");
        Add_Step_WaitUntil("the hand reached the second chop", n"Check_HandAtSecondChop", 0, 2.0f);
        Add_Step("chop again", n"Step_Chop");
        Add_Step_WaitUntil("the second cut committed and every piece is shown", n"Check_ThreeShown", 0, 5.0f);
        Add_Step("three pieces conserve the joint; only the positive half was cut", n"Step_AssertThree");
        Add_Step("the operator leaves", n"Step_Leave");
        Add_Step_WaitUntil("the station's state machine is Idle", n"Check_Idle", 0, 2.0f);
        Add_Step_WaitFrames("a clear would have drained by now", 2);
        Add_Step("the three pieces stay on the board", n"Step_AssertKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertJoint(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _Board.Get_Held()[0];
        _JointId = _Joint.Get_Id();
        _FirstLineage = _Joint.Get_Lineage();
        _JointVolumeCm3 = _Joint.Get_VolumeCm3();

        Assert_True(_Board.Get_IsUntouched(), "the board is untouched");
        Assert_False(_Joint.Get_ParentId().IsValid(), "the joint is a root");
        Assert_Equals_Float(_Joint.Get_MassKg(), _Food.Data.MassKg, 0.000000001, "the joint has the definition's mass");
        Assert_Equals_Float(_JointVolumeCm3, k_SlabVolumeCm3, 0.5, "the joint has the slab's volume");
        Assert_Equals_Float(_Joint.Get_Tuners().MinPortionMassKg, _Food.Tuners.MinPortionMassKg, 0.000000001, "the joint carries the definition's portion mass");
        Assert_Equals_Float(_Joint.Get_Tuners().MinPortionThicknessCm, _Food.Tuners.MinPortionThicknessCm, 0.000000001, "the joint carries the definition's portion thickness");
        Assert_Equals_Int(_Joint.Get_Cap().Get_MaterialID(), _Food.Visuals.Cap.Get_MaterialID(), "the joint carries the definition's cap slot");

        const auto StationWorld = Get_StationWorld();
        const auto JointWorld = Get_World(_Joint);
        const auto PilePoint = StationWorld.TransformPosition(FVector(0.0, 0.0, k_BoardTopCm));
        Assert_True(JointWorld.GetLocation().Equals(PilePoint, 0.01), f"the joint sits at the pile point ({JointWorld.GetLocation()} vs {PilePoint})");
        Assert_True(JointWorld.GetScale3D().Equals(FVector::OneVector, 0.0001), f"the joint is unscaled ({JointWorld.GetScale3D()})");

        // Yawed 90: the slab's long axis (+X) runs along the cleaver's travel (the station's +Y).
        const auto LongAxis = JointWorld.TransformVectorNoScale(FVector::ForwardVector);
        const auto Travel = StationWorld.TransformVectorNoScale(FVector::RightVector);
        Assert_True(LongAxis.Equals(Travel, 0.0001), f"the joint's long axis runs along the cleaver's travel ({LongAxis} vs {Travel})");
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _Board.Get_Held())
        { Watch(Piece); }

        Chop();
    }

    // A chop that issued nothing, or a cut that did not commit, settles at once so the assertions report it.
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
        Assert_Equals_Int(_PieceCuts, 1, "one committed cut");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "two halves are held");
        if (_Board.Get_HeldCount() != 2)
        { return; }

        Assert_False(_Board.Get_IsUntouched(), "a cut touches the board");

        const auto Held = _Board.Get_Held();
        for (const auto& Half : Held)
        {
            Assert_True(Half.Get_Lineage() == _FirstLineage, f"[{Half.ToString()}] keeps the joint's lineage");
            Assert_True(Half.Get_ParentId() == _JointId, f"[{Half.ToString()}] was cut from the joint");
            Assert_True(Get_IsShown(Half), f"[{Half.ToString()}] is shown");
        }

        Assert_True(Math::Abs(Get_HeldMassKg() - _Food.Data.MassKg) <= 0.000000001, f"the halves' masses add back to the joint's exactly ({Get_HeldMassKg()} kg)");
        Assert_Equals_Float(Get_HeldVolumeCm3(), _JointVolumeCm3, Math::Max(0.01, 0.0001 * _JointVolumeCm3), "the halves' volumes add back to the joint's");

        // Positive first: the blade's normal (the station's +Y) points at it.
        const auto Normal = Get_StationWorld().TransformVectorNoScale(FVector::RightVector);
        const auto Parting = (Get_World(Held[0]).GetLocation() - Get_World(Held[1]).GetLocation()).DotProduct(Normal);
        Assert_Equals_Float(Parting, k_SeparationCm, 0.01, "the halves part 1.5 cm along the blade's normal, the positive half on its side");

        // The plane the control captured at contact separates the halves' centroids.
        const auto Blade = utils_dicing::Get_BladePlane(Get_StationWorld(), 0.0f);
        Assert_True((Get_WorldCentroid(Held[0]) - Blade.PositionCm).DotProduct(Blade.Normal) > 0.0, "the positive half lies on the blade plane's normal side");
        Assert_True((Get_WorldCentroid(Held[1]) - Blade.PositionCm).DotProduct(Blade.Normal) < 0.0, "the negative half lies behind the blade plane");

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
        Res.Set(Math::Abs(_Dicing.Get_HandLateral() - k_SecondChopLateral) < 0.01f);
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
        auto FromJoint = 0;
        for (const auto& Piece : _Board.Get_Held())
        {
            if (Piece.Get_ParentId() == _PositiveHalfId)
            { ++FromPositiveHalf; }
            else if (Piece.Get_ParentId() == _JointId)
            { ++FromJoint; }
        }

        Assert_Equals_Int(FromPositiveHalf, 2, "the chop at 8 cm cut the positive half");
        Assert_Equals_Int(FromJoint, 1, "the negative half is untouched");
        Assert_True(Math::Abs(Get_HeldMassKg() - _Food.Data.MassKg) <= 0.000000001, f"the pieces' masses add back to the joint's exactly ({Get_HeldMassKg()} kg)");
        Assert_Equals_Float(Get_HeldVolumeCm3(), _JointVolumeCm3, Math::Max(0.01, 0.0002 * _JointVolumeCm3), "the pieces' volumes add back to the joint's");
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cleared, 0, "nothing cleared the board");
        Assert_Equals_Int(_Board.Get_HeldCount(), 3, "the three pieces are still held");
        Assert_False(_Board.Get_IsUntouched(), "the board is still touched");
        Assert_Equals_Int(Get_LineageCount(_FirstLineage), 3, "the three pieces are the joint's");
        Assert_True(Get_AllHeldShown(), "every piece is still shown");
    }

    // The chop issued nothing, or the watched cut resolved other than Cut.
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
}
