// A root that turns away from the committed direction mid-attack cancels the attack instead of sweeping on. As Strike
// begins the crawler is steered, at zero speed, 90 degrees to its right through SurfaceMotion (the root's only
// mover): once the root's heading is beyond FacingToleranceDegrees from the direction committed at admission, the next
// accepted sample is Displaced and never swept, the attack eases back through CancelRecover, and no sweep of the attack is
// longer than MaxSampleTravel. The target stands out of reach (near face 55 cm ahead), so no hit races the turn.
//
// A positional jump is not driven here: utils_transform::Request_SetTransform on the root of a SurfaceMotion body does
// not move it, SurfaceMotion being the sole mover.
class UMars_AutoTest_CrawlerMelee_Displacement : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-250000.0, -150000.0, 600.0);

    private FCk_Handle _TriggerEntity;
    private FVector _ForwardAtStart;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target out of reach; arm a 90 degree zero-speed steer as Strike begins", n"Step_Arm");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds("settle 0.5 s", 0.5f);
        Add_Step("the turn cancelled the attack unswept", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Arm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 55.0, FVector(10.0, 20.0, 20.0));
        _ForwardAtStart = Get_Forward();

        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::StrikeEntered, EMars_TESTONLY_CrawlerMelee_Action::SteerCrawler);
        Trigger.SteerDirection = Get_Right();
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Trigger = _TriggerEntity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger);
        const auto Jab = Get_ResolvedDefinition(GameplayTags::Attack_Mars_Jab);
        const auto TurnedDegrees = Math::RadiansToDegrees(Math::Acos(Math::Clamp(Get_Forward().DotProduct(_ForwardAtStart), -1.0, 1.0)));

        Assert_True(Trigger.Fired, "the crawler was steered as Strike began");
        Assert_True(TurnedDegrees > Jab.Prepare.FacingToleranceDegrees,
            f"the root turned beyond the facing tolerance ({TurnedDegrees :.1} degrees)");

        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::Displaced,
            f"the attack was cancelled as Displaced (last cancel {Get_LastCancelText()}, phases{Get_PhaseText(_RecordMark)})");
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover) >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown) >= 0,
            f"the attack eased back through CancelRecover into Cooldown (phases{Get_PhaseText(_RecordMark)})");
        Assert_True(_Crawler.Get_AttackLongestSweep() <= Get_JabEmitter().MaxSampleTravel,
            f"no sweep was longer than MaxSampleTravel [{Get_JabEmitter().MaxSampleTravel}] (longest {_Crawler.Get_AttackLongestSweep() :.2} cm)");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "no damage request was sent");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "the target is untouched");
    }
}
