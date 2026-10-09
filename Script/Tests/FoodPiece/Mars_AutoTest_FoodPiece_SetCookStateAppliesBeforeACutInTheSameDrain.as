// A cook state set and a cut issued in one step land in one drain: the cook state applies first, so the cut is not refused
// and both halves carry the new state.
class UMars_AutoTest_FoodPiece_SetCookStateAppliesBeforeACutInTheSameDrain : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(12800.0, -13000.0, -30000.0);
    private const float32 k_Penetration = 0.75f;

    private FCk_Handle_FoodPiece _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, k_Origin), Make_Spec(1.0));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("set the cook state and cut in one step", n"Step_SetCookStateThenCut");
        Add_Step_WaitUntil("the cut resolved and both halves are Ready", n"Check_CutSettled");
        Add_Step("the source was cut and both halves carry the cook state", n"Step_AssertHalves");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SourceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_SetCookStateThenCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto CookState = FMars_CookState();
        CookState.Penetration = k_Penetration;
        _Source.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
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
        Assert_Equals_Int(_Cuts.Num(), 1, "exactly one OnCutResolved");
        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::RefusedBusy), 0, "the cook state is not a cut: nothing is refused busy");

        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the source reported Cut (got {Result.Outcome :n})");
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        Assert_True(Math::IsNearlyEqual(Result.Positive.Get_CookState().Penetration, k_Penetration),
            f"the positive half carries the cook state (Penetration {Result.Positive.Get_CookState().Penetration})");
        Assert_True(Math::IsNearlyEqual(Result.Negative.Get_CookState().Penetration, k_Penetration),
            f"the negative half carries the cook state (Penetration {Result.Negative.Get_CookState().Penetration})");
    }
}
