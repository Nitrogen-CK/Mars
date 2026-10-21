// A lock queued after a step in the same drain still applies first, so that step is dropped; a step on a locked dial is
// dropped too. Unlocking and stepping in one drain moves it again.
class UMars_AutoTest_Dial_LockDropsStepsUntilUnlocked : UMars_AutoTestRig_Dial
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddDial(InHandle, Make_Spec(6, 0));

        Add_Step("a step, then a lock, in one drain", n"Step_StepThenLock");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("locked and unmoved; step it again", n"Step_AssertLockedThenStep");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("still unmoved; unlock and step in one drain", n"Step_AssertDroppedThenUnlock");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("unlocked, moved to 1", n"Step_AssertUnlocked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_StepThenLock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dial.Request_Step(FMars_Request_Dial_Step(1));
        _Dial.Request_SetLocked(FMars_Request_Dial_SetLocked(true));
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDrained());
    }

    UFUNCTION()
    private void Step_AssertLockedThenStep(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Dial.Get_IsLocked(), "the lock applied");
        Assert_Equals_Int(_Dial.Get_Index(), 0, "the lock applies before the step, which is dropped");
        Assert_Equals_Int(_Changes.Num(), 0, "no broadcast");

        _Dial.Request_Step(FMars_Request_Dial_Step(2));
    }

    UFUNCTION()
    private void Step_AssertDroppedThenUnlock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 0, "a locked dial drops its steps");

        _Dial.Request_SetLocked(FMars_Request_Dial_SetLocked(false));
        _Dial.Request_Step(FMars_Request_Dial_Step(1));
    }

    UFUNCTION()
    private void Step_AssertUnlocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Dial.Get_IsLocked(), "unlocked");
        Assert_Equals_Int(_Dial.Get_Index(), 1, "the step after the unlock moved it");
        Assert_Equals_Int(_Changes.Num(), 1, "one broadcast");
    }
}
