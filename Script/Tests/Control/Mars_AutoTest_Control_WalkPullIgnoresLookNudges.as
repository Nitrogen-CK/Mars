// A gripped Walk lever ignores look nudges: 30 frames of 4-degree nudges (a Look lever at 0.02 alpha per degree would cross
// its threshold in about 11) leave the alpha at rest and the interaction live, with the puller standing still.
class UMars_AutoTest_Control_WalkPullIgnoresLookNudges : UMars_AutoTestRig_Lever
{
    default _PullSource = EMars_Control_PullSource::Walk;

    private const int32 k_NudgeFrames = 30;
    private int32 _NudgedFrames = 0;
    private float32 _PeakAlpha = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Inactive);

        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 0);
        Add_Step("grip the lever with the puller", n"Step_BeginWalkManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 0);
        Add_Step_WaitUntil("nudge every frame", n"Check_NudgedEnough", 0, 0);
        Add_Step_WaitSeconds("let the last nudges drain", 0.2f);
        Add_Step("the nudges moved nothing", n"Step_AssertUnmoved");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_NudgedEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _PeakAlpha = Math::Max(_PeakAlpha, Get_ManipulationAlpha());
        _Control.Request_Nudge(FMars_Request_Control_Nudge(4.0f));
        _NudgedFrames += 1;

        auto Res = OutResult;
        Res.Set(_NudgedFrames >= k_NudgeFrames);
    }

    UFUNCTION()
    private void Step_AssertUnmoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PeakAlpha = Math::Max(_PeakAlpha, Get_ManipulationAlpha());
        Assert_Equals_Float(_PeakAlpha, 0.0f, 0.001f, "the alpha never left rest under the nudges");
        Assert_True(_Control.Get_IsManipulating(), "the lever is still gripped");
        Assert_Equals_Int(_FinishedResults.Num(), 0, "the interaction is still live");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged");
    }
}
