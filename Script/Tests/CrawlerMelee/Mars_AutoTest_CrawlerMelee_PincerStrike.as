// A crawler playing the reference pincer clip of its layout (Script/Editor/Mars_CrawlerAttackClips.as, what
// Mars.Crawler.SeedAttackClips writes as the sandbox crawlers' starting clip) strikes with both front legs: its attack's
// action claims the rig's first and last leg, each foot lifts off from where it stood, is at its windup key (thrown up and
// apart) on the windup's accepted endpoint, at its strike key (slammed together in front of the body) on the strike's, the
// left claw mirroring the right, and at its rest foot on the recover's. The body rears with them: it is pitched up by the
// windup key's pitch when Strike is entered and level again when Recover is. The jab underneath is unchanged: the phases
// run in order, the target loses the jab's 15 HP once and nothing cancels the attack. The start is requested once the
// crawler would admit it, since a pincer waits for its other feet to stand (the Stance rejection). Afterwards the gait has
// both legs back: each reads Default control and stands on the ground within one gait step of where it started. Four legs
// here, so the crawler rears on its two rear legs for the strike.
class UMars_AutoTest_CrawlerMelee_PincerStrike : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-220000.0, -180000.0, 600.0);

    protected int32 _LegCount = 4;
    // The layout's own reference pincer clip, as the sandbox wears it.
    protected EMars_Crawler_Layout _Layout = EMars_Crawler_Layout::Radial;
    // How far a foot may land from where it stood once the gait has it back: about one of the layout's gait steps.
    protected float64 _ReplantStep = 30.0;

    private const float64 k_KeyTolerance = 1.0;
    private const float64 k_PitchTolerance = 2.0;
    private const float64 k_GroundTolerance = 2.0;
    private const float64 k_EndpointTimeTolerance = 1.0e-4;

    // Right claw then left: the foot parts, their leg ids and where each foot stood before the attack (body frame).
    private TArray<FCk_Handle_Transform> _Feet;
    private TArray<FName> _LegIds;
    private TArray<FVector> _FeetAtRest;

    // Per phase entered since the attack was requested: both feet in the body frame, right then left.
    private TArray<EMars_Crawler_AttackPhase> _ClawPhases;
    private TArray<FVector> _ClawPoints;
    private int32 _ClawsAtStrike = -1;
    // The presentation's pitch against the root, at rest and on each phase entered.
    private float64 _PitchAtRest = 0.0;
    private TArray<float64> _BodyPitches;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_ArmedCrawlerSpec(_LegCount);
        Spec.Layout = _Layout;
        Wear_ReferenceLoadout(Spec, EMars_Crawler_AttackClipKind::Pincer);
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("record where the two front feet stand and watch the attack's phases", n"Step_RecordFeet");
        Add_Step("spawn a target the strike reaches mid-phase (near face 30 cm ahead of the neutral hit centre)", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_SelectTarget");
        Add_Step_WaitUntil("the crawler would admit a start", n"Check_StartAdmissible", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gait has both front legs back", n"Check_ClawsReturned", k_SlowPolls, 0);
        Add_Step_WaitSeconds("settle 0.5 s", 0.5f);
        Add_Step("the claws were at their keys on each phase's endpoint and the jab still landed once", n"Step_Assert");
        Run_Steps(InHandle);
    }

    private float64 Get_BodyPitch() const
    {
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        const auto Presented = utils_transform::Get_EntityCurrentTransform(_Crawler.Get_Presentation());
        return Presented.GetRelativeTransform(Root).Rotator().Pitch;
    }

    UFUNCTION()
    private void Step_SelectTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Target.Entity));
    }

    UFUNCTION()
    private void Check_StartAdmissible(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Ready = _Crawler.Get_HasPendingCombatRequests() == false && _Crawler.Get_StartRejection(_Target.Entity).IsSet() == false;
        // Enqueue once before the next gait solve can change the claimed feet's stance.
        // Requests and AttackTick run after this timer callback and before ProceduralGait.
        if (Ready) { Step_Start(InHandle, InPayload); }
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // Admissible means both claws are planted: this is where they stand.
        _FeetAtRest.Add(Get_FootInBody(0));
        _FeetAtRest.Add(Get_FootInBody(1));

        _RecordMark = _Records.Num();
        _AdmissionPolls = 0;
        Watch_Accepts();
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
    }

    private FVector Get_FootInBody(int32 InClaw) const
    {
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        return Root.InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(_Feet[InClaw]));
    }

    UFUNCTION()
    private void Step_RecordFeet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Legs = _Crawler.Get_Spec().Rig.Legs;
        _Feet.Add(Legs[0].Foot);
        _Feet.Add(Legs[Legs.Num() - 1].Foot);
        _LegIds.Add(Legs[0].LegId);
        _LegIds.Add(Legs[Legs.Num() - 1].LegId);
        _PitchAtRest = Get_BodyPitch();

        _Crawler.BindTo_OnAttackPhaseChanged(FMars_Delegate_Crawler_OnAttackPhaseChanged(this, n"OnPincerPhaseChanged"));
    }

    UFUNCTION()
    private void OnPincerPhaseChanged(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew)
    {
        _ClawPhases.Add(InNew);
        _ClawPoints.Add(Get_FootInBody(0));
        _ClawPoints.Add(Get_FootInBody(1));
        _BodyPitches.Add(Get_BodyPitch());

        if (InNew != EMars_Crawler_AttackPhase::Strike)
        { return; }

        _ClawsAtStrike = InCrawler.Get_AttackPlan().Entry.Slots.Num();
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));
    }

    UFUNCTION()
    private void Check_ClawsReturned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Subject = _Crawler.Get_Articulation();

        auto Res = OutResult;
        Res.Set(Subject.Get_LimbControl(_LegIds[0]).Get_State() == ECk_ProceduralLimbControl_State::Default &&
            Subject.Get_LimbControl(_LegIds[1]).Get_State() == ECk_ProceduralLimbControl_State::Default);
    }

    // The pitch of the body key the played clip's Windup phase ends on.
    private float64 Get_WindupEndPitch() const
    {
        for (const auto& Phase : _Crawler.Get_AttackClip().Get_Phases())
        {
            if (Phase.Get_Id() == utils_crawler::Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup) && Phase.Get_BodyKeys().Num() > 0)
            { return Phase.Get_BodyKeys().Last().Get_Rotation().Rotator().Pitch; }
        }

        return 0.0;
    }

    // The two feet on the frame that accepted the InPhaseId interval ending at InEndSeconds of the clip (that phase's
    // endpoint); false when no frame did.
    private bool Find_EndpointFeet(FName InPhaseId, float64 InEndSeconds, FVector& OutRight, FVector& OutLeft) const
    {
        for (const auto& Frame : Get_AcceptRecords())
        {
            if (Frame.AcceptedPhaseId != InPhaseId || Math::Abs(Frame.AcceptedTo - InEndSeconds) > k_EndpointTimeTolerance ||
                Frame.FrontFeet.Num() != 2)
            { continue; }

            OutRight = Frame.FrontFeet[0];
            OutLeft = Frame.FrontFeet[1];
            return true;
        }

        return false;
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phases = Get_PhaseText(_RecordMark);

        const auto Native = _Crawler.Get_AttackResult().Native;
        Assert_True(_Records.Num() - _RecordMark == 5 && _Crawler.Get_AttackLastCancel().IsSet() == false,
            f"the attack ran Windup > Strike > Recover > Cooldown > Idle uncancelled (got{Phases}, last cancel {Get_LastCancelText()}, action {Native.Get_Outcome() :n} [{Native.Get_Reason()}], planted feet {utils_procedural_gait::Get_PlantedCount(_Crawler.Get_Gait())}, trusted {utils_procedural_gait::Get_TrustedContactCount(_Crawler.Get_Gait())})");
        Assert_Equals_Int(_ClawsAtStrike, 2, "the attack's action claimed both front legs");
        Assert_True(_Crawler.Get_AttackId() == GameplayTags::Attack_Mars_Pincer, f"the attack played the pincer (got {_Crawler.Get_AttackId().ToString()})");

        // The claws' keys are checked on each phase's endpoint, the frame that accepted the interval ending there: the
        // clip action enters Strike and Recover on their own first accepted interval, which already carries that phase's
        // first motion (InQuad strike: up to about 2.5 cm from the windup key at 60 Hz). The keys are the reference
        // builder's, the clip the crawler plays.
        const auto WindupEnd = Get_AttackPhaseEnd(EMars_Crawler_AttackPhase::Windup);
        const auto StrikeEnd = Get_AttackPhaseEnd(EMars_Crawler_AttackPhase::Strike);
        const auto RecoverEnd = Get_AttackPhaseEnd(EMars_Crawler_AttackPhase::Recover);
        const auto WindupKeys = Get_ReferenceClawKeys(_Layout, EMars_Crawler_AttackPhase::Windup);
        const auto StrikeKeys = Get_ReferenceClawKeys(_Layout, EMars_Crawler_AttackPhase::Strike);
        const auto RestKeys = Get_ReferenceClawKeys(_Layout, EMars_Crawler_AttackPhase::Recover);

        FVector Right;
        FVector Left;
        if (Find_EndpointFeet(n"Windup", WindupEnd, Right, Left))
        {
            Assert_True((Right - WindupKeys.Right).Size() <= k_KeyTolerance && (Left - WindupKeys.Left).Size() <= k_KeyTolerance,
                f"the windup ends with both claws at the windup key (right {Right.ToString()} of {WindupKeys.Right.ToString()}, left {Left.ToString()} of {WindupKeys.Left.ToString()})");
            Assert_True(Right.Z > _FeetAtRest[0].Z + 100.0 && Left.Z > _FeetAtRest[1].Z + 100.0,
                f"the windup throws both feet up over the body (right from {_FeetAtRest[0].Z :.1} to {Right.Z :.1}, left from {_FeetAtRest[1].Z :.1} to {Left.Z :.1})");
        }
        else
        { Assert_True(false, f"no frame accepted the windup's endpoint at [{WindupEnd :.4}] s (got{Phases})"); }

        const auto WindupPitch = Get_WindupEndPitch();
        const auto StrikeIndex = _ClawPhases.FindIndex(EMars_Crawler_AttackPhase::Strike);
        const auto RecoverIndex = _ClawPhases.FindIndex(EMars_Crawler_AttackPhase::Recover);
        if (StrikeIndex >= 0 && RecoverIndex >= 0)
        {
            Assert_True(WindupPitch > 20.0 && Math::Abs(_BodyPitches[StrikeIndex] - _PitchAtRest - WindupPitch) <= k_PitchTolerance,
                f"Strike is entered with the body reared by the windup key's pitch ({_BodyPitches[StrikeIndex] - _PitchAtRest :.2} deg of {WindupPitch :.2})");
            Assert_True(Math::Abs(_BodyPitches[RecoverIndex] - _PitchAtRest) <= k_PitchTolerance,
                f"Recover is entered with the body level again ({_BodyPitches[RecoverIndex] - _PitchAtRest :.2} deg off its rest pitch)");
        }

        if (Find_EndpointFeet(n"Strike", StrikeEnd, Right, Left))
        {
            Assert_True((Right - StrikeKeys.Right).Size() <= k_KeyTolerance && (Left - StrikeKeys.Left).Size() <= k_KeyTolerance,
                f"the strike ends with both claws at the strike key (right {Right.ToString()} of {StrikeKeys.Right.ToString()}, left {Left.ToString()} of {StrikeKeys.Left.ToString()})");
            Assert_True(Math::Abs(Right.Y - Left.Y) < Math::Abs(_FeetAtRest[0].Y - _FeetAtRest[1].Y) * 0.5,
                f"the strike closes the claws (apart {Math::Abs(Right.Y - Left.Y) :.1} cm, {Math::Abs(_FeetAtRest[0].Y - _FeetAtRest[1].Y) :.1} cm at rest)");
        }
        else
        { Assert_True(false, f"no frame accepted the strike's endpoint at [{StrikeEnd :.4}] s (got{Phases})"); }

        // The clip's Recover ends each claw at its leg's rest foot (no longer at the spot the foot stood on at admission,
        // which the clip cannot know); the limb control's return then replants it, checked below.
        if (Find_EndpointFeet(n"Recover", RecoverEnd, Right, Left))
        {
            Assert_True((Right - RestKeys.Right).Size() <= k_KeyTolerance && (Left - RestKeys.Left).Size() <= k_KeyTolerance,
                f"the recover ends with both claws at their rest feet (right {Right.ToString()} of {RestKeys.Right.ToString()}, left {Left.ToString()} of {RestKeys.Left.ToString()})");
        }
        else
        { Assert_True(false, f"no frame accepted the recover's endpoint at [{RecoverEnd :.4}] s (got{Phases})"); }

        const auto RightNow = Get_FootInBody(0);
        const auto LeftNow = Get_FootInBody(1);
        Assert_True(Math::Abs(RightNow.Z - _FeetAtRest[0].Z) <= k_GroundTolerance && Math::Abs(LeftNow.Z - _FeetAtRest[1].Z) <= k_GroundTolerance,
            f"both feet are back on the ground (right {RightNow.Z - _FeetAtRest[0].Z :.2} cm above where it stood, left {LeftNow.Z - _FeetAtRest[1].Z :.2} cm)");
        Assert_True((RightNow - _FeetAtRest[0]).Size2D() <= _ReplantStep && (LeftNow - _FeetAtRest[1]).Size2D() <= _ReplantStep,
            f"both feet replanted within one step of where they stood (right {(RightNow - _FeetAtRest[0]).Size2D() :.2} cm off, left {(LeftNow - _FeetAtRest[1]).Size2D() :.2} cm off)");
        Assert_Equals_Int(utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait()), _LegCount, "every leg is still enabled");
        Assert_True(_Crawler.Get_AttackCleanup().Released && ck::Is_NOT_Valid(_Crawler.Get_AttackAction()), "the attack released its action and with it the claws");

        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the target lost the jab's 15 HP once");
    }
}
