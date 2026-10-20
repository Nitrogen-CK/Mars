// After a pincer strike the crawler walks as it did before it. An aggressive crawler playing the reference pincer clip attacks a target 300 cm ahead;
// the target is then replaced by one 350 cm off to its side, which the crawler has to turn to, walk to and strike. While
// it walks there every leg steps (the two that struck included), every leg takes part in the gait, and no foot is left
// further from its hip than its chain reaches.
class UMars_AutoTest_CrawlerMelee_PincerThenWalks : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-250000.0, -180000.0, 600.0);

    protected bool _WithPincer = true;
    protected int32 _LegCount = 4;
    // The layout's own reference clips, as the sandbox wears them.
    protected EMars_Crawler_Layout _Layout = EMars_Crawler_Layout::Radial;
    // Switches aggression off as the first attack enters Strike (its claws at the windup key, in the air): the Disabled
    // cancel skips the eased recovery, so the action is cancelled where it stands and the gait has to take the legs back
    // from there. Aggression is switched back on with the second target.
    protected bool _CancelFirstAttackMidAir = false;

    private const FVector k_HalfExtents = FVector(35.0, 25.0, 25.0);
    private const float64 k_BoundSeconds = 25.0;
    private const float64 k_MaxStretch = 1.02;

    private TArray<FCk_Handle_ProceduralLeg> _Legs;
    private TArray<FVector> _HipsLocal;
    private TArray<float64> _Reaches;

    // Sampled every frame from the moment the second target appears.
    private bool _Sampling = false;
    private TArray<ECk_ProceduralLeg_FootPhase> _LastPhases;
    private TArray<int32> _LegSteps;
    private TArray<float64> _MaxStretch;
    private int32 _FramesOutOfGait = 0;
    private FString _FirstOutOfGait = "";
    private FVector _RootAtSecondTarget;

    // The walker's return watchdog is 1 s; this is several of them at lane frame rate.
    private const int32 k_ReturnPolls = 1200;
    private int32 _ReturnPolls = 0;
    private bool _CancelSent = false;
    private int32 _ClawsAtFirstStrike = -1;
    private float64 _SpawnedAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_AggressiveCrawlerSpec(_LegCount);
        Spec.Layout = _Layout;
        Wear_ReferenceLoadout(Spec, _WithPincer ? EMars_Crawler_AttackClipKind::Pincer : EMars_Crawler_AttackClipKind::Jab);
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("spawn a tagged hostile 300 cm ahead", n"Step_SpawnFirstTarget");
        Add_Step_WaitUntil("the first attack lands (or is cancelled in the air) within 25 s", n"Check_FirstAttackDone", 4000, 0);
        Add_Step_WaitUntil("that attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gait has every leg back", n"Check_LegsReturned", 4000, 0);
        Add_Step("replace the target by one 350 cm to the side and watch the legs", n"Step_SpawnSecondTarget");
        Add_Step_WaitUntil("the second target takes a hit within 25 s", n"Check_Hit", 4000, 0);
        Add_Step("the crawler walked there on every leg", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnFirstTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const TArray<FCk_ProceduralLeg_Spec> LegSpecs = _Crawler.Get_Spec().Get_RigData().Get_Legs();
        const auto Parts = _Crawler.Get_LegParts();
        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            FCk_Handle LegEntity = Parts[Index];
            _Legs.Add(LegEntity.As_ProceduralLeg());
            _HipsLocal.Add(LegSpecs[Index].Get_Placement().Get_HipLocal());
            _Reaches.Add(utils_crawler::Get_ChainReach(LegSpecs[Index]));
            _LastPhases.Add(ECk_ProceduralLeg_FootPhase::Planted);
            _LegSteps.Add(0);
            _MaxStretch.Add(0.0);
        }

        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnSampleTick"));
        _Crawler.BindTo_OnAttackPhaseChanged(FMars_Delegate_Crawler_OnAttackPhaseChanged(this, n"OnWalkPhaseChanged"));

        _RecordMark = _Records.Num();
        _SpawnedAt = System::GetGameTimeInSeconds();
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointFromRoot(300.0, 0.0)), k_HalfExtents);
    }

    UFUNCTION()
    private void OnWalkPhaseChanged(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew)
    {
        if (InNew != EMars_Crawler_AttackPhase::Strike || _ClawsAtFirstStrike >= 0)
        { return; }

        _ClawsAtFirstStrike = InCrawler.Get_AttackPlan().Entry.Slots.Num();
        if (_CancelFirstAttackMidAir)
        {
            _CancelSent = true;
            _Crawler.Request_SetAggression(FMars_Request_Crawler_SetAggression(ECk_EnableDisable::Disable));
        }
    }

    UFUNCTION()
    private void Step_SpawnSecondTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Target.Entity);

        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        { _LastPhases[Index] = utils_procedural_leg::Get_Foot(_Legs[Index]).Get_Phase(); }

        _RootAtSecondTarget = BodyLocation();
        _Sampling = true;
        _SpawnedAt = System::GetGameTimeInSeconds();
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointFromRoot(0.0, 350.0)), k_HalfExtents);

        if (_CancelSent)
        { _Crawler.Request_SetAggression(FMars_Request_Crawler_SetAggression(ECk_EnableDisable::Enable)); }
    }

    private FCk_ProceduralLimbControl_Observation Get_Control(int32 InLeg) const
    {
        return _Crawler.Get_Articulation().Get_LimbControl(utils_procedural_leg::Get_Id(_Legs[InLeg]));
    }

    UFUNCTION()
    private void OnSampleTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_Sampling == false || ck::Is_NOT_Valid(_Crawler))
        { return; }

        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        const auto Attacking = _Crawler.Get_AttackPhase() != EMars_Crawler_AttackPhase::Idle;

        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        {
            const auto Foot = utils_procedural_leg::Get_Foot(_Legs[Index]);
            if (Foot.Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted && _LastPhases[Index] == ECk_ProceduralLeg_FootPhase::Swinging)
            { ++_LegSteps[Index]; }
            _LastPhases[Index] = Foot.Get_Phase();

            const auto Stretch = (Foot.Get_Position() - Root.TransformPosition(_HipsLocal[Index])).Size() / _Reaches[Index];
            _MaxStretch[Index] = Math::Max(_MaxStretch[Index], Stretch);

            if (Attacking)
            { continue; }

            const auto Control = Get_Control(Index);
            if (Control.Get_State() != ECk_ProceduralLimbControl_State::Default || Control.Get_Participating() == false)
            {
                ++_FramesOutOfGait;
                if (_FirstOutOfGait.IsEmpty())
                { _FirstOutOfGait = f"leg {Index}: control {Control.Get_State() :n}, participating {Control.Get_Participating()}, trusted {Control.Get_TrustedSupport()}, reason {Control.Get_Reason()}"; }
            }
        }
    }

    private FString Get_LegText() const
    {
        FString Text = "";
        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        {
            const auto Foot = utils_procedural_leg::Get_Foot(_Legs[Index]);
            const auto Control = Get_Control(Index);
            Text = f"{Text} [leg {Index}: {_LegSteps[Index]} steps, max stretch {_MaxStretch[Index] :.2}, {Foot.Get_Phase() :n}, {utils_procedural_leg::Get_Status(_Legs[Index]) :n}, control {Control.Get_State() :n} participating {Control.Get_Participating()} reason {Control.Get_Reason()}]";
        }
        return Text;
    }

    private FString Get_Diagnostics() const
    {
        const auto Gait = _Crawler.Get_Gait();
        return f"claws at the first strike {_ClawsAtFirstStrike}, sampling {_Sampling}, moved {(BodyLocation() - _RootAtSecondTarget).Size2D() :.1} cm, phases{Get_PhaseText(_RecordMark)}, last cancel {Get_LastCancelText()}, last reject {Get_LastRejectText()}, gait {utils_procedural_gait::Get_Status(Gait) :n} with {utils_procedural_gait::Get_EnabledLegCount(Gait)} enabled and {utils_procedural_gait::Get_PlantedCount(Gait)} planted, legs{Get_LegText()}, out of gait [{_FirstOutOfGait}] for {_FramesOutOfGait} leg-frames; {Get_CrawlerDiagnostics()}";
    }

    private bool Get_IsOverdue()
    {
        if (System::GetGameTimeInSeconds() - _SpawnedAt <= k_BoundSeconds)
        { return false; }

        FinishFailure(f"nothing happened within {k_BoundSeconds :.0} s ({Get_Diagnostics()})");
        return true;
    }

    UFUNCTION()
    private void Check_FirstAttackDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_IsOverdue())
        { return; }

        auto Res = OutResult;
        Res.Set(_CancelFirstAttackMidAir ? _CancelSent : _Target.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void Check_LegsReturned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_ReturnPolls;
        if (_ReturnPolls > k_ReturnPolls)
        {
            FinishFailure(f"the gait did not have every leg back {k_ReturnPolls} polls after the attack reached Idle ({Get_Diagnostics()})");
            return;
        }

        auto Returned = true;
        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        {
            const auto Control = Get_Control(Index);
            Returned = Returned && Control.Get_State() == ECk_ProceduralLimbControl_State::Default && Control.Get_Participating();
        }

        auto Res = OutResult;
        Res.Set(Returned);
    }

    UFUNCTION()
    private void Check_Hit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_IsOverdue())
        { return; }

        auto Res = OutResult;
        Res.Set(ck::IsValid(_Target.Health) && _Target.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Sampling = false;

        Assert_Equals_Int(_ClawsAtFirstStrike, _WithPincer ? 2 : 0, "the first attack claimed the pincer's two legs, or none without a pincer");

        const auto Walked = (BodyLocation() - _RootAtSecondTarget).Size2D();
        Assert_True(Walked > 100.0, f"the crawler walked to the second target (moved {Walked :.1} cm)");

        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        {
            Assert_True(_LegSteps[Index] >= 2, f"leg {Index} stepped on the way (legs{Get_LegText()})");
            Assert_True(_MaxStretch[Index] <= k_MaxStretch, f"leg {Index}'s foot stayed within its chain's reach of its hip (legs{Get_LegText()})");
        }

        Assert_Equals_Int(_FramesOutOfGait, 0, f"outside the attacks every leg was the gait's (first seen: [{_FirstOutOfGait}])");
    }
}
