// One press = one chop. Two chop requests in one step land one chop (only the drain's first can start one); a chop asked
// while the cleaver strikes (from OnChopStarted) and another while it recovers (from OnChopLanded) are presses during the
// chop and start nothing. Over a window longer than two whole chops past the first, exactly one chop started and landed.
class UMars_AutoTest_Cutting_ChopWhileChoppingIsIgnored : UMars_AutoTestRig_Cutting
{
    private TArray<EMars_Cutting_ChopPhase> _PhasesAtPress;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, FMars_Cutting_Spec());

        _Cutting.BindTo_OnChopStarted(FMars_Delegate_Cutting_OnChopStarted(this, n"OnChopStartedPressAgain"));
        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLandedPressAgain"));

        Add_Step("chop twice in one step", n"Step_ChopTwice");
        Add_Step_WaitUntil("the chop landed and the cleaver is back up", n"Check_FirstChopDone", 0, 0);
        // Two whole chops (a strike and a recovery each) and a margin: a chop restarted by either press would start and land here.
        Add_Step_WaitSeconds("a restarted chop would start and land in this window", 4.0f * _Spec.ChopSeconds + 0.1f);
        Add_Step("exactly one chop started and landed", n"Step_AssertOneChop");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ChopTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Cutting), "the feature composed");
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
    }

    // The first start: a chop asked now lands in the next drain, while the cleaver strikes.
    UFUNCTION()
    private void OnChopStartedPressAgain(FCk_Handle_Cutting InCutting)
    {
        OnChopStarted(InCutting);
        if (_ChopsStarted == 1)
        { Press(); }
    }

    // The first landing: a chop asked now lands in the next drain, while the cleaver recovers.
    UFUNCTION()
    private void OnChopLandedPressAgain(FCk_Handle_Cutting InCutting)
    {
        OnChopLanded(InCutting);
        if (_ChopsLanded == 1)
        { Press(); }
    }

    private void Press()
    {
        _PhasesAtPress.Add(_Cutting.Get_ChopPhase());
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
    }

    UFUNCTION()
    private void Step_AssertOneChop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PhasesAtPress.Num(), 2, "a chop was asked from the strike and from the recovery");
        if (_PhasesAtPress.Num() == 2)
        {
            Assert_True(_PhasesAtPress[0] == EMars_Cutting_ChopPhase::Striking, f"the first was asked while Striking (got {_PhasesAtPress[0] :n})");
            Assert_True(_PhasesAtPress[1] == EMars_Cutting_ChopPhase::Recovering, f"the second was asked while Recovering (got {_PhasesAtPress[1] :n})");
        }

        Assert_Equals_Int(_ChopsStarted, 1, "exactly one OnChopStarted");
        Assert_Equals_Int(_ChopsLanded, 1, "exactly one OnChopLanded");
        Assert_False(_Cutting.Get_IsChopping(), "the cleaver is back up");
    }
}
