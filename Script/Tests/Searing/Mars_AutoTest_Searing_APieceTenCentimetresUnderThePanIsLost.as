// A piece whose middle is 10 cm under the cooking surface (over the disc, deeper than Loss.FallThroughCm) fell through:
// it is lost at once, judged by the depth, not by its own half height.
class UMars_AutoTest_Searing_APieceTenCentimetresUnderThePanIsLost : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    private const float64 k_Depth = 10.0;
    // Lost on the frame the teleport lands; a few frames of slack.
    private const int32 k_MaxFramesToLoss = 5;

    private int32 _FramesSinceTeleport = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);

        Add_Steps_AddPieceAndLand();
        Add_Step("the piece rests on the pan; move its middle 10 cm under the surface", n"Step_Sink");
        Add_Step_WaitUntil("the piece is lost", n"Check_Lost", 0, 2.0f);
        Add_Step("it was lost within a few frames of falling through", n"Step_AssertLost");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Sink(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Spec.Loss.FallThroughCm < k_Depth, f"10 cm is deeper than Loss.FallThroughCm ({_Spec.Loss.FallThroughCm})");
        Assert_True(_LostIds.Num() == 0, "the resting piece is not lost");
        Teleport_Piece(Get_FirstId(), FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ - k_Depth), FRotator::ZeroRotator);
    }

    UFUNCTION()
    private void Check_Lost(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _FramesSinceTeleport += 1;
        auto Res = OutResult;
        Res.Set(_LostIds.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertLost(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LostIds.Num() == 1 && _LostIds[0].Get_IsSame(Get_FirstId()), "the piece is the one lost");
        Assert_True(_FramesSinceTeleport <= k_MaxFramesToLoss, f"lost within {k_MaxFramesToLoss} frames (took {_FramesSinceTeleport})");
    }
}

class AMars_AutoTest_Searing_APieceTenCentimetresUnderThePanIsLost_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_APieceTenCentimetresUnderThePanIsLost;
}
