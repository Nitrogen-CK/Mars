// With a release delay, the first drop below RequiredCount starts one release timer and the occupancy stays active; a
// later exit while that timer runs keeps the same timer (it does not restart the delay); when it ends the occupancy goes
// inactive and the timer is gone. RequiredCount 2 with three occupants, so two exits are both drops below it.
class UMars_AutoTest_Occupancy_ReleaseDelayStartsOneTimerThatLaterExitsDoNotExtend : UMars_AutoTestRig_Occupancy
{
    private FCk_Handle_Occupancy _Occupancy;
    private FCk_Handle_Timer _FirstTimer;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTrigger(InHandle, FVector(4000.0, 330000.0, -41000.0));
        AddOccupants(InHandle, 3);

        _Occupancy = AddOccupancy(InHandle, Make_Spec(2, 0.6f));
        BindActiveChanges(_Occupancy);

        Add_Step("all three enter", n"Step_AllIn");
        Add_Step_WaitUntil("active with three inside", n"Check_ActiveThree", k_SlowPolls, 0);
        Add_Step("no release timer while enough are inside", n"Step_AssertNoTimer");
        Add_Step("one leaves (still two)", n"Step_FirstOut");
        Add_Step_WaitUntil("the count drops to two", n"Check_CountTwo", k_SlowPolls, 0);
        Add_Step("still at RequiredCount: no timer", n"Step_AssertNoTimer");
        Add_Step("a second leaves (one, below RequiredCount)", n"Step_SecondOut");
        Add_Step_WaitUntil("the release timer starts", n"Check_TimerStarted", k_SlowPolls, 0);
        Add_Step("still active while the delay runs", n"Step_AssertStillActive");
        Add_Step("the last one leaves while the delay runs", n"Step_LastOut");
        Add_Step_WaitUntil("the count drops to zero", n"Check_CountZero", k_SlowPolls, 0);
        Add_Step("the later exit kept the same timer", n"Step_AssertSameTimer");
        Add_Step_WaitUntil("the delay ends and the occupancy releases", n"Check_Released", k_SlowPolls, 0);
        Add_Step("one Active edge, one Inactive edge, no timer left", n"Step_AssertEdges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AllIn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveIn(0);
        MoveIn(1);
        MoveIn(2);
    }

    UFUNCTION()
    private void Check_ActiveThree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 3 && _Occupancy.Get_IsActive());
    }

    UFUNCTION()
    private void Step_AssertNoTimer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(ck::IsValid(Get_ReleaseTimer(_Occupancy)), f"no release timer at count {_Occupancy.Get_Count()}");
        Assert_True(_Occupancy.Get_IsActive(), "active");
    }

    UFUNCTION()
    private void Step_FirstOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveOut(0);
    }

    UFUNCTION()
    private void Check_CountTwo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 2);
    }

    UFUNCTION()
    private void Step_SecondOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveOut(1);
    }

    UFUNCTION()
    private void Check_TimerStarted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 1 && ck::IsValid(Get_ReleaseTimer(_Occupancy)));
    }

    UFUNCTION()
    private void Step_AssertStillActive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstTimer = Get_ReleaseTimer(_Occupancy);
        Assert_True(_Occupancy.Get_IsActive(), "a drop below RequiredCount with a delay does not release at once");
        Assert_Equals_Int(_ActiveChanges.Num(), 1, "only the Active edge so far");
    }

    UFUNCTION()
    private void Step_LastOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveOut(2);
    }

    UFUNCTION()
    private void Check_CountZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 0);
    }

    UFUNCTION()
    private void Step_AssertSameTimer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Occupancy.Get_IsActive(), "still active: the delay started by the first drop is still running");
        Assert_True(Get_ReleaseTimer(_Occupancy) == _FirstTimer, "the later exit kept the timer the first drop started");
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_IsActive() == false);
    }

    UFUNCTION()
    private void Step_AssertEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ActiveChanges.Num(), 2, "one Active and one Inactive edge");
        Assert_True(_ActiveChanges.Num() == 2 && _ActiveChanges[1] == EMars_Occupancy_Activation::Inactive, "the second edge is Inactive");
        Assert_False(ck::IsValid(Get_ReleaseTimer(_Occupancy)), "the finished timer is cleared");
    }
}
