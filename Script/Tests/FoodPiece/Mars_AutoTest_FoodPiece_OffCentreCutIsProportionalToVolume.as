// A cut a fifth of the way along the box splits it 200 / 800 cm3, and the mass follows the volume: 0.2 M and 0.8 M, the
// two summing to M.
class UMars_AutoTest_FoodPiece_OffCentreCutIsProportionalToVolume : UMars_AutoTestRig_FoodPiece
{
    private float _MassKg = 3.0;

    private FCk_Handle_FoodPiece _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -40200.0)), Make_Spec(_MassKg));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("cut the source a fifth of the way along X", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved", n"Check_CutResolved");
        Add_Step("the halves' masses follow their volumes", n"Step_AssertSplit");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SourceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Metrics = Get_Metrics(_Source);
        auto Position = Get_BoundsCenter(_Source);
        Position.X = Metrics.Get_BoundsMinCm().X + 0.2 * (Metrics.Get_BoundsMaxCm().X - Metrics.Get_BoundsMinCm().X);
        Cut(_Source, Position, FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_CutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertSplit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the outcome is Cut (got {Result.Outcome :n})");
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        const auto Positive = Result.Positive;
        const auto Negative = Result.Negative;
        Assert_Equals_Float(Negative.Get_VolumeCm3(), 200.0, 0.01, "the negative half is 200 cm3");
        Assert_Equals_Float(Positive.Get_VolumeCm3(), 800.0, 0.01, "the positive half is 800 cm3");
        Assert_Equals_Float(Negative.Get_MassKg(), _MassKg * 0.2, 0.00001, "the negative half has 0.2 of the mass");
        Assert_Equals_Float(Positive.Get_MassKg(), _MassKg * 0.8, 0.00001, "the positive half has 0.8 of the mass");

        const auto VolumeShare = Negative.Get_VolumeCm3() / (Negative.Get_VolumeCm3() + Positive.Get_VolumeCm3());
        Assert_Equals_Float(Negative.Get_MassKg() / _MassKg, VolumeShare, 0.000000001, "the smaller half's mass share is its volume share");
        Assert_True(Math::Abs(Positive.Get_MassKg() + Negative.Get_MassKg() - _MassKg) <= 0.000000001, "the halves' masses sum to the whole");
    }
}
