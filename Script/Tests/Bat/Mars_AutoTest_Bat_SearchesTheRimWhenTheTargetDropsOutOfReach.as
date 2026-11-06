// The target drops under the floor after the first swoop lands (still within HomeRadius, now out of the flight volume):
// the remembered place is where the previous sense saw it on the ground, not the hole, so the bat searches the rim it
// can fly to, finds nothing (the target stays out of AcquireRadius down there) and goes home.
class UMars_AutoTest_Bat_SearchesTheRimWhenTheTargetDropsOutOfReach : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(320000.0, -210000.0, 2000.0);

    private const float32 k_SearchSeconds = 2.0f;
    private const float64 k_Drop = 1200.0;
    private FVector _Rim;
    private TOptional<FVector> _Remembered;

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
        Add_Step("the target drops under the floor", n"Step_DropTarget");
        Add_Step_WaitUntil("it searches the rim", n"Check_Searching", 0, 10.0f);
        Add_Step_WaitUntil("it gives the search up and returns", n"Check_Returning", 0, k_SearchSeconds + 10.0f);
        Add_Step_WaitUntil("it roosts again", n"Check_Roosting", 0, k_FlightSeconds);
        Add_Step("it searched the rim, not the hole", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Landed.Num() >= 1);
    }

    UFUNCTION()
    private void Step_DropTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Rim = utils_transform::Get_EntityCurrentLocation(_TargetRoot);
        MoveTarget(FVector(600.0, 0.0, -k_Drop));
    }

    UFUNCTION()
    private void Check_Searching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Bat.Get_Phase() == EMars_Bat_Phase::Searching && _Bat.Get_HasLastKnown() && _Remembered.IsSet() == false)
        { _Remembered = _Bat.Get_LastKnown(); }

        Res.Set(_Remembered.IsSet());
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
        const auto Remembered = _Remembered.GetValue();
        Log(f"[BatTest] remembered {Remembered.ToString()} for a rim at {_Rim.ToString()}; phases {Get_PhaseTrail()}");
        Assert_True(Get_SawInOrder(Get_ExpectedOrder()), f"it swooped, searched, returned and roosted in that order (saw {Get_PhaseTrail()})");
        Assert_True((Remembered - _Rim).Size() < 150.0, f"it remembered the rim (kept {Remembered.ToString()}, rim {_Rim.ToString()})");
        Assert_True(Remembered.Z > _Rim.Z - 1.0, "the remembered place is not down the hole");
        Assert_False(_Bat.Get_HasLastKnown(), "the rim is forgotten");
        Assert_False(_Bat.Get_HasTarget(), "it holds no target");
        Assert_Equals_Int(_Landed.Num(), 1, "only the first swoop landed");
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
