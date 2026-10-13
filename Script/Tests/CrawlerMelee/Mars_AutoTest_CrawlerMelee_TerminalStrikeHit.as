// A hit found on Strike's terminal sample still commits, once, before Recover. The target starts out of reach (near face
// 52 cm ahead of the neutral hit centre; the strike reaches 44) and is moved into the strike's path in the frame the
// player stages the strike's terminal interval, so only that sample can reach it. The resolver stores the candidate in
// that frame; the next attack tick commits it, and Recover is entered once its first accepted interval arrives. Recover
// is therefore entered with the hit committed from the strike's terminal sample, and the latch stays set through
// Cooldown: the spent hit budget survives the normal phase change.
class UMars_AutoTest_CrawlerMelee_TerminalStrikeHit : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-190000.0, -150000.0, 600.0);

    private const FVector k_HalfExtents = FVector(10.0, 20.0, 20.0);

    private FCk_Handle _TriggerEntity;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn the target out of reach and arm its move into the path as the strike's terminal sample is staged", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the target's Health has taken the hit", n"Check_TargetHit", k_SlowPolls, 0);
        Add_Step_WaitSeconds("settle 0.5 s", 0.5f);
        Add_Step("the terminal sample's hit committed on the next pass, before Recover, and stayed spent", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 52.0, k_HalfExtents);

        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::StrikeEndpointStaged, EMars_TESTONLY_CrawlerMelee_Action::MoveTarget);
        Trigger.TargetRoot = _Target.Root;
        Trigger.Destination = Get_FacingTransform(Get_PointAhead(30.0 + k_HalfExtents.X, 0.0));
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Check_TargetHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Target.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Trigger = _TriggerEntity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger);
        const auto Phases = Get_PhaseText(_RecordMark);
        const auto RecoverIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::Recover);
        const auto CooldownIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown);

        Assert_True(Trigger.Fired, "the target was moved as the strike's terminal sample was staged");
        Assert_True(Trigger.SawCandidate && Trigger.SawCandidateFrame == Trigger.FiredFrame,
            f"the candidate appeared in the frame of the terminal sample (move frame {Trigger.FiredFrame}, candidate frame {Trigger.SawCandidateFrame})");
        const auto StrikeEnd = Get_AttackPhaseEnd(EMars_Crawler_AttackPhase::Strike);
        Assert_True(Trigger.SawCandidatePhaseId == n"Strike" && Math::Abs(Trigger.SawCandidateTo - StrikeEnd) <= 1.0e-4,
            f"the candidate came from the strike's terminal interval (got {Trigger.SawCandidatePhaseId} to [{Trigger.SawCandidateTo :.4}] s, strike ends at [{StrikeEnd :.4}])");
        Assert_True(RecoverIndex >= 0 && CooldownIndex > RecoverIndex, f"the attack ran Strike > Recover > Cooldown (got{Phases})");
        if (RecoverIndex < 0 || CooldownIndex < 0)
        { return; }

        const auto ToRecover = _Records[RecoverIndex];
        // Approved change: Recover is entered on its first accepted interval, staged the frame after the commit pass.
        Assert_True(ToRecover.Frame == Trigger.SawCandidateFrame + 2,
            f"Recover was entered on the tick after the commit pass (candidate frame {Trigger.SawCandidateFrame}, Recover frame {ToRecover.Frame})");
        Assert_True(ToRecover.DamageCommitted, "the candidate was committed before Recover was entered");
        Assert_True(ToRecover.CommittedSampleId != 0 && ToRecover.CommittedSampleId == Trigger.SawCandidateSampleId,
            f"the committed sample is the strike's terminal sample (committed {ToRecover.CommittedSampleId}, terminal {Trigger.SawCandidateSampleId})");
        Assert_True(_Records[CooldownIndex].DamageCommitted, "the spent hit budget survives into Cooldown");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the target lost 15 HP once");
    }
}
