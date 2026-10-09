// The real meat slab imports Ready (about 6927 cm3, 636 triangles) and a cut across its long X axis at its centroid
// succeeds: the halves' volumes add back to the slab's within RuntimeMesh's own tolerance, and their masses add back to
// the slab's exactly and follow their volumes.
class UMars_AutoTest_FoodPiece_MeatSlabCutsIntoConservedPortions : UMars_AutoTestRig_FoodPiece
{
    private float _MassKg = 1.2;

    private FCk_Handle_FoodPiece _Slab;
    private float _SlabVolumeCm3 = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Slab = Build_Piece(assets::MeatSlab_Mars_SM(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -40900.0)), Make_Spec(_MassKg));

        Add_Step_WaitUntil("the slab is Ready", n"Check_SlabReady");
        Add_Step("cut the slab across X at its centroid", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved", n"Check_CutResolved");
        Add_Step("the portions conserve volume and mass", n"Step_AssertPortions");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Slab) || _Failures.Num() > 0);
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Failures.Num(), 0, "the slab imported");
        Assert_True(_Slab.Get_Status() == EMars_FoodPiece_Status::Ready, "the slab is Ready");

        const auto Metrics = Get_Metrics(_Slab);
        _SlabVolumeCm3 = _Slab.Get_VolumeCm3();
        Assert_Equals_Float(_SlabVolumeCm3, 6927.34, 0.5, "the slab's volume");
        Assert_Equals_Int(Metrics.Get_TriangleCount(), 636, "the slab's triangle count");

        Cut(_Slab, Metrics.Get_CentroidCm(), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_CutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertPortions(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the slab was cut (got {Result.Outcome :n})");
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        const auto PositiveCm3 = Result.Positive.Get_VolumeCm3();
        const auto NegativeCm3 = Result.Negative.Get_VolumeCm3();
        ck::Trace(f"[FoodPiece test] slab {_SlabVolumeCm3} cm3 cut into {PositiveCm3} + {NegativeCm3} cm3, {Result.Positive.Get_MassKg()} + {Result.Negative.Get_MassKg()} kg");

        Assert_True(PositiveCm3 > 0.0 && NegativeCm3 > 0.0, "both portions have volume");
        Assert_Equals_Float(PositiveCm3 + NegativeCm3, _SlabVolumeCm3, Math::Max(0.01, 0.0001 * _SlabVolumeCm3), "the portions' volumes add back to the slab's");
        Assert_True(Math::Abs(Result.Positive.Get_MassKg() + Result.Negative.Get_MassKg() - _MassKg) <= 0.000000001, "the portions' masses add back to the slab's");
        Assert_Equals_Float(Result.Positive.Get_MassKg() / _MassKg, PositiveCm3 / (PositiveCm3 + NegativeCm3), 0.000000001, "the mass share follows the volume share");
    }
}
