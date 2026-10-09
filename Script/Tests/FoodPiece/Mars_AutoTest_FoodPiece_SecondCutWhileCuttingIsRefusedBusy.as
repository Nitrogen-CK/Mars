// Two cuts issued in one step: the first is submitted and the piece is Cutting, so the second is refused RefusedBusy
// without slicing. Exactly one Cut and one RefusedBusy resolve.
class UMars_AutoTest_FoodPiece_SecondCutWhileCuttingIsRefusedBusy : UMars_AutoTestRig_FoodPiece
{
    private FCk_Handle_FoodPiece _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -40600.0)), Make_Spec(1.0));

        Add_Step_WaitUntil("the source is Ready", n"Check_SourceReady");
        Add_Step("cut twice in one step", n"Step_CutTwice");
        Add_Step_WaitUntil("both cuts resolved", n"Check_BothResolved");
        Add_Step_WaitSeconds("a third resolution would arrive in this window", 0.2f);
        Add_Step("one cut, one busy refusal", n"Step_AssertOneCutOneBusy");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SourceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_CutTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Cut(_Source, Get_BoundsCenter(_Source), FVector::ForwardVector);
        Cut(_Source, Get_BoundsCenter(_Source), FVector::RightVector);
    }

    UFUNCTION()
    private void Check_BothResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertOneCutOneBusy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 2, "exactly two resolutions for two cut requests");
        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut), 1, "one Cut");
        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::RefusedBusy), 1, "one RefusedBusy");

        const auto Busy = Get_FirstCut(EMars_FoodPiece_CutOutcome::RefusedBusy);
        Assert_False(Busy.SliceOutcome.IsSet(), "a busy refusal slices nothing");
        Assert_False(ck::IsValid(Busy.Positive) || ck::IsValid(Busy.Negative), "a busy refusal has no halves");

        const auto Committed = Get_FirstCut(EMars_FoodPiece_CutOutcome::Cut);
        Assert_Equals_Float(Committed.Positive.Get_VolumeCm3() + Committed.Negative.Get_VolumeCm3(), 1000.0, 0.01, "the one cut split the whole box");
    }
}
