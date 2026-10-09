// A piece on a mesh RuntimeMesh cannot import (the whole mushroom is over the raw-vertex ceiling) ensures, ends Failed and
// announces OnFailed once with LimitExceeded, never OnReady; a cut of it is refused RefusedNotReady without slicing. The
// ensure is expected (the actor wrapper below).
class UMars_AutoTest_FoodPiece_FailedImportIsReported : UMars_AutoTestRig_FoodPiece
{
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Piece = Build_Piece(assets::Mushroom_Mars_SM(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -41000.0)), Make_Spec(0.05));

        Add_Step_WaitUntil("the import failed", n"Check_Failed");
        Add_Step("the piece is Failed; cut it", n"Step_AssertFailedThenCut");
        Add_Step_WaitUntil("the cut resolved", n"Check_CutResolved");
        Add_Step_WaitSeconds("a late OnReady or second OnFailed would arrive in this window", 0.2f);
        Add_Step("the cut was refused and nothing else fired", n"Step_AssertRefused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Failed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Failures.Num() > 0 || _Readied.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertFailedThenCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Piece.Get_Status() == EMars_FoodPiece_Status::Failed, f"the piece is Failed (got {_Piece.Get_Status() :n})");
        Assert_Equals_Int(_Failures.Num(), 1, "OnFailed fired once");
        if (_Failures.Num() > 0)
        { Assert_True(_Failures[0] == ECk_RuntimeMesh_SetupFailure::LimitExceeded, f"the reason is LimitExceeded (got {_Failures[0] :n})"); }

        Cut(_Piece, FVector::ZeroVector, FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_CutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 1, "one resolution");
        Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::RefusedNotReady, f"the cut is RefusedNotReady (got {_Cuts[0].Outcome :n})");
        Assert_False(_Cuts[0].SliceOutcome.IsSet(), "a refused cut slices nothing");
        Assert_True(_Piece.Get_Status() == EMars_FoodPiece_Status::Failed, "the piece is still Failed");
        Assert_Equals_Int(_Readied.Num(), 0, "no OnReady");
        Assert_Equals_Int(_Failures.Num(), 1, "still one OnFailed");
    }
}

// Hand-authored so the deliberate import-failure ensure is an expected error rather than a failure.
class AMars_AutoTest_FoodPiece_FailedImportIsReported_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_FoodPiece_FailedImportIsReported;
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("failed to import its mesh: LimitExceeded");
        return Out;
    }
}
