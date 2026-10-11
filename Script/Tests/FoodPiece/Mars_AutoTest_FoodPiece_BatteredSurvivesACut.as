// The batter dip is ledger state a cut half inherits with the rest of the cook state. A box piece is given a battered cook
// state (its +X fried 1.2 in batter); once it is on the ledger the piece is cut through its middle, and both halves carry
// Battered 1 and the fried face.
class UMars_AutoTest_FoodPiece_BatteredSurvivesACut : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(12800.0, -14500.0, -30000.0);
    private const float32 k_FriedHeat = 1.2f;
    private const float32 k_Tolerance = 0.0001f;

    private FCk_Handle_FoodPiece _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, k_Origin), Make_Spec(1.0));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("batter the source", n"Step_Batter");
        Add_Step_WaitUntil("the dip is on the ledger", n"Check_Battered");
        Add_Step("cut the source through its middle", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved and both halves are Ready", n"Check_CutSettled");
        Add_Step("both halves are battered", n"Step_AssertHalves");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SourceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_Batter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto CookState = FMars_FoodPiece_CookState();
        CookState.Batter[int32(EMars_Searing_Face::PosX)] = k_FriedHeat;
        CookState.Battered = 1.0f;
        _Source.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
    }

    UFUNCTION()
    private void Check_Battered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Source.Get_CookState().Battered > 0.5f);
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
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
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the source reported Cut (got {Result.Outcome :n})");
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        Assert_Half(Result.Positive, "positive");
        Assert_Half(Result.Negative, "negative");
    }

    private void Assert_Half(FCk_Handle_FoodPiece InHalf, const FString& InWhich)
    {
        const auto CookState = InHalf.Get_CookState();
        Assert_False(InHalf.Get_IsWhole(), f"the {InWhich} half is not whole");
        Assert_Equals_Float(CookState.Battered, 1.0f, k_Tolerance, f"the {InWhich} half is battered");
        Assert_Equals_Float(CookState.Batter[int32(EMars_Searing_Face::PosX)], k_FriedHeat, k_Tolerance,
            f"the {InWhich} half keeps the fried +X");
    }
}
