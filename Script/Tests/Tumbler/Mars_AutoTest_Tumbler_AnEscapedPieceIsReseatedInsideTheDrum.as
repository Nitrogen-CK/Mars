// With the hatch shut and one piece at rest inside the shell, the piece teleported 100 cm out in front of the drum (where
// nothing holds it) is reseated within 1 s: OnPieceReseated fires once for it, the reseat count is 1, it is inside the shell
// again, the drum still holds one piece, and the jump back coats nothing (its coverage grows by no more than the short drop
// from the reseat point onto the floor could add).
class UMars_AutoTest_Tumbler_AnEscapedPieceIsReseatedInsideTheDrum : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 12.0f;

    // Outside the shell's inner radius, in front of the axle at its height.
    private const float64 k_EscapeCm = 100.0;
    // The reseat point's drop onto the floor and the settle after it, well under the 100+ cm jump.
    private const float32 k_SettleCm = 5.0f;

    private float32 _CoverageBefore = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Steps_StationReady();
        Add_Steps_OpenHatch();
        Add_Step("load piece 0", n"Step_AddFirst");
        Add_Step_WaitUntil("it is added", n"Check_Added1", 0, 1.0f);
        Add_Steps_CloseHatch();
        Add_Step_WaitUntil("it rests inside the shell", n"Check_AllAtRest", 0, 3.0f);
        Add_Step("teleport it out of the drum", n"Step_TeleportOut");
        Add_Step_WaitUntil("it was reseated", n"Check_Reseated", 0, 1.0f);
        Add_Step_WaitUntil("it is inside the shell again", n"Check_InsideAgain", 0, 1.0f);
        Add_Step_WaitFrames("a second reseat would show", 5);
        Add_Step("reseated once, inside, the batch and its coverage kept", n"Step_AssertReseated");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPiece(0);
    }

    UFUNCTION()
    private void Check_Added1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() >= 1);
    }

    UFUNCTION()
    private void Step_TeleportOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_PieceInside(Make_Id(0)), "the piece starts inside the shell");
        Assert_Equals_Int(_Tumbler.Get_Reseats(), 0, "nothing was reseated yet");
        _CoverageBefore = _Tumbler.Get_PieceCoverage(Make_Id(0));
        Teleport(Make_Id(0), k_AxleLocal - FVector(float64(_Spec.Drum.InnerRadius) + k_EscapeCm, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_Reseated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReseatIds.Num() >= 1);
    }

    UFUNCTION()
    private void Check_InsideAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_PieceInside(Make_Id(0)));
    }

    UFUNCTION()
    private void Step_AssertReseated(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ReseatIds.Num(), 1, "OnPieceReseated fired once");
        if (_ReseatIds.Num() > 0)
        { Assert_True(_ReseatIds[0].Get_IsSame(Make_Id(0)), "OnPieceReseated names the escaped piece"); }

        Assert_Equals_Int(_Tumbler.Get_Reseats(), 1, "one reseat counted");
        Assert_True(Check_PieceInside(Make_Id(0)), "the piece is inside the shell");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 1, "the drum still holds one piece");

        const auto Coverage = _Tumbler.Get_PieceCoverage(Make_Id(0));
        const auto MaxGain = k_SettleCm * _Spec.Coating.CoveragePerCm;
        Log(f"[Mars_AutoTest_Tumbler_AnEscapedPieceIsReseatedInsideTheDrum] coverage {_CoverageBefore :.4} -> {Coverage :.4}");
        Assert_True(Coverage >= _CoverageBefore && Coverage - _CoverageBefore <= MaxGain,
            f"the jump coated nothing ({_CoverageBefore :.4} -> {Coverage :.4}, at most {MaxGain :.4} from the settle)");
    }
}
