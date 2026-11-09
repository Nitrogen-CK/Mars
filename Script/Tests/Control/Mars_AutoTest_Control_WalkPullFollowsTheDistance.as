// A Walk lever's alpha follows the ground its puller gains from where it gripped: (d - d0) / WalkCm, horizontally (the
// puller stands 150 cm above the lever: a 3D distance would read differently), within 0.05 once the spring settles, down
// as well as up; carried past WalkCm, the threshold ends the interaction Succeeded and the lever engages once.
class UMars_AutoTest_Control_WalkPullFollowsTheDistance : UMars_AutoTestRig_Lever
{
    default _PullSource = EMars_Control_PullSource::Walk;

    private const float32 k_Tolerance = 0.05f;
    private const float32 k_FirstAlpha = 0.5f;
    private const float32 k_SecondAlpha = 0.3f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Inactive);

        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 0);
        Add_Step("grip the lever with the puller", n"Step_BeginWalkManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 0);
        Add_Step("the grip starts at rest; walk back half of WalkCm", n"Step_AssertRestAndWalkHalf");
        Add_Step_WaitSeconds("the spring settles", 1.0f);
        Add_Step("the alpha reads half; walk in to 0.3", n"Step_AssertHalfAndWalkIn");
        Add_Step_WaitSeconds("the spring settles", 1.0f);
        Add_Step("the alpha reads 0.3; walk past WalkCm", n"Step_AssertBackInAndWalkPast");
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 0);
        Add_Step("the threshold ended the interaction Succeeded", n"Step_AssertSucceeded");
        Add_Step_WaitUntil("the Succeeded finish runs the Engage chain", n"Check_Engaged", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertRestAndWalkHalf(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Control.TryGet_Puller() == _Puller, "the Walk grip carries the puller");
        Assert_True(_Control.Get_PullSource() == EMars_Control_PullSource::Walk, "the lever is a Walk control");
        Assert_Equals_Float(Get_ManipulationAlpha(), 0.0f, 0.001f, "no ground gained, no pull");
        Walk_Puller(k_FirstAlpha * _WalkCm);
    }

    UFUNCTION()
    private void Step_AssertHalfAndWalkIn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_ManipulationAlpha(), k_FirstAlpha, k_Tolerance, "the alpha is the ground gained over WalkCm");
        Assert_Equals_Int(_FinishedResults.Num(), 0, "the interaction is still live");
        Walk_Puller(k_SecondAlpha * _WalkCm);
    }

    UFUNCTION()
    private void Step_AssertBackInAndWalkPast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_ManipulationAlpha(), k_SecondAlpha, k_Tolerance, "walking back in lowers the alpha with the distance");
        Walk_Puller(1.3f * _WalkCm);
    }

    UFUNCTION()
    private void Step_AssertSucceeded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _FinishedResults[0];
        Assert_True(Result == ECk_SucceededFailed::Succeeded, f"the threshold ends the interaction Succeeded (got {Result :n})");
        Assert_False(_Control.Get_IsManipulating(), "the threshold ended the manipulation");
        Assert_False(ck::IsValid(_Control.TryGet_Puller()), "no puller once the grip ended");
    }

    UFUNCTION()
    private void Check_Engaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_EngagedCount >= 1);
    }
}
