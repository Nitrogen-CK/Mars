// A walk pull stretched to half its travel and then let go (the interaction cancelled before the threshold) finishes Failed
// and consumes nothing: no release, the charge still there, the target still enabled, no yield afterwards. The let-go ends
// the manipulation: the Control's alpha is back near 0 within 1 s (the springback the player sees is SRC_Cancel, drawn).
class UMars_AutoTest_ScreamingTurnip_ACancelledPullKeepsTheCharge : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 21000.0, -30000.0);

    private const float32 k_HeldAlpha = 0.5f;
    private const float32 k_AlphaTolerance = 0.05f;
    private const float64 k_SpringbackSeconds = 1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        Build_Floor(InHandle);
        Spawn_Bed(InHandle);

        Add_Step_WaitUntil("the bed is constructed", n"Check_BedReady");
        Add_Step("start a pull with free hands", n"Step_Pull");
        Add_Step_WaitUntil("the puller grips the stalks", n"Check_PullGripped", k_SlowPolls);
        Add_Step("walk back half the stretch travel", n"Step_WalkHalfway");
        Add_Step_WaitSeconds("the spring settles", 1.0f);
        Add_Step("stretched to half, still live; let go", n"Step_LetGo");
        Add_Step_WaitUntil("the pull finishes", n"Check_PullFinished", k_SlowPolls);
        Add_Step_WaitUntil("the alpha is back near 0", n"Check_AlphaBackNearZero", k_SlowPolls);
        Add_Step("the alpha fell back within 1 s", n"Step_AssertSpringbackPrompt");
        Add_Step_WaitSeconds("past where a full pull would have completed", 0.8f);
        Add_Step("nothing consumed", n"Step_AssertKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_WalkHalfway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Walk_Puller(Get_WalkCmFor(k_HeldAlpha));
    }

    UFUNCTION()
    private void Step_LetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PullResults.Num(), 0, "the pull is still live at half the stretch");
        Assert_Equals_Float(Get_PullAlpha(), k_HeldAlpha, k_AlphaTolerance, "the alpha follows the ground gained");
        Mark_Time();
        Cancel_Pull();
    }

    UFUNCTION()
    private void Check_AlphaBackNearZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PullAlpha() < k_AlphaTolerance);
    }

    UFUNCTION()
    private void Step_AssertSpringbackPrompt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Seconds = Get_SecondsSinceMark();
        Assert_True(Seconds <= k_SpringbackSeconds, f"the alpha was back near 0 {Seconds :.3} s after the let-go (at most {k_SpringbackSeconds} s)");
        Assert_False(_BedControl.Get_IsManipulating(), "the let-go ended the manipulation");
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PullResults[0] == ECk_SucceededFailed::Failed, "a let-go pull finishes Failed");
        Assert_Equals_Int(_Released.Num(), 0, "no release");
        Assert_Equals_Int(_BedForage.Get_ChargesLeft(), 1, "the charge is kept");
        Assert_False(_BedForage.Get_IsExhausted(), "the bed is not exhausted");
        Assert_True(_BedInteractable.Get_EnableDisable() == ECk_EnableDisable::Enable, "the target is still enabled");
        Assert_Equals_Int(Get_YieldCountNearBed(InHandle), 0, "no root lies by the bed");
    }
}
