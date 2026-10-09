// A centre cut that would leave a half below the piece's portion minimum is Rejected (RejectedTooSmall) and the piece stays
// whole and Ready: once by mass (MinPortionMassKg above half the mass) and once by thickness (MinPortionThicknessCm above
// half the box).
class UMars_AutoTest_FoodPiece_TooSmallPortionIsRejected : UMars_AutoTestRig_FoodPiece
{
    private FCk_Handle_FoodPiece _TooLight;
    private FCk_Handle_FoodPiece _TooThin;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LightSpec = Make_Spec(1.0);
        LightSpec.Tuners.MinPortionMassKg = 0.6;
        _TooLight = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -40500.0)), LightSpec);

        auto ThinSpec = Make_Spec(1.0);
        ThinSpec.Tuners.MinPortionThicknessCm = 6.0;
        _TooThin = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(50.0, 0.0, -40500.0)), ThinSpec);

        Add_Step_WaitUntil("both pieces are Ready", n"Check_BothReady");
        Add_Step("cut both through their centres", n"Step_CutBoth");
        Add_Step_WaitUntil("both cuts resolved", n"Check_BothResolved");
        Add_Step("both cuts were rejected and both pieces are whole", n"Step_AssertRejected");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_BothReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_TooLight) && Get_HasReadied(_TooThin));
    }

    UFUNCTION()
    private void Step_CutBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Cut(_TooLight, Get_BoundsCenter(_TooLight), FVector::ForwardVector);
        Cut(_TooThin, Get_BoundsCenter(_TooThin), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_BothResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 2, "two resolutions");
        for (int32 Index = 0; Index < _Cuts.Num(); ++Index)
        {
            const auto Result = _Cuts[Index];
            Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Rejected, f"cut {Index} is Rejected (got {Result.Outcome :n})");
            Assert_True(Result.SliceOutcome.IsSet() && Result.SliceOutcome.GetValue() == ECk_RuntimeMesh_SliceOutcome::RejectedTooSmall, f"cut {Index} was too small");
        }

        Assert_Equals_Float(_TooLight.Get_MinimumPortionVolumeCm3(), 600.0, 0.01, "the mass minimum is 600 cm3 at the piece's density");
        AssertWhole(_TooLight);
        AssertWhole(_TooThin);
    }

    private void AssertWhole(FCk_Handle_FoodPiece InPiece)
    {
        Assert_True(ck::IsValid(InPiece), "the piece is alive");
        Assert_True(InPiece.Get_Status() == EMars_FoodPiece_Status::Ready, "the piece is Ready again");
        Assert_False(InPiece.Get_IsCutting(), "the piece is not cutting");
        Assert_Equals_Float(InPiece.Get_VolumeCm3(), 1000.0, 0.01, "the piece kept its volume");
    }
}
