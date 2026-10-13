// The production crawler's jab lands on the production player once: an armed, passive 4-leg crawler spawned through
// UMars_Crawler_EntityScript settles on its floor, the real possessed AMars_PlayerCharacter is spawned standing in front of
// it (capsule 20 cm ahead of the neutral hit centre, within StartDistance), and the crawler's kernel is driven directly
// (SetCombatTarget + StartAttack on the player's entity; no state machine involved). The player's Health goes 100 -> 85
// exactly once, through exactly one damage request on the crawler's dealer, routed by the player's own zone; a second
// StartAttack during Cooldown is rejected Busy. Floor, crawler and settle are the CrawlerMelee rig's recipe
// (Script/Tests/CrawlerMelee/Mars_AutoTestRig_CrawlerMelee.as), copied: this test stands on the PlayerCombat rig.
// Isolated origin (-175000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_ProductionReceiver : UMars_AutoTestRig_PlayerCombat
{
    default _TimeoutSeconds = 45.0f;
    default _Origin = FVector(-175000.0, 210000.0, 8000.0);

    // How far in front of the crawler's neutral hit centre the player's capsule begins: the jab's sphere (radius 20)
    // reaches 44 in front at the end of the strike and 10 at the end of the windup.
    private const float64 k_CapsuleFaceAhead = 20.0;

    private FCk_Handle_Crawler _Crawler;
    private TArray<EMars_Crawler_AttackPhase> _Phases;
    // The radial reference jab the crawler plays (Script/Editor/Mars_CrawlerAttackClips.as), never the authored asset;
    // this property keeps it alive for the spec's soft reference.
    UPROPERTY()
    private UCk_ProceduralAction_Data _JabClip;
    private int32 _AdmissionPolls = 0;
    private float64 _RestSince = -1.0;
    private FVector _RestForward;
    private int32 _HealthChanges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Self = InHandle;
        SpawnFloorAndCrawler(InHandle);

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and every leg part registered", n"Check_CrawlerReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_CrawlerInRoam", k_SlowPolls, 0);
        Add_Step("stop the navigator", n"Step_StopCrawlerNavigator");
        Add_Step_WaitUntil("the navigator has drained the stop and is not Moving", n"Check_CrawlerNavigatorStopped", k_SlowPolls, 0);
        Add_Step_WaitUntil("the crawler has been at rest (speed under 0.5 cm/s, heading within 0.25 deg) for 1 s", n"Check_CrawlerAtRest", k_SlowPolls, 0);
        Add_Step("spawn the possessed player in front of the crawler", n"Step_SpawnPlayer");
        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("the local player composed its combat receiver", n"Step_AssertLocalReceiver");
        Add_Step_WaitUntil("the player's hurtbox is the first hurtbox the crawler's query meets across the player", n"Check_PlayerTraceableByCrawler", k_SlowPolls, 0);
        Add_Step("target the player and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is in Cooldown", n"Check_InCooldown", k_SlowPolls, 0);
        Add_Step("request a second attack during Cooldown", n"Step_StartDuringCooldown");
        Add_Step_WaitUntil("the second request has drained", n"Check_CombatRequestsDrained", k_SlowPolls, 0);
        Add_Step("the second attack was rejected Busy", n"Step_AssertBusy");
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackIdle", k_SlowPolls, 0);
        // Deliberately a fixed window: "exactly once" is a negative; the positive half is the hit already observed.
        Add_Step_WaitSeconds("watch for a second hit", 0.5f);
        Add_Step("the player lost 15 HP once, from one request, through its own zone", n"Step_AssertOneHit");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The crawler (the CrawlerMelee rig's floor, armed spec and settle)
    //----------------------------------------------------------------------------------------------------------------------

    private void SpawnFloorAndCrawler(FCk_Handle InHandle)
    {
        SpawnJoltWall(_Origin - FVector(0.0, 0.0, 10.0), FVector(1500.0, 1500.0, 10.0));

        // Roams +-150 around _Origin but dwells 120 s after a stop, so once stopped it stands still for the whole test.
        auto Spec = FMars_Crawler_Spec(4, FBox(_Origin - FVector(150.0, 150.0, 200.0), _Origin + FVector(150.0, 150.0, 200.0)));
        Spec.RoamDwellSeconds = 120.0f;
        Spec.Combat.Enabled = true;
        // Passive: the behaviour layer never engages, so only this test's direct requests drive the attack.
        Spec.Combat.StartAggressive = ECk_EnableDisable::Disable;
#if EDITOR
        _JabClip = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        const auto Report = utils_crawler::Build_ReferenceClip(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Jab, _JabClip);
        Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            f"the reference jab builds (got [{utils_crawler::Get_FirstDiagnosticText(Report)}])");
        Spec.Combat.JabClip = TSoftObjectPtr<UCk_ProceduralAction_Data>(_JabClip);
#else
        FinishFailure("the crawler's reference clips come from an editor-only builder");
#endif

        auto SpawnParams = UMars_Crawler_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        SpawnParams.Spec = Spec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Crawler_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnCrawlerConstructed"));
    }

    UFUNCTION()
    private void OnCrawlerConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Crawler = InEntityScriptHandle.As_Crawler();
        _Crawler.BindTo_OnAttackPhaseChanged(FMars_Delegate_Crawler_OnAttackPhaseChanged(this, n"OnAttackPhaseChanged"));
    }

    UFUNCTION()
    private void OnAttackPhaseChanged(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew)
    {
        _Phases.Add(InNew);
    }

    UFUNCTION()
    private void OnPlayerDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InCurrent)
    {
        ++_HealthChanges;
    }

    private FVector CrawlerLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(_Crawler.As_Transform());
    }

    private FVector CrawlerForward() const
    {
        return utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform()).GetRotation().GetForwardVector().GetSafeNormal2D();
    }

    private FString Get_LastRejectText() const
    {
        const auto LastReject = _Crawler.Get_AttackLastReject();
        return LastReject.IsSet() ? f"{LastReject.GetValue() :n}" : "none";
    }

    UFUNCTION()
    private void Check_CrawlerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(false);
        if (ck::Is_NOT_Valid(_Crawler))
        { return; }

        const auto Gait = _Crawler.Get_Gait();
        if (utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Failed)
        {
            FinishFailure(f"the crawler's gait failed: {utils_procedural_gait::Get_Failure(Gait) :n}");
            return;
        }

        Res.Set(utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Ready
            && _Crawler.Get_Monster().Get_Parts().Num() == _Crawler.Get_Spec().LegCount);
    }

    UFUNCTION()
    private void Check_CrawlerInRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam);
    }

    UFUNCTION()
    private void Step_StopCrawlerNavigator(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RestSince = -1.0;
        auto Navigator = _Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
    }

    UFUNCTION()
    private void Check_CrawlerNavigatorStopped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Navigator = _Crawler.Get_Navigator();
        auto Res = OutResult;
        Res.Set(Navigator.Get_HasPendingRequests() == false && Navigator.Get_Status() != EMars_SurfaceNavigator_Status::Moving);
    }

    // A stopped crawler keeps turning for a moment after its speed reaches zero, so rest also waits for the heading.
    UFUNCTION()
    private void Check_CrawlerAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Now = System::GetGameTimeInSeconds();
        const auto Forward = CrawlerForward();
        const auto Moving = utils_surface_motion::Get_Velocity(_Crawler.Get_Motion()).Size() > 0.5;
        const auto Turning = _RestSince >= 0.0 && Forward.DotProduct(_RestForward) < Math::Cos(Math::DegreesToRadians(0.25));
        if (Moving)
        { _RestSince = -1.0; }
        else if (_RestSince < 0.0 || Turning)
        {
            _RestSince = Now;
            _RestForward = Forward;
        }

        auto Res = OutResult;
        Res.Set(_RestSince >= 0.0 && Now - _RestSince >= 1.0);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The player in front, and the attack
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_SpawnPlayer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(_Crawler.Get_Presentation());
        const auto NeutralHitCenter = utils_crawler::Get_HitCenter(Presentation, _Crawler.Get_Spec().Combat.Hit.LocalCenter);
        const auto Radius = float64(mars::Mars_PlayerCharacter_Config.Body.CapsuleRadius);
        const auto Centre = NeutralHitCenter + CrawlerForward() * (k_CapsuleFaceAhead + Radius);
        SpawnFloorAndUnpossessedPawnAt(InHandle, FVector(Centre.X, Centre.Y, _Origin.Z));
        PossessPawn();
    }

    // A sweep across the player with the crawler's attack query (its own bodies ignored) meets a hurtbox of the player's zone.
    UFUNCTION()
    private void Check_PlayerTraceableByCrawler(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Centre = PawnLocation();
        const auto Across = FVector::UpVector.CrossProduct(CrawlerForward()) * 200.0;
        auto Settings = FCk_ShapeCast_Settings(Centre - Across, Centre + Across,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(5.0f)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_WorldHitPolicy(ECk_ProbeTrace_WorldHitPolicy::Blocking);
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        Settings.Set_BackFaceModeConvex(ECk_BackFaceMode::CollideWithBackFaces);
        Settings.Set_IgnoredEntities(_Crawler.Get_AttackIgnoredEntities());
        const auto Result = utils_probe_trace::Request_SingleShapeTrace(InHandle, Settings);
        FCk_Handle HitZone = utils_hit_zone::TryGet_Zone(Result.Get_HitEntity());
        FCk_Handle PlayerZone = Get_Zone();

        auto Res = OutResult;
        Res.Set(ck::IsValid(HitZone) && HitZone == PlayerZone);
    }

    // Target and start in one frame, so they drain together.
    UFUNCTION()
    private void Step_TargetAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Health = Get_Health();
        Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnPlayerDamaged"));
        Assert_Equals_Float(Health.Get_Current(), 100.0f, 0.001f, "the player starts at 100");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "the crawler's dealer has drained no request yet");

        _Phases.Empty();
        _AdmissionPolls = 0;
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Player));
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Player));
    }

    // Dealt plus rejected: every damage request the crawler's dealer has drained.
    private int32 Get_DamageRequestCount() const
    {
        const auto Dealer = _Crawler.Get_CombatDealer();
        return Dealer.Get_HitsDealt() + Dealer.Get_HitsRejected();
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Phases.Contains(EMars_Crawler_AttackPhase::Windup))
        {
            Res.Set(true);
            return;
        }

        ++_AdmissionPolls;
        if (_AdmissionPolls > 60 && _Crawler.Get_HasPendingCombatRequests() == false)
        {
            const auto ToPlayer = PawnLocation() - CrawlerLocation();
            const auto FacingError = utils_crawler::Get_PlanarAngleDegrees(CrawlerForward(), ToPlayer, FVector::UpVector);
            FinishFailure(f"the start was not admitted (last reject {Get_LastRejectText()}, phase {_Crawler.Get_AttackPhase() :n}, facing error {FacingError :.2} deg, player {ToPlayer.Size2D() :.1} cm away horizontally, {ToPlayer.Z :.1} cm above the crawler's root)");
        }

        Res.Set(false);
    }

    UFUNCTION()
    private void Check_InCooldown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Cooldown);
    }

    UFUNCTION()
    private void Step_StartDuringCooldown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_Health().Get_Current(), 85.0f, 0.001f, "the strike has landed by Cooldown: the player reads 85");
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Player));
    }

    UFUNCTION()
    private void Check_CombatRequestsDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_HasPendingCombatRequests() == false);
    }

    UFUNCTION()
    private void Step_AssertBusy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastReject = _Crawler.Get_AttackLastReject();
        Assert_True(LastReject.IsSet() && LastReject.GetValue() == EMars_Crawler_AttackReject::Busy,
            f"the second start was rejected Busy (last reject {Get_LastRejectText()}, phase {_Crawler.Get_AttackPhase() :n})");
    }

    UFUNCTION()
    private void Check_AttackIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle);
    }

    UFUNCTION()
    private void Step_AssertOneHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Health = Get_Health();
        Assert_Equals_Float(Health.Get_Current(), 85.0f, 0.001f, "the player's Health reads 85");
        Assert_Equals_Int(_HealthChanges, 1, "the player's Health was damaged exactly once");

        const auto Dealer = _Crawler.Get_CombatDealer();
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "exactly one damage request on the crawler's dealer");
        Assert_Equals_Int(Dealer.Get_HitsDealt(), 1, "the one request was dealt, not rejected");
        Assert_Equals_Int(Get_Zone().Get_HitCount(), 1, "the player's zone routed exactly one hit");

        const auto LastHit = Health.Get_LastHit();
        Assert_True(LastHit.IsSet(), "the player's Health recorded the hit");
        if (LastHit.IsSet())
        {
            const auto Event = LastHit.GetValue();
            FCk_Handle PlayerZone = Get_Zone();
            FCk_Handle CrawlerEntity = _Crawler;
            Assert_True(Event.HitZone == PlayerZone, "the hit was routed by the player's own zone");
            Assert_True(Event.Source.Instigator == CrawlerEntity, "the crawler instigated the hit");
            Assert_True(Event.DamageType == GameplayTags::DamageType_Mars_Blunt, "the hit is the jab's Blunt");
        }

        Assert_True(Get_IsInAlive(), "the player is still Alive at 85 HP");
    }
}

class AMars_AutoTest_PlayerCombat_ProductionReceiver_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 45.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_ProductionReceiver;
}
