// Another role may commit while the first is still turning. Locking freezes the nearest selected glyph, including its
// visible pointer; a later grip release must not leave it between detents or move the solved dial.
class UMars_AutoTest_Bellkeeper_SolveSettlesAnUnreleasedDial : UMars_AutoTestRig_Bellkeeper
{
    default _TimeoutSeconds = 10.0f;

    private TArray<float32> _VisibleAngles;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddLock(InHandle);
        auto First = _Dials[0];
        First.BindTo_OnAngleChanged(FMars_Delegate_Dial_OnAngleChanged(this, n"OnVisibleAngle"));
        Add_Step("turn the first dial partway onto its answer", n"Step_Turn");
        Add_Step_WaitUntil("the dials drain their turns", n"Check_Drained", k_SlowPolls, 0);
        Add_Step("commit while the first pointer is still between detents", n"Step_Commit");
        Add_Step_WaitUntil("the solved lock has locked and drained every dial", n"Check_Locked", k_SlowPolls, 0);
        Add_Step("the visible pointer settled before freezing; release the old grip", n"Step_AssertAndRelease");
        Add_Step_WaitUntil("the locked dial drains the later release", n"Check_Drained", k_SlowPolls, 0);
        Add_Step("the solved pointer remains on the selected glyph", n"Step_AssertFinal");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Turn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dials[0].Request_Turn(FMars_Request_Dial_Turn(50.0f));
        _Dials[1].Request_Step(FMars_Request_Dial_Step(2));
        _Dials[2].Request_Step(FMars_Request_Dial_Step(3));
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDrained());
    }

    UFUNCTION()
    private void Step_Commit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Dials[0].Get_Angle(), 50.0f, 0.001f, "the unreleased pointer is between detents");
        Assert_Equals_Int(_Dials[0].Get_Index(), 1, "the selected nearest glyph is the answer");
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_Locked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Bellkeeper.Get_IsSolved() && Get_IsDrained()
            && _Dials[0].Get_IsLocked() && _Dials[1].Get_IsLocked() && _Dials[2].Get_IsLocked());
    }

    UFUNCTION()
    private void Step_AssertAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[BellkeeperDialRepro] solved={_Bellkeeper.Get_IsSolved()} locked={_Dials[0].Get_IsLocked()} index={_Dials[0].Get_Index()} angle={_Dials[0].Get_Angle()} angleEvents={_VisibleAngles.Num()}");
        Assert_Equals_Float(_Dials[0].Get_Angle(), 60.0f, 0.001f, "locking settles the visible pointer on its selected glyph");
        Assert_Equals_Int(_VisibleAngles.Num(), 2, "locking publishes the final settled pointer angle once");
        Assert_Equals_Float(_VisibleAngles.Last(), 60.0f, 0.001f, "the assembly receives the actual final angle");
        _Dials[0].Request_Turn(FMars_Request_Dial_Turn(90.0f));
        _Dials[0].Request_Settle(FMars_Request_Dial_Settle());
    }

    UFUNCTION()
    private void Step_AssertFinal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Dials[0].Get_Angle(), 60.0f, 0.001f, "later turn/release cannot move a solved dial");
        Assert_Equals_Int(_VisibleAngles.Num(), 2, "the later locked release emits no new movement");
    }

    UFUNCTION()
    private void OnVisibleAngle(FCk_Handle_Dial InDial, float32 InAngle, int32 InCrossed)
    {
        _VisibleAngles.Add(InAngle);
    }
}
