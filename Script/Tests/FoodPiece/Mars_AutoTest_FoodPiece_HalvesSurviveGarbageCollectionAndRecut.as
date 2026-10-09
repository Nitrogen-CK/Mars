// A box cut in two, then a forced garbage collection, then each half cut again across the first cut: three Cut
// resolutions, four Ready quarters of 250 cm3 whose masses sum to the box's, each naming its half as parent and all in the
// box's lineage.
class UMars_AutoTest_FoodPiece_HalvesSurviveGarbageCollectionAndRecut : UMars_AutoTestRig_FoodPiece
{
    private float _MassKg = 2.0;

    private FCk_Handle_FoodPiece _Source;
    private FGuid _Lineage;
    private FCk_Handle_FoodPiece _Positive;
    private FCk_Handle_FoodPiece _Negative;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -40800.0)), Make_Spec(_MassKg));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("cut the source through its centre", n"Step_FirstCut");
        Add_Step_WaitUntil("the halves are Ready", n"Check_HalvesReady");
        Add_Step("collect garbage", n"Step_CollectGarbage");
        Add_Step("cut each half across the first cut", n"Step_CutHalves");
        Add_Step_WaitUntil("both halves' cuts resolved and the quarters are Ready", n"Check_QuartersReady");
        Add_Step("four quarters conserve the box's mass", n"Step_AssertQuarters");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SourceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_FirstCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lineage = _Source.Get_Lineage();
        Cut(_Source, Get_BoundsCenter(_Source), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_HalvesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
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

        Res.Set(Get_HasReadied(_Cuts[0].Positive) && Get_HasReadied(_Cuts[0].Negative));
    }

    UFUNCTION()
    private void Step_CollectGarbage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the first cut succeeded (got {_Cuts[0].Outcome :n})");
        _Positive = _Cuts[0].Positive;
        _Negative = _Cuts[0].Negative;

        System::CollectGarbage();
    }

    UFUNCTION()
    private void Step_CutHalves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Positive) && ck::IsValid(_Negative), "both halves survived the collection");
        Assert_True(_Positive.Get_Status() == EMars_FoodPiece_Status::Ready && _Negative.Get_Status() == EMars_FoodPiece_Status::Ready, "both halves are still Ready");

        Cut(_Positive, Get_BoundsCenter(_Positive), FVector::RightVector);
        Cut(_Negative, Get_BoundsCenter(_Negative), FVector::RightVector);
    }

    UFUNCTION()
    private void Check_QuartersReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Cuts.Num() < 3)
        {
            Res.Set(false);
            return;
        }

        auto AllReady = true;
        for (int32 Index = 1; Index < _Cuts.Num(); ++Index)
        {
            if (_Cuts[Index].Outcome == EMars_FoodPiece_CutOutcome::Cut)
            { AllReady = AllReady && Get_HasReadied(_Cuts[Index].Positive) && Get_HasReadied(_Cuts[Index].Negative); }
        }

        Res.Set(AllReady);
    }

    UFUNCTION()
    private void Step_AssertQuarters(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 3, "three resolutions");
        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut), 3, "all three are Cut");

        auto MassSumKg = 0.0;
        for (int32 Index = 1; Index < _Cuts.Num(); ++Index)
        {
            const auto Result = _Cuts[Index];
            const auto Half = _CutSources[Index];
            Assert_True(Half == _Positive || Half == _Negative, f"cut {Index} was of a half");

            const auto Quarters = Get_Pair(Result);
            for (const auto& Quarter : Quarters)
            {
                Assert_Equals_Float(Quarter.Get_VolumeCm3(), 250.0, 0.01, f"a quarter of cut {Index} is 250 cm3");
                Assert_True(Quarter.Get_Lineage() == _Lineage, f"a quarter of cut {Index} is in the box's lineage");
                MassSumKg += Quarter.Get_MassKg();
            }
        }

        Assert_True(Math::Abs(MassSumKg - _MassKg) <= 0.000000001, f"the four quarters' masses sum to the box's (got {MassSumKg})");
        Assert_Equals_Int(Get_LineagePieces(_Lineage).Num(), 4, "four live pieces remain in the lineage");
    }

    private TArray<FCk_Handle_FoodPiece> Get_Pair(const FMars_FoodPiece_CutResult& InResult) const
    {
        TArray<FCk_Handle_FoodPiece> Pair;
        Pair.Add(InResult.Positive);
        Pair.Add(InResult.Negative);
        return Pair;
    }
}
