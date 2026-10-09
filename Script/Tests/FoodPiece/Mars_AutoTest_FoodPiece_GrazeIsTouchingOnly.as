// A plane lying on the box's +X face only touches it: Missed with SliceOutcome TouchingOnly, and the source stays whole,
// Ready and not cutting.
class UMars_AutoTest_FoodPiece_GrazeIsTouchingOnly : UMars_AutoTestRig_FoodPiece
{
    private FCk_Handle_FoodPiece _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -40400.0)), Make_Spec(1.0));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("cut on the +X face", n"Step_CutOnFace");
        Add_Step_WaitUntil("the graze resolved", n"Check_Resolved");
        Add_Step("the graze touched only and the source is whole", n"Step_AssertGraze");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SourceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_CutOnFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Position = Get_BoundsCenter(_Source);
        Position.X = Get_Metrics(_Source).Get_BoundsMaxCm().X;
        Cut(_Source, Position, FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_Resolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertGraze(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 1, "one resolution");
        const auto Graze = _Cuts[0];
        Assert_True(Graze.Outcome == EMars_FoodPiece_CutOutcome::Missed, f"the outcome is Missed (got {Graze.Outcome :n})");
        Assert_True(Graze.SliceOutcome.IsSet() && Graze.SliceOutcome.GetValue() == ECk_RuntimeMesh_SliceOutcome::TouchingOnly, "the slice only touched the piece");

        Assert_True(ck::IsValid(_Source), "the source is alive");
        Assert_True(_Source.Get_Status() == EMars_FoodPiece_Status::Ready, "the source is Ready again");
        Assert_False(_Source.Get_IsCutting(), "the source is not cutting");
        Assert_Equals_Float(_Source.Get_VolumeCm3(), 1000.0, 0.01, "the source kept its volume");
    }
}
