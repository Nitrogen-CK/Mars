// A set puts the dial where its host says it stands: Placed counts no detent, Stepped counts the shorter way round
// (4 to 0 of six is two forward, 0 to 5 is one back). A set and a lock asked in one drain leave the dial locked on the
// set's index.
class UMars_AutoTest_Dial_ASetIndexPlacesOrStepsThePointer : UMars_AutoTestRig_Dial
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddDial(InHandle, Make_Spec(6, 0));

        Add_Step("place it on 4", n"Step_PlaceOnFour");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("on 4 with no detent counted; step it to 0", n"Step_AssertPlacedThenStepToZero");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("two detents forward; step it to 5", n"Step_AssertTwoThenStepToFive");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("one detent back; set it to 2 and lock it in one drain", n"Step_AssertOneThenSetAndLock");
        Add_Step_WaitUntil("the dial drains", n"Check_Drained", 0, 0);
        Add_Step("locked on 2", n"Step_AssertLockedOnTheSet");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDrained());
    }

    UFUNCTION()
    private void Step_PlaceOnFour(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dial.Request_SetIndex(FMars_Request_Dial_SetIndex(4, EMars_Dial_Arrival::Placed));
    }

    UFUNCTION()
    private void Step_AssertPlacedThenStepToZero(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 4, "the set placed the index on 4");
        Assert_True(Math::IsNearlyEqual(_Dial.Get_Angle(), utils_dial::Get_DetentAngle(4, 6)), "the pointer stands on detent 4");
        Assert_Equals_Int(_Crossings.Num(), 1, "one angle change");
        Assert_Equals_Int(_Crossings.Num() > 0 ? _Crossings[0] : -1, 0, "a placed set counts no detent");

        _Dial.Request_SetIndex(FMars_Request_Dial_SetIndex(0, EMars_Dial_Arrival::Stepped));
    }

    UFUNCTION()
    private void Step_AssertTwoThenStepToFive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 0, "the set stepped the index to 0");
        Assert_Equals_Int(_Crossings.Num(), 2, "one more angle change");
        Assert_Equals_Int(_Crossings.Num() > 1 ? _Crossings[1] : -1, 2, "4 to 0 of six is two detents the shorter way");

        _Dial.Request_SetIndex(FMars_Request_Dial_SetIndex(5, EMars_Dial_Arrival::Stepped));
    }

    UFUNCTION()
    private void Step_AssertOneThenSetAndLock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dial.Get_Index(), 5, "the set stepped the index to 5");
        Assert_Equals_Int(_Crossings.Num() > 2 ? _Crossings[2] : -1, 1, "0 to 5 of six is one detent the shorter way");

        _Dial.Request_SetLocked(FMars_Request_Dial_SetLocked(true));
        _Dial.Request_SetIndex(FMars_Request_Dial_SetIndex(2, EMars_Dial_Arrival::Placed));
    }

    UFUNCTION()
    private void Step_AssertLockedOnTheSet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Dial.Get_IsLocked(), "the lock applied");
        Assert_Equals_Int(_Dial.Get_Index(), 2, "the set applied first, lock or no lock");
        Assert_True(Math::IsNearlyEqual(_Dial.Get_Angle(), utils_dial::Get_DetentAngle(2, 6)), "the locked pointer stands on detent 2");
    }
}
