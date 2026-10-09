// A centre cut of a placed, rotated box: exactly one OnCutResolved (Cut) with two Ready halves of 500 cm3 and half the mass
// each, summing to the whole; new distinct Ids, the source as parent, the source's lineage and world transform; and the
// source destroyed.
class UMars_AutoTest_FoodPiece_CentreCutConservesMassAndLineage : UMars_AutoTestRig_FoodPiece
{
    private float _MassKg = 1.75;

    private FCk_Handle_FoodPiece _Source;
    private FGuid _SourceId;
    private FGuid _SourceLineage;
    private FTransform _SourceWorld;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _SourceWorld = FTransform(FRotator(0.0, 30.0, 0.0), FVector(120.0, -80.0, -40100.0));
        _Source = Build_Piece(Get_BoxMesh(), _SourceWorld, Make_Spec(_MassKg));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("cut the source through its centre", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved, both halves are Ready and the source is gone", n"Check_CutSettled");
        Add_Step_WaitSeconds("a second resolution would arrive in this window", 0.2f);
        Add_Step("the halves conserve mass, volume, lineage and pose", n"Step_AssertHalves");
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
        _SourceId = _Source.Get_Id();
        _SourceLineage = _Source.Get_Lineage();
        Cut(_Source, Get_BoundsCenter(_Source), FVector::ForwardVector);
    }

    // A non-Cut outcome settles at once so the assertions report it.
    UFUNCTION()
    private void Check_CutSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Cuts.Num() == 0)
        {
            Res.Set(false);
            return;
        }

        if (_Cuts[0].Outcome != EMars_FoodPiece_CutOutcome::Cut)
        {
            Res.Set(true);
            return;
        }

        Res.Set(Get_HasReadied(_Cuts[0].Positive) && Get_HasReadied(_Cuts[0].Negative) && ck::Is_NOT_Valid(_Source));
    }

    UFUNCTION()
    private void Step_AssertHalves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 1, "exactly one OnCutResolved");
        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the outcome is Cut (got {Result.Outcome :n})");
        Assert_True(Result.SliceOutcome.IsSet() && Result.SliceOutcome.GetValue() == ECk_RuntimeMesh_SliceOutcome::Succeeded, "the slice succeeded");
        Assert_True(_CutSources[0] == _Source, "the broadcast names the source");
        Assert_True(ck::Is_NOT_Valid(_Source), "the source is destroyed");

        const auto Positive = Result.Positive;
        const auto Negative = Result.Negative;
        Assert_True(ck::IsValid(Positive) && ck::IsValid(Negative), "both halves are live");
        Assert_True(Positive.Get_Status() == EMars_FoodPiece_Status::Ready && Negative.Get_Status() == EMars_FoodPiece_Status::Ready, "both halves are Ready");

        Assert_Equals_Float(Positive.Get_VolumeCm3(), 500.0, 0.01, "the positive half is 500 cm3");
        Assert_Equals_Float(Negative.Get_VolumeCm3(), 500.0, 0.01, "the negative half is 500 cm3");
        Assert_Equals_Float(Positive.Get_MassKg(), _MassKg * 0.5, 0.000001, "the positive half has half the mass");
        Assert_Equals_Float(Negative.Get_MassKg(), _MassKg * 0.5, 0.000001, "the negative half has half the mass");
        Assert_True(Math::Abs(Positive.Get_MassKg() + Negative.Get_MassKg() - _MassKg) <= 0.000000001, "the halves' masses sum to the whole");

        Assert_True(Positive.Get_Id().IsValid() && Negative.Get_Id().IsValid(), "both halves have an Id");
        Assert_True(Positive.Get_Id() != Negative.Get_Id(), "the halves' Ids differ");
        Assert_True(Positive.Get_Id() != _SourceId && Negative.Get_Id() != _SourceId, "neither half reuses the source's Id");
        Assert_True(Positive.Get_ParentId() == _SourceId && Negative.Get_ParentId() == _SourceId, "both halves name the source as parent");
        Assert_True(Positive.Get_Lineage() == _SourceLineage && Negative.Get_Lineage() == _SourceLineage, "both halves keep the source's lineage");

        Assert_True(Get_World(Positive).Equals(_SourceWorld, 0.0001), "the positive half has the source's world transform");
        Assert_True(Get_World(Negative).Equals(_SourceWorld, 0.0001), "the negative half has the source's world transform");
    }
}
