// A root that names the meat's definition and kind is whole and carries both. A centre cut hands both to each half, which
// names the source as its parent and is no longer whole.
class UMars_AutoTest_FoodPiece_KindAndDefinitionFollowTheCut : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(12800.0, -12000.0, -30000.0);

    private FCk_Handle_FoodPiece _Source;
    private FGuid _SourceId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_Spec(1.0);
        Spec.Data.Definition = TWeakObjectPtr<UMars_Food_Def>(mars::Food_MeatSlab_Mars);
        Spec.Data.Kind.AddTag(GameplayTags::Food_Meat_Beef);
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, k_Origin), Spec);

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("the source is whole and carries the meat's definition and kind", n"Step_AssertSource");
        Add_Step("cut the source through its centre", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved and both halves are Ready", n"Check_CutSettled");
        Add_Step("both halves carry the source's definition and kind and are not whole", n"Step_AssertHalves");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SourceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_AssertSource(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Source.Get_IsWhole(), "a root is whole");
        Assert_True(_Source.Get_Kind().HasTag(GameplayTags::Food_Meat_Beef), "the root is beef");
        Assert_True(_Source.Get_Definition().Get() == mars::Food_MeatSlab_Mars, "the root names the meat's definition");
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SourceId = _Source.Get_Id();
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

        Res.Set(Get_HasReadied(_Cuts[0].Positive) && Get_HasReadied(_Cuts[0].Negative));
    }

    UFUNCTION()
    private void Step_AssertHalves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the outcome is Cut (got {Result.Outcome :n})");
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        Assert_Half(Result.Positive, "the positive half");
        Assert_Half(Result.Negative, "the negative half");
    }

    private void Assert_Half(const FCk_Handle_FoodPiece& InHalf, const FString& InName)
    {
        Assert_True(ck::IsValid(InHalf), f"{InName} is live");
        if (ck::Is_NOT_Valid(InHalf))
        { return; }

        Assert_False(InHalf.Get_IsWhole(), f"{InName} is not whole");
        Assert_True(InHalf.Get_ParentId() == _SourceId, f"{InName} names the source as parent");
        Assert_True(InHalf.Get_Kind().HasTag(GameplayTags::Food_Meat_Beef), f"{InName} is beef");
        Assert_True(InHalf.Get_Definition().Get() == mars::Food_MeatSlab_Mars, f"{InName} names the meat's definition");
    }
}
