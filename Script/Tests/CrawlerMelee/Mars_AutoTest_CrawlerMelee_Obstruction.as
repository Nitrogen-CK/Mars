// What stands in the strike's path decides the attack, and only the target's own hurtbox can take damage. The target's
// near face is 38 cm ahead of the neutral hit centre, where an unobstructed strike reaches it; the crawler's own body and
// leg hurtboxes overlap the hit sphere throughout and never count. Three attacks in turn:
//   1. a static Jolt wall between the crawler and the target (24..30 cm ahead): the strike is Obstructed, the attack
//      eases back through CancelRecover, no damage request;
//   2. instead of the wall, another creature's hurtbox (an untagged damageable, 30..36 cm ahead): Obstructed again, the
//      bystander is not hit, and the combat target stays the target (no retargeting);
//   3. nothing in the way, but the target's zone is disabled during Windup: the target is lost (TargetLost), no damage.
class UMars_AutoTest_CrawlerMelee_Obstruction : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-220000.0, -150000.0, 600.0);

    private FCk_Handle _Wall;
    private FMars_AutoTest_CrawlerMelee_Target _Bystander;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn the target and a wall in front of it", n"Step_SpawnTargetAndWall");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step_WaitUntil("the wall blocks a sweep toward the target", n"Check_WallTraceable", k_SlowPolls, 0);
        Add_Step("(1) select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("(1) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("(1) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("(1) the wall obstructed the strike; remove the wall, place a bystander", n"Step_AssertWallAndPlaceBystander");
        Add_Step_WaitUntil("(2) the bystander's hurtbox blocks a sweep toward the target", n"Check_BystanderTraceable", k_SlowPolls, 0);
        Add_Step("(2) request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("(2) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("(2) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds("(2) settle 0.5 s", 0.5f);
        Add_Step("(2) the bystander obstructed the strike unhurt; remove it", n"Step_AssertBystander");
        Add_Step_WaitFrames("(3) let the bystander go", 5);
        Add_Step("(3) request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("(3) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("(3) disable the target's zone during Windup", n"Step_DisableZone");
        Add_Step_WaitUntil("(3) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds("(3) settle 0.5 s", 0.5f);
        Add_Step("(3) the disabled target was lost, not damaged", n"Step_AssertDisabled");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTargetAndWall(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 38.0, FVector(10.0, 20.0, 20.0));
        _Wall = SpawnWallAt(InHandle, Get_FacingTransform(Get_PointAhead(27.0, 0.0)), FVector(3.0, 60.0, 60.0));
    }

    // A sweep along the strike axis through the block point hits the expected entity first.
    private bool Get_IsBlockedBy(FCk_Handle InHandle, FCk_Handle InExpected, ECk_ProbeTrace_HitKind InKind)
    {
        auto Settings = Make_HitQuery(Get_PointAhead(0.0, 0.0), Get_PointAhead(60.0, 0.0), 5.0f);
        Settings.Set_IgnoredEntities(_Crawler.Get_AttackIgnoredEntities());
        const auto Result = utils_probe_trace::Request_SingleShapeTrace(InHandle, Settings);
        return Result.Get_HitKind() == InKind && Result.Get_HitEntity() == InExpected;
    }

    UFUNCTION()
    private void Check_WallTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsBlockedBy(InHandle, _Wall, ECk_ProbeTrace_HitKind::World));
    }

    UFUNCTION()
    private void Check_BystanderTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsBlockedBy(InHandle, _Bystander.Hurtbox, ECk_ProbeTrace_HitKind::Probe));
    }

    private void Assert_ObstructedWithoutDamage(FString InLabel)
    {
        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::Obstructed,
            f"{InLabel}: the strike was Obstructed (last cancel {Get_LastCancelText()}, phases{Get_PhaseText(_RecordMark)})");
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover) >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Recover) < 0,
            f"{InLabel}: the attack eased back through CancelRecover, never Recover (phases{Get_PhaseText(_RecordMark)})");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, f"{InLabel}: no damage request was sent");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, f"{InLabel}: the target is untouched");
    }

    UFUNCTION()
    private void Step_AssertWallAndPlaceBystander(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_ObstructedWithoutDamage("(1) wall");

        utils_entity_lifetime::Request_DestroyEntity(_Wall);
        _Bystander = SpawnBystanderAt(InHandle, Get_FacingTransform(Get_PointAhead(33.0, 0.0)), FVector(3.0, 25.0, 25.0));
    }

    UFUNCTION()
    private void Step_AssertBystander(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_ObstructedWithoutDamage("(2) bystander");
        Assert_Equals_Int(_Bystander.Zone.Get_HitCount(), 0, "(2) the bystander's zone was not hit");
        Assert_Equals_Float(_Bystander.Health.Get_Current(), 100.0f, 0.01f, "(2) the bystander is untouched");
        Assert_True(_Crawler.Get_CombatTarget() == _Target.Entity, "(2) the combat target is still the target: no retargeting");

        utils_entity_lifetime::Request_DestroyEntity(_Bystander.Entity);
    }

    UFUNCTION()
    private void Step_DisableZone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Windup, f"(3) the zone is disabled during Windup (phase {_Crawler.Get_AttackPhase() :n})");
        auto Zone = _Target.Zone;
        Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Step_AssertDisabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::TargetLost,
            f"(3) the disabled target was lost (last cancel {Get_LastCancelText()}, phases{Get_PhaseText(_RecordMark)})");
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::Strike) < 0, f"(3) the attack never reached Strike (phases{Get_PhaseText(_RecordMark)})");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "(3) no damage request was sent");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "(3) the target is untouched");
    }
}
