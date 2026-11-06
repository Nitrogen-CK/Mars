// The target steps out of the bat's LoseRadius after the first swoop lands (still within HomeRadius): the kernel keeps
// where it was last sensed, the bat flies there (Searching), and when the target is gone for good it circles the place
// for SearchSeconds, forgets it and goes home to its roost. Acquire and lose radii are pulled in to 900 so the hop out
// of range stays inside the flight volume.
class UMars_AutoTest_Bat_SearchesTheLastKnownPlaceThenGivesUp : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(320000.0, -192000.0, 2000.0);

    private const float32 k_SearchSeconds = 2.0f;
    private FVector _LostAt;
    private float64 _ClosestToSearchPoint = 1.0e9;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        _Spec.Sensing.AcquireRadius = 900.0f;
        _Spec.Sensing.LoseRadius = 900.0f;
        _Spec.Sensing.SearchSeconds = k_SearchSeconds;
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("its first swoop lands", n"Check_Landed", 0, k_FlightSeconds);
        Add_Step("the target steps out of range", n"Step_MoveTargetAway");
        Add_Step_WaitUntil("it searches where the target was last sensed", n"Check_Searching", 0, 10.0f);
        Add_Step("the target is gone for good", n"Step_DestroyTarget");
        Add_Step_WaitUntil("it reaches the search point", n"Check_Arrived", 0, k_FlightSeconds);
        Add_Step_WaitUntil("it gives the search up and returns", n"Check_Returning", 0, k_SearchSeconds + 4.0f);
        Add_Step_WaitUntil("it roosts again", n"Check_Roosting", 0, k_FlightSeconds);
        Add_Step("it searched the last-known place, then forgot it", n"Step_Assert");
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
        _LostAt = Get_TargetLocation(FVector(-700.0, 700.0, 0.0));
    }

    UFUNCTION()
    private void Check_Searching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Searching && _Bat.Get_HasLastKnown());
    }

    UFUNCTION()
    private void Step_DestroyTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastKnown = _Bat.Get_LastKnown();
        Assert_True(LastKnown.IsSet() && (LastKnown.GetValue() - _LostAt).Size() < 1.0,
            f"the last-known place is where the target went (kept {LastKnown.GetValue().ToString()}, went {_LostAt.ToString()})");
        DestroyTarget();
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto SearchPoint = _LostAt + FVector(0.0, 0.0, _Spec.Swoop.AimHeight + _Spec.Swoop.Height);
        _ClosestToSearchPoint = Math::Min(_ClosestToSearchPoint, (SearchPoint - _Bat.Get_Location()).Size());
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Searching && _Bat.Get_Fragment(FMars_Fragment_Bat_SearchBlackboard).ArrivedClock.IsSet());
    }

    UFUNCTION()
    private void Check_Returning(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Returning);
    }

    UFUNCTION()
    private void Check_Roosting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[BatTest] closest to the search point {_ClosestToSearchPoint}; phases {Get_PhaseTrail()}");
        Assert_True(Get_SawInOrder(Get_ExpectedOrder()), f"it swooped, searched, returned and roosted in that order (saw {Get_PhaseTrail()})");
        Assert_True(_ClosestToSearchPoint <= float64(_Spec.Swoop.Standoff) + utils_bat::StrikeTolerance,
            f"it came within the standoff circle of the search point (closest {_ClosestToSearchPoint})");
        Assert_False(_Bat.Get_HasLastKnown(), "the last-known place is forgotten");
        Assert_False(_Bat.Get_HasTarget(), "it holds no target");
        Assert_Equals_Int(_Landed.Num(), 1, "only the first swoop landed");
        Assert_Equals_Int(_TargetDamaged, 1, "the target was hit once");
    }

    private TArray<EMars_Bat_Phase> Get_ExpectedOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Swooping);
        Order.Add(EMars_Bat_Phase::Searching);
        Order.Add(EMars_Bat_Phase::Returning);
        Order.Add(EMars_Bat_Phase::Roosting);
        return Order;
    }
}
