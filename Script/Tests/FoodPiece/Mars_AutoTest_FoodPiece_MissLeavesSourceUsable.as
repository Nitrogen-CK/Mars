// A plane clear of the box resolves Missed (NoIntersection) and leaves the source whole, Ready and not cutting with the
// same identity and volume; a real cut of the same source afterwards still succeeds.
class UMars_AutoTest_FoodPiece_MissLeavesSourceUsable : UMars_AutoTestRig_FoodPiece
{
    private FCk_Handle_FoodPiece _Source;
    private FGuid _SourceId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -40300.0)), Make_Spec(1.0));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("cut 5 cm past the box", n"Step_CutPast");
        Add_Step_WaitUntil("the miss resolved", n"Check_OneResolved");
        Add_Step("the source is whole and usable; cut it through its centre", n"Step_AssertWholeAndCut");
        Add_Step_WaitUntil("the second cut resolved", n"Check_TwoResolved");
        Add_Step("the second cut succeeded", n"Step_AssertCut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SourceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_CutPast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SourceId = _Source.Get_Id();
        auto Position = Get_BoundsCenter(_Source);
        Position.X = Get_Metrics(_Source).Get_BoundsMaxCm().X + 5.0;
        Cut(_Source, Position, FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_OneResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertWholeAndCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Miss = _Cuts[0];
        Assert_True(Miss.Outcome == EMars_FoodPiece_CutOutcome::Missed, f"the outcome is Missed (got {Miss.Outcome :n})");
        Assert_True(Miss.SliceOutcome.IsSet() && Miss.SliceOutcome.GetValue() == ECk_RuntimeMesh_SliceOutcome::NoIntersection, "the slice found no intersection");
        Assert_False(ck::IsValid(Miss.Positive) || ck::IsValid(Miss.Negative), "a miss has no halves");

        Assert_True(ck::IsValid(_Source), "the source is alive");
        Assert_True(_Source.Get_Status() == EMars_FoodPiece_Status::Ready, "the source is Ready again");
        Assert_False(_Source.Get_IsCutting(), "the source is not cutting");
        Assert_True(_Source.Get_Id() == _SourceId, "the source kept its Id");
        Assert_Equals_Float(_Source.Get_VolumeCm3(), 1000.0, 0.01, "the source kept its volume");

        Cut(_Source, Get_BoundsCenter(_Source), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_TwoResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 2, "two resolutions");
        Assert_True(_Cuts[1].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the second cut succeeded (got {_Cuts[1].Outcome :n})");
        Assert_True(ck::IsValid(_Cuts[1].Positive) && ck::IsValid(_Cuts[1].Negative), "the second cut produced two halves");
    }
}
