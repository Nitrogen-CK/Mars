// A walk pull held at 0.8 of its stretch travel for a second settles there (alpha within 0.05 of 0.8, under the 0.97
// threshold) and never releases: the interaction stays live, the manipulation gripped, the charge kept. Then let go.
class UMars_AutoTest_ScreamingTurnip_AStretchShortOfTheBreakNeverReleases : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 30000.0, -30000.0);

    private const float32 k_HeldAlpha = 0.8f;
    private const float32 k_AlphaTolerance = 0.05f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        Build_Floor(InHandle);
        Spawn_Bed(InHandle);

        Add_Step_WaitUntil("the bed is constructed", n"Check_BedReady");
        Add_Step("start a pull with free hands", n"Step_Pull");
        Add_Step_WaitUntil("the puller grips the stalks", n"Check_PullGripped", k_SlowPolls);
        Add_Step("walk back 0.8 of the stretch travel", n"Step_WalkShortOfTheBreak");
        Add_Step_WaitSeconds("hold there for 1 s", 1.0f);
        Add_Step("settled short of the break: live, gripped, nothing released", n"Step_AssertHeldShort");
        Add_Step("let go", n"Step_LetGo");
        Add_Step_WaitUntil("the pull finishes", n"Check_PullFinished", k_SlowPolls);
        Add_Step("the let-go pull failed and kept the charge", n"Step_AssertKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_WalkShortOfTheBreak(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Walk_Puller(Get_WalkCmFor(k_HeldAlpha));
    }

    UFUNCTION()
    private void Step_AssertHeldShort(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_PullAlpha(), k_HeldAlpha, k_AlphaTolerance, "the stretch settles at the ground gained");
        Assert_Equals_Int(_PullResults.Num(), 0, "the interaction is still live");
        Assert_True(_BedControl.Get_IsManipulating(), "the stalks are still gripped");
        Assert_Equals_Int(_Released.Num(), 0, "nothing released");
        Assert_Equals_Int(_BedForage.Get_ChargesLeft(), 1, "the charge is kept");
    }

    UFUNCTION()
    private void Step_LetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Cancel_Pull();
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PullResults[0] == ECk_SucceededFailed::Failed, "the let-go pull finishes Failed");
        Assert_Equals_Int(_Released.Num(), 0, "no release");
        Assert_Equals_Int(_BedForage.Get_ChargesLeft(), 1, "the charge is kept");
    }
}
