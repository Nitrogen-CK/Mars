// The target steps out of the bat's LoseRadius after the first swoop lands and stays where it went: the search brings
// the bat back within AcquireRadius of it, it is taken up again from the search, approached and swooped a second time.
class UMars_AutoTest_Bat_SearchFindsTheTargetAgain : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(320000.0, -198000.0, 2000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        _Spec.Sensing.AcquireRadius = 900.0f;
        _Spec.Sensing.LoseRadius = 900.0f;
        _Spec.Sensing.SearchSeconds = 3.0f;
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("its first swoop lands", n"Check_Landed", 0, k_FlightSeconds);
        Add_Step("the target steps out of range", n"Step_MoveTargetAway");
        Add_Step_WaitUntil("it searches where the target was last sensed", n"Check_Searching", 0, 10.0f);
        Add_Step_WaitUntil("it finds the target again and its second swoop lands", n"Check_LandedTwice", 0, k_FlightSeconds);
        Add_Step("the search led to the second swoop", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Landed.Num() >= 1);
    }

    UFUNCTION()
    private void Step_MoveTargetAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveTarget(FVector(-700.0, 700.0, 0.0));
    }

    UFUNCTION()
    private void Check_Searching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Searching);
    }

    UFUNCTION()
    private void Check_LandedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Landed.Num() >= 2);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[BatTest] phases {Get_PhaseTrail()}");
        Assert_True(Get_SawInOrder(Get_ExpectedOrder()), f"it swooped, searched, approached and swooped again (saw {Get_PhaseTrail()})");
        Assert_False(_Bat.Get_HasLastKnown(), "the last-known place is forgotten once the target is held again");
        Assert_True(_Bat.Get_HasTarget(), "it holds the target");
        Assert_Equals_Int(_TargetDamaged, 2, "the target was hit twice");
    }

    private TArray<EMars_Bat_Phase> Get_ExpectedOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Swooping);
        Order.Add(EMars_Bat_Phase::Searching);
        Order.Add(EMars_Bat_Phase::Approaching);
        Order.Add(EMars_Bat_Phase::Swooping);
        return Order;
    }
}
