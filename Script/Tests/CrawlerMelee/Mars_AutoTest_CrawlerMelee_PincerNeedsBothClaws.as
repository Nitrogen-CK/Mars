// A pincer crawler that cannot spare both front legs jabs with its body alone. With its right front leg disabled, a
// four-leg crawler still walks (three enabled legs) but lifting two more would leave one standing: the attack's action
// claims no leg, the left front foot is never thrown up toward the windup key (the gait may still step it, a step's
// height off the ground), and the jab still runs its phases and lands its 15 HP once.
class UMars_AutoTest_CrawlerMelee_PincerNeedsBothClaws : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-240000.0, -180000.0, 600.0);

    // The crawler gait's step height is 24 cm; the windup key is 150 cm above the ground.
    private const float64 k_MaxStepRise = 40.0;

    private FCk_Handle_Transform _LeftFoot;
    private FVector _LeftFootAtRest;
    private bool _Watching = false;
    private float64 _LeftFootRise = 0.0;
    private int32 _ClawsAtStrike = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_ArmedCrawlerSpec(4);
        Wear_ReferenceLoadout(Spec, EMars_Crawler_AttackClipKind::Pincer);
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("disable the right front leg", n"Step_DisableRightClaw");
        Add_Step_WaitUntil("three legs remain enabled", n"Check_ThreeLegsEnabled", k_SlowPolls, 0);
        Add_Step_WaitUntil("the crawler has been at rest for 1 s again", n"Check_AtRest", k_SlowPolls, 0);
        Add_Step("record where the left front foot stands and watch the attack's phases", n"Step_RecordFoot");
        Add_Step("spawn a target the strike reaches mid-phase (near face 30 cm ahead of the neutral hit centre)", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        // With a leg disabled the gait re-plants after the body rests: a start requested before the remaining feet stand on
        // trusted support is refused SupportStance and nothing retries it.
        Add_Step("select the target", n"Step_SelectTarget");
        Add_Step_WaitUntil("an attack is ready to start against the target", n"Check_StanceReady", k_SlowPolls, 0);
        Add_Step("request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds("settle 0.5 s", 0.5f);
        Add_Step("the jab ran on the body alone", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DisableRightClaw(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle LegEntity = _Crawler.Get_LegParts()[0];
        utils_procedural_leg::Request_EnableDisable(LegEntity.As_ProceduralLeg(), FCk_Request_ProceduralLeg_EnableDisable(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Check_ThreeLegsEnabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait()) == 3);
    }

    private FVector Get_LeftFootInBody() const
    {
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        return Root.InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(_LeftFoot));
    }

    UFUNCTION()
    private void Step_RecordFoot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Legs = _Crawler.Get_Spec().Rig.Legs;
        _LeftFoot = Legs[Legs.Num() - 1].Foot;
        _LeftFootAtRest = Get_LeftFootInBody();
        _Watching = true;

        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatchTick"));
        _Crawler.BindTo_OnAttackPhaseChanged(FMars_Delegate_Crawler_OnAttackPhaseChanged(this, n"OnPincerPhaseChanged"));
    }

    UFUNCTION()
    private void OnPincerPhaseChanged(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew)
    {
        if (InNew == EMars_Crawler_AttackPhase::Strike)
        { _ClawsAtStrike = InCrawler.Get_AttackPlan().Entry.Slots.Num(); }
    }

    UFUNCTION()
    private void OnWatchTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_Watching && ck::IsValid(_Crawler))
        { _LeftFootRise = Math::Max(_LeftFootRise, Get_LeftFootInBody().Z - _LeftFootAtRest.Z); }
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));
    }

    UFUNCTION()
    private void Step_SelectTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Target.Entity));
    }

    // The crawler's cached decision has a ready choice against this target: some attack (here the body jab; the pincer
    // stays blocked on SupportStance while its claw is disabled) can start now.
    UFUNCTION()
    private void Check_StanceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackEvaluation().Selection.ReadyChoice.IsSet());
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Records.Num() - _RecordMark == 5 && _Crawler.Get_AttackLastCancel().IsSet() == false,
            f"the attack ran Windup > Strike > Recover > Cooldown > Idle uncancelled (got{Get_PhaseText(_RecordMark)}, last cancel {Get_LastCancelText()})");
        Assert_Equals_Int(_ClawsAtStrike, 0, "the attack's action claimed no leg");
        _Watching = false;
        Assert_True(_LeftFootRise <= k_MaxStepRise,
            f"the left front foot never rose past a gait step (it rose {_LeftFootRise :.2} cm)");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the target lost the jab's 15 HP once");
    }
}
