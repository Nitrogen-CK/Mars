// A hostile target stands 600 uu from the point under the roost: the bat wakes (Alert), drops off its perch (Launching),
// flies to its strike point (Approaching), telegraphs, commits one swoop and the blow lands exactly once (one OnDamaged on
// the target, one OnSwoopLanded). The target then steps out of reach: the bat recovers, returns, brakes up to its hang
// point, perches and roosts again, and the target takes no second hit on the way.
class UMars_AutoTest_Bat_RoostsAlertsLaunchesAndSwoopsOnce : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -180000.0, 2000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("it swoops and the blow lands", n"Check_Landed", 0, k_FlightSeconds);
        Add_Step("the target steps out of reach", n"Step_MoveTargetAway");
        Add_Step_WaitUntil("it returns to its perch and roosts again", n"Check_RoostedAgain", 0, k_FlightSeconds);
        Add_Step("one swoop, one result, the whole cycle", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Landed.Num() >= 1 && _TargetDamaged >= 1);
    }

    UFUNCTION()
    private void Step_MoveTargetAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveTarget(FVector(6000.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_RoostedAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto Tail = TArray<EMars_Bat_Phase>();
        Tail.Add(EMars_Bat_Phase::Recovering);
        Tail.Add(EMars_Bat_Phase::Returning);
        Tail.Add(EMars_Bat_Phase::Braking);
        Tail.Add(EMars_Bat_Phase::Perching);
        Tail.Add(EMars_Bat_Phase::Roosting);
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting && Get_SawInOrder(Tail));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Cycle = TArray<EMars_Bat_Phase>();
        Cycle.Add(EMars_Bat_Phase::Roosting);
        Cycle.Add(EMars_Bat_Phase::Alert);
        Cycle.Add(EMars_Bat_Phase::Launching);
        Cycle.Add(EMars_Bat_Phase::Approaching);
        Cycle.Add(EMars_Bat_Phase::Telegraphing);
        // The sortie's first telegraph is named Screeching (presentation only) before it commits.
        Cycle.Add(EMars_Bat_Phase::Screeching);
        Cycle.Add(EMars_Bat_Phase::Swooping);
        Cycle.Add(EMars_Bat_Phase::Recovering);
        Cycle.Add(EMars_Bat_Phase::Returning);
        Cycle.Add(EMars_Bat_Phase::Braking);
        Cycle.Add(EMars_Bat_Phase::Perching);
        Cycle.Add(EMars_Bat_Phase::Roosting);
        Log(f"[BatTest] happy path: phases [{Get_PhaseTrail()}], target hits {_TargetDamaged}, landed {_Landed.Num()}");
        Assert_True(Get_SawInOrder(Cycle), f"the phases ran Roost -> Alert -> Launch -> Approach -> Telegraph -> Screech -> Swoop -> Recover -> Return -> Brake -> Perch -> Roost (saw {Get_PhaseTrail()})");

        Assert_Equals_Int(_TargetDamaged, 1, "the target took exactly one hit");
        Assert_Equals_Int(_Landed.Num(), 1, "OnSwoopLanded fired exactly once");
        Assert_Equals_Int(_Bat.Get_SwoopLedger().Landed, 1, "the ledger counts one landed swoop");
        Assert_Equals_Int(_Bat.Get_SwoopLedger().Generation, 1, "it committed one swoop, and that one landed");
        Assert_Equals_Int(_Cancels.Num(), 0, "no swoop was cancelled");
        Assert_True(_TargetHealth.Get_Current() < 100.0f, "the hit went through the target's Health");
        const auto Off = (_Bat.Get_Location() - Get_HangPoint()).Size();
        Assert_True(Off <= 60.0, f"it hangs at its hang point again ({Off} uu off)");
        Assert_True(_Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Held, "it still holds its roost");
    }
}
