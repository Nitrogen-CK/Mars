// Hit-and-run: a blow under StunDamage while the bat telegraphs interrupts the swoop and flinches it (Hit); once the
// flinch ends it pulls back from the target (Retreating, to RetreatDistance from the aim point) instead of flying straight
// back in, and only then approaches and swoops again.
class UMars_AutoTest_Bat_RetreatsAfterABlowThenAttacksAgain : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -204000.0, 2000.0);

    private float64 _DistanceAtHit = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("it telegraphs a swoop", n"Check_Telegraphing", 0, k_FlightSeconds);
        Add_Step("a blow lands on it", n"Step_Hit");
        Add_Step_WaitUntil("it flinches and pulls back", n"Check_Retreating", 0, 5.0f);
        Add_Step_WaitUntil("its retreat ends", n"Check_RetreatEnded", 0, 5.0f);
        Add_Step_WaitUntil("it attacks again and the blow lands", n"Check_Landed", 0, k_FlightSeconds);
        Add_Step("it retreated before attacking again", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Telegraphing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Bat) && _Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::Telegraphing);
    }

    UFUNCTION()
    private void Step_Hit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DistanceAtHit = Get_DistanceToTarget();
        HitBat(5.0f);
    }

    UFUNCTION()
    private void Check_Retreating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Retreating);
    }

    UFUNCTION()
    private void Check_RetreatEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FirstRetreatEnd.IsSet());
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Landed.Num() >= 1);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto TargetLocation = utils_transform::Get_EntityCurrentLocation(_TargetRoot);
        const auto DistanceAtRetreatEnd = (TargetLocation - _FirstRetreatEnd.GetValue()).Size();
        Log(f"[BatTest] distance to the target at the hit {_DistanceAtHit}, at the retreat's end {DistanceAtRetreatEnd}; phases {Get_PhaseTrail()}");
        Assert_True(_Cancels.Contains(EMars_Bat_SwoopCancel::Interrupted), "the telegraphed swoop was Interrupted by the blow");
        Assert_True(Get_SawInOrder(Get_ExpectedOrder()), f"it flinched, retreated, approached and swooped in that order (saw {Get_PhaseTrail()})");
        Assert_True(DistanceAtRetreatEnd > _DistanceAtHit + 100.0,
            f"the retreat took it further from the target ({DistanceAtRetreatEnd} vs {_DistanceAtHit} at the hit)");
        Assert_Equals_Int(_Landed.Num(), 1, "the second attack landed once");
        Assert_Equals_Int(_Bat.Get_Hurt().HitCount, 1, "it took one blow");
    }

    private TArray<EMars_Bat_Phase> Get_ExpectedOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Telegraphing);
        Order.Add(EMars_Bat_Phase::Hit);
        Order.Add(EMars_Bat_Phase::Retreating);
        Order.Add(EMars_Bat_Phase::Approaching);
        Order.Add(EMars_Bat_Phase::Swooping);
        return Order;
    }
}
