// A walk pull stretched to 0.8 and then walked back in to 0.2 un-stretches: the Pull falls with the distance and the spring
// follows it down, the alpha under 0.3 within 1 s of the step back, and nothing is released on the way.
class UMars_AutoTest_ScreamingTurnip_WalkingBackUnstretches : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 33000.0, -30000.0);

    private const float32 k_OutAlpha = 0.8f;
    private const float32 k_BackAlpha = 0.2f;
    private const float32 k_BelowAlpha = 0.3f;
    private const float32 k_AlphaTolerance = 0.05f;
    private const float64 k_FallSeconds = 1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        Build_Floor(InHandle);
        Spawn_Bed(InHandle);

        Add_Step_WaitUntil("the bed is constructed", n"Check_BedReady");
        Add_Step("start a pull with free hands", n"Step_Pull");
        Add_Step_WaitUntil("the puller grips the stalks", n"Check_PullGripped", k_SlowPolls);
        Add_Step("walk back 0.8 of the stretch travel", n"Step_WalkOut");
        Add_Step_WaitSeconds("the spring settles", 1.0f);
        Add_Step("stretched to 0.8; walk back in to 0.2", n"Step_WalkBackIn");
        Add_Step_WaitUntil("the alpha falls under 0.3", n"Check_AlphaFell", k_SlowPolls);
        Add_Step("it fell within 1 s, nothing released", n"Step_AssertFellPromptly");
        Add_Step("let go", n"Step_LetGo");
        Add_Step_WaitUntil("the pull finishes", n"Check_PullFinished", k_SlowPolls);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_WalkOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Walk_Puller(Get_WalkCmFor(k_OutAlpha));
    }

    UFUNCTION()
    private void Step_WalkBackIn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_PullAlpha(), k_OutAlpha, k_AlphaTolerance, "stretched to the ground gained");
        Mark_Time();
        Walk_Puller(Get_WalkCmFor(k_BackAlpha));
    }

    UFUNCTION()
    private void Check_AlphaFell(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_BedControl.Get_IsManipulating() == false || Get_PullAlpha() < k_BelowAlpha);
    }

    UFUNCTION()
    private void Step_AssertFellPromptly(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Seconds = Get_SecondsSinceMark();
        Assert_True(_BedControl.Get_IsManipulating(), "still gripped: walking back is not letting go");
        Assert_True(Seconds <= k_FallSeconds, f"the alpha fell under {k_BelowAlpha} {Seconds :.3} s after the step back (at most {k_FallSeconds} s)");
        Assert_Equals_Int(_PullResults.Num(), 0, "the interaction is still live");
        Assert_Equals_Int(_Released.Num(), 0, "nothing released");
    }

    UFUNCTION()
    private void Step_LetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Cancel_Pull();
    }
}
