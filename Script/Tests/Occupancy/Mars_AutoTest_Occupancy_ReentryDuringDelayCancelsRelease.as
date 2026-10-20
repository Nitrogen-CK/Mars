// A re-entry while the release delay runs cancels the release: the timer is destroyed, the occupancy stays active with
// one Active edge only, and it is still active well after the delay would have ended.
class UMars_AutoTest_Occupancy_ReentryDuringDelayCancelsRelease : UMars_AutoTestRig_Occupancy
{
    private const float32 k_Delay = 0.4f;

    private FCk_Handle_Occupancy _Occupancy;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTrigger(InHandle, FVector(8000.0, 330000.0, -41000.0));
        AddOccupants(InHandle, 1);

        _Occupancy = AddOccupancy(InHandle, Make_Spec(1, k_Delay));
        BindActiveChanges(_Occupancy);

        Add_Step("the occupant enters", n"Step_In");
        Add_Step_WaitUntil("active", n"Check_Active", k_SlowPolls, 0);
        Add_Step("the occupant leaves", n"Step_Out");
        Add_Step_WaitUntil("the release timer starts", n"Check_TimerStarted", k_SlowPolls, 0);
        Add_Step("the occupant comes back during the delay", n"Step_In");
        Add_Step_WaitUntil("the re-entry cancels the timer", n"Check_TimerCancelled", k_SlowPolls, 0);
        Add_Step_WaitSeconds("give a wrongful release time to land", k_Delay * 2.0f);
        Add_Step("still active: one Active edge only", n"Step_AssertStillActive");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_In(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveIn(0);
    }

    UFUNCTION()
    private void Step_Out(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveOut(0);
    }

    UFUNCTION()
    private void Check_Active(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 1 && _Occupancy.Get_IsActive());
    }

    UFUNCTION()
    private void Check_TimerStarted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 0 && _Occupancy.Get_IsActive() && ck::IsValid(Get_ReleaseTimer(_Occupancy)));
    }

    UFUNCTION()
    private void Check_TimerCancelled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 1 && ck::Is_NOT_Valid(Get_ReleaseTimer(_Occupancy)));
    }

    UFUNCTION()
    private void Step_AssertStillActive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Occupancy.Get_IsActive(), "the re-entry kept the occupancy active past the delay");
        Assert_Equals_Int(_ActiveChanges.Num(), 1, "only the first Active edge was broadcast");
    }
}
