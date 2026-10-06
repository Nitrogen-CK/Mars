// One press = one chop: two chop requests in the same step, with the hand on the band, resolve exactly one chop. The run
// then waits a wall-clock window longer than a whole chop past the first, so a late second resolution would be seen.
class UMars_AutoTest_Dicing_ChopWhileChoppingIsIgnored : UMars_AutoTestRig_Dicing
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, FMars_Dicing_Spec());

        _Dicing.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));

        Add_Step("nudge the hand onto the band", n"Step_AssertComposedAndAimAtBand");
        Add_Step_WaitUntil("the hand is on the band", n"Check_HandOnBand", 0, 2.0f);
        Add_Step("chop twice in one step", n"Step_ChopTwice");
        Add_Step_WaitUntil("the chop resolved and the cleaver is back up", n"Check_FirstChopDone", 0, 2.0f);
        Add_Step_WaitSeconds("a second chop would resolve in this window", 0.3f);
        Add_Step("exactly one chop resolved", n"Step_AssertOneChop");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposedAndAimAtBand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Dicing), "the feature composed");
        AimAtBand();
    }

    UFUNCTION()
    private void Step_ChopTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
    }

    UFUNCTION()
    private void Step_AssertOneChop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Resolved.Num(), 1, "exactly one OnChopResolved for two same-step chop requests");
        Assert_Equals_Int(_Dicing.Get_UsefulChops(), 1, "exactly one useful chop counted");
        Assert_False(_Dicing.Get_IsChopping(), "the cleaver is back up");
    }
}
