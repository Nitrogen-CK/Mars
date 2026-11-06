// The bat's entity is destroyed while it flies at a target: nothing ensures, the roost it held is released exactly once
// (the roost notices its claimant going), the bat reports nothing after it is gone, and nothing is dealt.
class UMars_AutoTest_Bat_TeardownReleasesBindingsOnce : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -150000.0, 2000.0);

    private int32 _PhasesAtTeardown = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("it flies at the target", n"Check_Approaching", 0, k_FlightSeconds);
        Add_Step("the bat is destroyed in flight", n"Step_Destroy");
        Add_Step_WaitUntil("the bat is gone and its roost free", n"Check_Gone", 0, 5.0f);
        Add_Step("released once, nothing after", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Approaching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Bat) && _Bat.Get_Phase() == EMars_Bat_Phase::Approaching && _Bat.Get_Telemetry().Speed > 10.0f);
    }

    UFUNCTION()
    private void Step_Destroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhasesAtTeardown = _Phases.Num();
        FCk_Handle Entity = _Bat;
        utils_entity_lifetime::Request_DestroyEntity(Entity);
    }

    UFUNCTION()
    private void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        FCk_Handle Entity = _Bat;
        Res.Set(ck::Is_NOT_Valid(Entity) && utils_bat::Get_RoostState(_Roost).Occupancy == EMars_BatRoost_Occupancy::Free);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Roost = utils_bat::Get_RoostState(_Roost);
        Assert_Equals_Int(Roost.ClaimCount, 1, "the roost was claimed once");
        Assert_Equals_Int(Roost.ReleaseCount, 1, "the roost was released once");
        Assert_Equals_Int(_Phases.Num(), _PhasesAtTeardown, "no phase change was reported after the teardown");
        Assert_Equals_Int(_TargetDamaged, 0, "nothing was dealt");
    }
}
