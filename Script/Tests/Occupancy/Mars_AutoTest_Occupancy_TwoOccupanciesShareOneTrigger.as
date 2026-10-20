// Two occupancies counting through one trigger: the trigger links both and binds its enter/exit signals once; an
// occupant entering counts on both (each OnCountChanged once) and activates both, and leaving releases both.
class UMars_AutoTest_Occupancy_TwoOccupanciesShareOneTrigger : UMars_AutoTestRig_Occupancy
{
    private FCk_Handle_Occupancy _First;
    private FCk_Handle_Occupancy _Second;
    private int32 _FirstCountChanges = 0;
    private int32 _SecondCountChanges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTrigger(InHandle, FVector(12000.0, 330000.0, -41000.0));
        AddOccupants(InHandle, 1);

        _First = AddOccupancy(InHandle, Make_Spec(1, 0.0f));
        _Second = AddOccupancy(InHandle, Make_Spec(1, 0.0f));
        _First.BindTo_OnCountChanged(FMars_Delegate_Occupancy_OnCountChanged(this, n"OnFirstCountChanged"));
        _Second.BindTo_OnCountChanged(FMars_Delegate_Occupancy_OnCountChanged(this, n"OnSecondCountChanged"));

        Add_Step_WaitUntil("both occupancies are set up", n"Check_SetUp", 0, 0);
        Add_Step("the trigger links both and is bound once", n"Step_AssertLink");
        Add_Step("the occupant enters", n"Step_In");
        Add_Step_WaitUntil("both are active", n"Check_BothActive", k_SlowPolls, 0);
        Add_Step("each counted the entry once", n"Step_AssertCountedOnce");
        Add_Step("the occupant leaves", n"Step_Out");
        Add_Step_WaitUntil("both are released", n"Check_BothReleased", k_SlowPolls, 0);
        Add_Step("each counted the exit once", n"Step_AssertCountedTwice");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SetUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_First.Has_Fragment(FMars_Tag_Occupancy_NeedsSetup) == false && _Second.Has_Fragment(FMars_Tag_Occupancy_NeedsSetup) == false);
    }

    UFUNCTION()
    private void Step_AssertLink(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_First.Get_Trigger() == _Second.Get_Trigger(), "both count through the same trigger");

        const auto& Link = _Trigger.Get_Fragment(FMars_Fragment_Occupancy_TriggerLink);
        Assert_Equals_Int(Link.Occupancies.Num(), 2, "the trigger links both occupancies");
        Assert_True(Link.IsBound, "the trigger's signals are bound");

        const auto& Signals = _Trigger.Get_Fragment(FMars_Fragment_Trigger_Signals);
        Assert_True(Signals.OnEntityEntered._Inner.IsBound(), "OnEntityEntered has a listener");
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
    private void Check_BothActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_First.Get_IsActive() && _Second.Get_IsActive());
    }

    UFUNCTION()
    private void Step_AssertCountedOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_First.Get_Count(), 1, "the first counts one");
        Assert_Equals_Int(_Second.Get_Count(), 1, "the second counts one");
        Assert_Equals_Int(_FirstCountChanges, 1, "the first broadcast OnCountChanged once");
        Assert_Equals_Int(_SecondCountChanges, 1, "the second broadcast OnCountChanged once");
    }

    UFUNCTION()
    private void Check_BothReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_First.Get_IsActive() == false && _Second.Get_IsActive() == false);
    }

    UFUNCTION()
    private void Step_AssertCountedTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FirstCountChanges, 2, "the first broadcast OnCountChanged twice in all");
        Assert_Equals_Int(_SecondCountChanges, 2, "the second broadcast OnCountChanged twice in all");
    }

    UFUNCTION()
    private void OnFirstCountChanged(FCk_Handle_Occupancy InOccupancy, int32 InCount)
    {
        ++_FirstCountChanges;
    }

    UFUNCTION()
    private void OnSecondCountChanged(FCk_Handle_Occupancy InOccupancy, int32 InCount)
    {
        ++_SecondCountChanges;
    }
}
