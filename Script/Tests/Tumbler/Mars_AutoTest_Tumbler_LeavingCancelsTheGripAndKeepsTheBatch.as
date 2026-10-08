// With two pieces in, a grip rocked part way and then cancelled (the operator left) frees the hand, lets go of the lever and
// returns the drum home; both pieces stay in with their coverage kept (the return only adds to it). A press on the lever
// released before the reach arrives (ReachSeconds 1.0) frees the hand and never grips.
class UMars_AutoTest_Tumbler_LeavingCancelsTheGripAndKeepsTheBatch : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_SlowReachSeconds = 1.0f;

    private float32 _Coverage0AtCancel = 0.0f;
    private float32 _Coverage1AtCancel = 0.0f;
    private int32 _ModesBeforePress = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Hand.ReachSeconds = k_SlowReachSeconds;
        BuildStation(InHandle, Spec);

        Add_Step_WaitUntil("the station's nodes are posed", n"Check_NodesPosed", 0, 2.0f);
        Add_Steps_OpenHatch();
        Add_Step("load pieces 0 and 1", n"Step_AddTwo");
        Add_Step_WaitUntil("both are answered", n"Check_Answered2", 0, 1.0f);
        Add_Steps_CloseHatch();
        Add_Steps_Grip();
        Add_Step_Rock("rock part way down", k_RockDegrees, 15);
        Add_Step("the operator leaves mid-arc", n"Step_SampleAndCancel");
        Add_Step("the hand is free and the drum returning one pass later", n"Step_AssertCancelled");
        Add_Step_WaitUntil("the lever is let go", n"Check_LeverLetGo", 0, 1.0f);
        Add_Step_WaitUntil("the drum is home", n"Check_DrumHome", 0, 2.0f);
        Add_Step("the batch is kept", n"Step_AssertBatchKept");
        Add_Step("look at the lever", n"Step_LookToLever");
        Add_Step_WaitUntil("the lever is hovered", n"Check_HoveredLever", 0, 2.0f);
        Add_Step("press on the lever", n"Step_PressCounted");
        Add_Step_WaitUntil("the hand reaches", n"Check_Reaching", 0, 1.0f);
        Add_Step("let go before the reach arrives", n"Step_Release");
        Add_Step("the hand is free one pass later", n"Step_AssertReachDropped");
        Add_Step_WaitSeconds("the reach would have arrived by now", k_SlowReachSeconds + 0.2f);
        Add_Step("it never gripped", n"Step_AssertNeverGripped");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPiece(0);
        AddPiece(1);
    }

    UFUNCTION()
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Step_SampleAndCancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Axle.Get_Alpha();
        Assert_True(Alpha > 0.05f && Alpha < 0.95f, f"the drum is mid-arc (alpha {Alpha :.3})");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 2, "two pieces in the drum");
        _Coverage0AtCancel = _Tumbler.Get_PieceCoverage(Make_Id(0));
        _Coverage1AtCancel = _Tumbler.Get_PieceCoverage(Make_Id(1));
        Cancel();
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Free), f"the hand is free (got {_Tumbler.Get_HandMode() :n})");
        Assert_True(Check_Drum(EMars_Tumbler_Drum::Returning), f"the drum is returning (got {_Tumbler.Get_Drum() :n})");
    }

    UFUNCTION()
    private void Check_LeverLetGo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Step_AssertBatchKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 2, "both pieces are still in");
        Assert_True(_Tumbler.Get_HasPiece(Make_Id(0)) && _Tumbler.Get_HasPiece(Make_Id(1)), "the same two pieces");
        const auto Coverage0 = _Tumbler.Get_PieceCoverage(Make_Id(0));
        const auto Coverage1 = _Tumbler.Get_PieceCoverage(Make_Id(1));
        Assert_True(Coverage0 >= _Coverage0AtCancel && Coverage0 > 0.0f, f"piece 0 kept its coverage ({_Coverage0AtCancel :.4} -> {Coverage0 :.4})");
        Assert_True(Coverage1 >= _Coverage1AtCancel && Coverage1 > 0.0f, f"piece 1 kept its coverage ({_Coverage1AtCancel :.4} -> {Coverage1 :.4})");
        Assert_Equals_Float(_Axle.Get_Alpha(), 0.0, 0.0, "the drum is back at alpha 0");
        Assert_Equals_Int(_LeverEngagedCount, 0, "the Control never engaged");
    }

    UFUNCTION()
    private void Step_PressCounted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _ModesBeforePress = _HandModes.Num();
        Press();
    }

    UFUNCTION()
    private void Step_AssertReachDropped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Free), f"the hand is free (got {_Tumbler.Get_HandMode() :n})");
    }

    UFUNCTION()
    private void Step_AssertNeverGripped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Free), "the hand stays free");
        Assert_Equals_Int(Count_Modes(EMars_Tumbler_HandMode::Gripped, _ModesBeforePress), 0, "no Gripped edge after the press");
        Assert_Equals_Int(Count_Modes(EMars_Tumbler_HandMode::Reaching, _ModesBeforePress), 1, "one Reaching edge after the press");
        Assert_False(_Lever.Get_IsManipulating(), "the lever was never gripped");
        Assert_True(Check_Drum(EMars_Tumbler_Drum::Home), "the drum stayed home");
    }
}
