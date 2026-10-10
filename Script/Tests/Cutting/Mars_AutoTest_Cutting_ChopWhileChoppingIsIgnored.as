// One press = one chop: two chop requests in the same step land exactly one chop. The run then waits a wall-clock window
// longer than a whole chop past the first, so a late second landing would be seen.
class UMars_AutoTest_Cutting_ChopWhileChoppingIsIgnored : UMars_AutoTestRig_Cutting
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, FMars_Cutting_Spec());

        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));

        Add_Step("chop twice in one step", n"Step_ChopTwice");
        Add_Step_WaitUntil("the chop landed and the cleaver is back up", n"Check_FirstChopDone", 0, 2.0f);
        Add_Step_WaitSeconds("a second chop would land in this window", 0.3f);
        Add_Step("exactly one chop landed", n"Step_AssertOneChop");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ChopTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Cutting), "the feature composed");
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
    }

    UFUNCTION()
    private void Step_AssertOneChop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChopsLanded, 1, "exactly one OnChopLanded for two same-step chop requests");
        Assert_False(_Cutting.Get_IsChopping(), "the cleaver is back up");
    }
}
