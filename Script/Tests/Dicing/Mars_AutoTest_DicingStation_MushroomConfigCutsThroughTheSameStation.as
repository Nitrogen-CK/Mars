// The same station class with the mushroom-slice definition instead of the meat: its joint is the slice (53.6 cm3) at the
// definition's 32 g with the definition's portion tuners and cap. A chop 5.6 cm off centre, 0.37 cm inside the slice's tip,
// would leave a sliver under the 0.8 cm minimum: the cut is issued, RuntimeMesh rejects it and the slice stays whole, held and
// untouched. A chop at the centre then cuts it through the same station into two shown, gram-scale halves whose masses add
// back exactly and whose volumes add back within RuntimeMesh's tolerance.
class UMars_AutoTest_DicingStation_MushroomConfigCutsThroughTheSameStation : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(13600.0, -9000.0, -30000.0);
    private const float64 k_SliceVolumeCm3 = 53.58;
    private const float32 k_EdgeChopLateral = 5.6f;

    private FCk_Handle_FoodPiece _Slice;
    private float _SliceVolumeCm3 = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin, mars::CuttableFood_MushroomSlice_Mars);

        Add_Step_WaitUntil("the station composed its Dicing and FoodBoard", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the board holds one shown slice", n"Check_JointShown", 0, 10.0f);
        Add_Step("the slice has the mushroom's volume, mass, tuners and cap", n"Step_AssertSlice");
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step("move the hand near the slice's tip", n"Step_MoveToEdge");
        Add_Step_WaitUntil("the hand is near the tip", n"Check_HandAtEdge", 0, 2.0f);
        Add_Step("chop near the tip", n"Step_Chop");
        Add_Step_WaitUntil("the edge cut resolved and the cleaver is back up", n"Check_EdgeCutResolved", 0, 5.0f);
        Add_Step("the edge cut was issued and rejected; the slice is whole and untouched", n"Step_AssertRejected");
        Add_Step("move the hand to the centre", n"Step_MoveToCentre");
        Add_Step_WaitUntil("the hand is at the centre", n"Check_HandAtCentre", 0, 2.0f);
        Add_Step("chop at the centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", 0, 5.0f);
        Add_Step("two gram-scale halves conserve the slice", n"Step_AssertHalves");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertSlice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Slice = _Board.Get_Held()[0];
        _SliceVolumeCm3 = _Slice.Get_VolumeCm3();

        Assert_Equals_Float(_SliceVolumeCm3, k_SliceVolumeCm3, 0.05, "the slice has the mushroom slice's volume");
        Assert_Equals_Float(_Slice.Get_MassKg(), _Food.Data.MassKg, 0.000000001, "the slice has the definition's mass");
        Assert_True(_Slice.Get_MassKg() < 0.1, "the slice is gram-scale");
        Assert_Equals_Float(_Slice.Get_Tuners().MinPortionMassKg, _Food.Tuners.MinPortionMassKg, 0.000000001, "the slice carries the definition's portion mass");
        Assert_Equals_Float(_Slice.Get_Tuners().MinPortionThicknessCm, _Food.Tuners.MinPortionThicknessCm, 0.000000001, "the slice carries the definition's portion thickness");
        Assert_Equals_Int(_Slice.Get_Cap().Get_MaterialID(), _Food.Visuals.Cap.Get_MaterialID(), "the slice carries the definition's cap slot");
        Assert_True(_Slice.Get_Cap().Get_Color().Equals(_Food.Visuals.Cap.Get_Color(), 0.0001), "the slice carries the definition's cap colour");

        Watch(_Slice);
    }

    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Take();
    }

    UFUNCTION()
    private void Step_MoveToEdge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveHandTo(k_EdgeChopLateral);
    }

    UFUNCTION()
    private void Check_HandAtEdge(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Dicing.Get_HandLateral() - k_EdgeChopLateral) < 0.01f);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop();
    }

    // A chop that issued nothing settles at once so the assertions report it.
    UFUNCTION()
    private void Check_EdgeCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Knocked = _Issues.Num() > 0 && _Issues[0].Issued == 0;
        auto Res = OutResult;
        Res.Set(Knocked || (Get_OutcomeCountFor(_Slice) > 0 && _Dicing.Get_IsChopping() == false));
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Issues.Num() == 1 && _Issues[0].Issued == 1, "the chop near the tip issued the cut (the plane straddles the slice)");
        Assert_Equals_Int(Get_OutcomeCount(_Slice, EMars_FoodPiece_CutOutcome::Rejected), 1, "RuntimeMesh rejected the sliver");
        Assert_Equals_Int(_PieceCuts, 0, "nothing was cut");
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the slice is still the one piece held");
        Assert_True(_Board.Get_Held()[0] == _Slice, "the held piece is the whole slice");
        Assert_True(_Slice.Get_Status() == EMars_FoodPiece_Status::Ready, "the slice is Ready again");
        Assert_True(_Board.Get_IsUntouched(), "a refused cut leaves the board untouched");
    }

    UFUNCTION()
    private void Step_MoveToCentre(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveHandTo(0.0f);
    }

    UFUNCTION()
    private void Check_HandAtCentre(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Dicing.Get_HandLateral()) < 0.01f);
    }

    UFUNCTION()
    private void Check_TwoShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Knocked = _Issues.Num() > 1 && _Issues[1].Issued == 0;
        auto Res = OutResult;
        Res.Set(Knocked || Get_OutcomeCountFor(_Slice) > 1 || (_PieceCuts >= 1 && _Board.Get_HeldCount() == 2 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Step_AssertHalves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_OutcomeCount(_Slice, EMars_FoodPiece_CutOutcome::Cut), 1, "the centre chop cut the slice");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "two halves are held");

        for (const auto& Half : _Board.Get_Held())
        {
            Assert_True(Half.Get_MassKg() > 0.0 && Half.Get_MassKg() < _Food.Data.MassKg, f"[{Half.ToString()}] is gram-scale ({Half.Get_MassKg() * 1000.0 :.2} g)");
            Assert_True(Get_IsShown(Half), f"[{Half.ToString()}] is shown");
        }

        Assert_True(Math::Abs(Get_HeldMassKg() - _Food.Data.MassKg) <= 0.000000001, f"the halves' masses add back to the slice's exactly ({Get_HeldMassKg()} kg)");
        Assert_Equals_Float(Get_HeldVolumeCm3(), _SliceVolumeCm3, Math::Max(0.01, 0.0001 * _SliceVolumeCm3), "the halves' volumes add back to the slice's");
    }
}
