// The target stands inside a sealed static cage baked into the flight volume, so the bat's strike point over it is free
// space no route reaches: the route reports an explicit failure (Unreachable, or another explicit route outcome), the bat
// drops the target and heads home, and never jumps (no frame moves it further than flight can).
class UMars_AutoTest_Bat_BlockedRouteReportsOutcomeAndReturnsHome : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -162000.0, 2000.0);

    // No frame may move the bat further than this (cruise speed is 380 cm/s).
    private const float64 k_MaxStep = 100.0;

    private float64 _MaxStep = 0.0;
    private TOptional<FVector> _LastLocation;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);

        // Interior 700 x 700 x 600 round (600, 0), walls 40 thick, standing on the floor.
        const auto Centre = _Origin + FVector(600.0, 0.0, 0.0);
        SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, Centre + FVector(-370.0, 0.0, 300.0)), FVector(20.0, 390.0, 300.0));
        SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, Centre + FVector(370.0, 0.0, 300.0)), FVector(20.0, 390.0, 300.0));
        SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, Centre + FVector(0.0, -370.0, 300.0)), FVector(390.0, 20.0, 300.0));
        SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, Centre + FVector(0.0, 370.0, 300.0)), FVector(390.0, 20.0, 300.0));
        SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, Centre + FVector(0.0, 0.0, 620.0)), FVector(390.0, 390.0, 20.0));
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step("the bat's motion is watched", n"Step_Watch");
        Add_Step_WaitUntil("the route fails explicitly and it heads home", n"Check_Returned", 0, k_FlightSeconds);
        Add_Step("the failure was explicit and nothing jumped", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Watch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Bat))
        { return; }

        const auto Here = _Bat.Get_Location();
        if (_LastLocation.IsSet())
        { _MaxStep = Math::Max(_MaxStep, (Here - _LastLocation.GetValue()).Size()); }

        _LastLocation = Here;
    }

    private bool Get_HasExplicitFailure() const
    {
        for (auto Outcome : _Outcomes)
        {
            if (utils_bat::Get_IsRouteFailure(Outcome))
            { return true; }
        }

        return false;
    }

    UFUNCTION()
    private void Check_Returned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Approaching);
        Order.Add(EMars_Bat_Phase::Returning);
        Res.Set(Get_HasExplicitFailure() && Get_SawInOrder(Order));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Outcomes = FString();
        for (auto Outcome : _Outcomes)
        { Outcomes += f"{Outcome} "; }

        const auto Explicit = _Outcomes.Contains(EMars_Bat_RouteOutcome::Unreachable) || _Outcomes.Contains(EMars_Bat_RouteOutcome::EndpointUnresolvable) ||
            _Outcomes.Contains(EMars_Bat_RouteOutcome::GoalBlocked) || _Outcomes.Contains(EMars_Bat_RouteOutcome::GoalFailed);
        Log(f"[BatTest] blocked route: outcomes [{Outcomes}], max frame step {_MaxStep} uu, phases [{Get_PhaseTrail()}]");
        Assert_True(Explicit, f"the route to the caged target failed with an explicit outcome (got {Outcomes})");
        Assert_True(_MaxStep <= k_MaxStep, f"no frame moved it more than {k_MaxStep} uu (max {_MaxStep})");
        Assert_Equals_Int(_TargetDamaged, 0, "the caged target took nothing");
        Assert_False(Get_SawPhase(EMars_Bat_Phase::Swooping), f"it never swooped (saw {Get_PhaseTrail()})");
        Assert_True(_Bat.Get_Location().X - _Origin.X < 230.0, "it never got inside the cage");
    }
}
