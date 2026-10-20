// A cook state sent while the piece is Cutting reaches both halves. The slice can resolve before that write drains, and the
// source dies at the commit, so the commit takes the last write still queued on it. Dropping that take (the halves copying
// only the ledger) fails this whenever the slice commits first.
class UMars_AutoTest_FoodPiece_ACookStateSentMidCutReachesTheHalves : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(12800.0, -13800.0, -30000.0);
    private const float32 k_OilCoat = 0.75f;

    private FCk_Handle_FoodPiece _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, k_Origin), Make_Spec(1.0));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("cut the source through its middle", n"Step_Cut");
        Add_Step_WaitUntil("the source is Cutting", n"Check_Cutting");
        Add_Step("set the cook state while the slice is in flight", n"Step_SetCookState");
        Add_Step_WaitUntil("the cut resolved and both halves are Ready", n"Check_CutSettled");
        Add_Step("both halves carry the cook state sent mid-cut", n"Step_AssertHalves");
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
        Cut(_Source, Get_BoundsCenter(_Source), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_Cutting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Source) && _Source.Get_IsCutting());
    }

    UFUNCTION()
    private void Step_SetCookState(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto CookState = FMars_FoodPiece_CookState();
        CookState.OilCoat = k_OilCoat;
        _Source.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
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
        Assert_Equals_Int(_Cuts.Num(), 1, "exactly one OnCutResolved");

        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the source reported Cut (got {Result.Outcome :n})");
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        Assert_Equals_Float(Result.Positive.Get_CookState().OilCoat, k_OilCoat, 0.0001, "the positive half carries the write sent mid-cut");
        Assert_Equals_Float(Result.Negative.Get_CookState().OilCoat, k_OilCoat, 0.0001, "the negative half carries the write sent mid-cut");
    }
}
