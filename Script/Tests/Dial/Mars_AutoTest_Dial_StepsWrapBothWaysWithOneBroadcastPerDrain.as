// A six-detent dial at 4 takes +1, +1, +1 in one drain (4 -> 5 -> 0 -> 1) and broadcasts once with 1; then -3 in the next
// drain wraps back to 4. A drain whose steps cancel out (+2, -2) moves nothing and broadcasts nothing.
class UMars_AutoTest_Dial_StepsWrapBothWaysWithOneBroadcastPerDrain : UMars_AutoTestRig_Dial
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddDial(InHandle, Make_Spec(6, 4));

        Add_Step("three forward steps in one drain", n"Step_Forward");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("index 1, one broadcast with 1; then three steps back", n"Step_AssertForwardThenBack");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("index 4 again, a second broadcast; then two steps that cancel", n"Step_AssertBackThenCancel");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("still 4, no third broadcast", n"Step_AssertCancelled");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Forward(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 4, "the dial starts at its StartIndex");
        _Dial.Request_Step(FMars_Request_Dial_Step(1));
        _Dial.Request_Step(FMars_Request_Dial_Step(1));
        _Dial.Request_Step(FMars_Request_Dial_Step(1));
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDrained());
    }

    UFUNCTION()
    private void Step_AssertForwardThenBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 1, "4 + 3 wraps to 1 on six detents");
        Assert_Equals_Int(_Changes.Num(), 1, "one broadcast for the whole drain");
        if (_Changes.Num() == 1)
        { Assert_Equals_Int(_Changes[0], 1, "the broadcast carries the final index"); }

        _Dial.Request_Step(FMars_Request_Dial_Step(-3));
    }

    UFUNCTION()
    private void Step_AssertBackThenCancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 4, "1 - 3 wraps back to 4");
        Assert_Equals_Int(_Changes.Num(), 2, "a second broadcast");

        _Dial.Request_Step(FMars_Request_Dial_Step(2));
        _Dial.Request_Step(FMars_Request_Dial_Step(-2));
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 4, "the steps cancelled out");
        Assert_Equals_Int(_Changes.Num(), 2, "an unmoved dial does not broadcast");
    }
}
