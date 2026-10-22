// A six-detent dial (60 degrees a detent) from 0. A +50 turn puts the pointer at 50, nearest detent 1, one crossing; -25
// brings it to 25 (detent 0, one crossing back); -40 goes through zero to 345 (still detent 0, no crossing). A settle snaps
// it onto 0 with no crossing. Then +130 and a settle in one drain: two crossings, detent 2, the pointer on 120. Finally a
// locked dial drops a turn and a settle.
class UMars_AutoTest_Dial_TurnFollowsAndSettlesOnTheNearestDetent : UMars_AutoTestRig_Dial
{
    private int32 _AnglesBeforeTurnAndSettle = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddDial(InHandle, Make_Spec(6, 0));

        Add_Step("turn +50", n"Step_TurnPlus50");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("at 50, detent 1, one crossing; turn -25", n"Step_AssertAt50");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("at 25, detent 0, one crossing back; turn -40 through zero", n"Step_AssertAt25");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("at 345, still detent 0, no crossing; settle", n"Step_AssertAt345");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("snapped onto 0; turn +130 and settle in one drain", n"Step_AssertSettledThenTurnAndSettle");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("on 120, detent 2, two crossings; lock, then turn and settle", n"Step_AssertOn120ThenLock");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("a locked dial drops both", n"Step_AssertLocked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDrained());
    }

    UFUNCTION()
    private void Step_TurnPlus50(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Dial.Get_Angle(), 0.0f, 0.001f, "the pointer starts on its detent");
        _Dial.Request_Turn(FMars_Request_Dial_Turn(50.0f));
    }

    UFUNCTION()
    private void Step_AssertAt50(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Dial.Get_Angle(), 50.0f, 0.001f, "the pointer follows the turn");
        Assert_Equals_Int(_Dial.Get_Index(), 1, "50 is nearest detent 1");
        Assert_Equals_Int(Get_TotalCrossings(), 1, "the 30 degree line was crossed once");
        Assert_Equals_Int(_Changes.Num(), 1, "one index change");

        _Dial.Request_Turn(FMars_Request_Dial_Turn(-25.0f));
    }

    UFUNCTION()
    private void Step_AssertAt25(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Dial.Get_Angle(), 25.0f, 0.001f, "the pointer came back to 25");
        Assert_Equals_Int(_Dial.Get_Index(), 0, "25 is nearest detent 0");
        Assert_Equals_Int(Get_TotalCrossings(), 2, "crossing back counts too");

        _Dial.Request_Turn(FMars_Request_Dial_Turn(-40.0f));
    }

    UFUNCTION()
    private void Step_AssertAt345(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Dial.Get_Angle(), 345.0f, 0.001f, "the pointer wrapped through zero");
        Assert_Equals_Int(_Dial.Get_Index(), 0, "345 is nearest detent 0, not 6");
        Assert_Equals_Int(Get_TotalCrossings(), 2, "staying inside detent 0's half-lines crosses nothing");

        _Dial.Request_Settle(FMars_Request_Dial_Settle());
    }

    UFUNCTION()
    private void Step_AssertSettledThenTurnAndSettle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Dial.Get_Angle(), 0.0f, 0.001f, "the settle snapped the pointer onto its detent");
        Assert_Equals_Int(Get_TotalCrossings(), 2, "a settle crosses nothing");

        _AnglesBeforeTurnAndSettle = _Angles.Num();
        _Dial.Request_Turn(FMars_Request_Dial_Turn(130.0f));
        _Dial.Request_Settle(FMars_Request_Dial_Settle());
    }

    UFUNCTION()
    private void Step_AssertOn120ThenLock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 2, "130 is nearest detent 2");
        Assert_Equals_Float(_Dial.Get_Angle(), 120.0f, 0.001f, "the settle in the same drain lands on detent 2");
        Assert_Equals_Int(_Angles.Num(), _AnglesBeforeTurnAndSettle + 1, "one angle broadcast for the drain");
        Assert_Equals_Int(_Crossings.Last(), 2, "two detent lines crossed on the way");

        _Dial.Request_SetLocked(FMars_Request_Dial_SetLocked(true));
        _Dial.Request_Turn(FMars_Request_Dial_Turn(90.0f));
        _Dial.Request_Settle(FMars_Request_Dial_Settle());
    }

    UFUNCTION()
    private void Step_AssertLocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Dial.Get_IsLocked(), "locked");
        Assert_Equals_Float(_Dial.Get_Angle(), 120.0f, 0.001f, "a locked dial does not turn");
        Assert_Equals_Int(_Dial.Get_Index(), 2, "nor change detent");
    }
}
