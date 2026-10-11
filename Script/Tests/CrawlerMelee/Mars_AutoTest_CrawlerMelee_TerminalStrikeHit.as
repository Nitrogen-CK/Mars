// A hit found on Strike's terminal sample still commits, once, before the endpoint ends the phase. The target starts out
// of reach (near face 52 cm ahead of the neutral hit centre; the strike reaches 44) and is moved into the strike's path in
// the frame the endpoint sample is submitted, so only that sample can reach it. The resolver stores the candidate in that
// frame; the next attack tick commits it and only then consumes the endpoint's acknowledgment into Recover. Recover is
// therefore entered with the hit committed from the acknowledged terminal sample, and the latch stays set through
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
        Add_Step("spawn the target out of reach and arm its move into the path on the strike's endpoint sample", n"Step_SpawnTarget");
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

        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::StrikeEndpointSubmitted, EMars_TESTONLY_CrawlerMelee_Action::MoveTarget);
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

        Assert_True(Trigger.Fired, "the target was moved on the strike's endpoint sample");
        Assert_True(Trigger.SawCandidate && Trigger.SawCandidateFrame == Trigger.FiredFrame,
            f"the candidate appeared in the frame of the endpoint sample (move frame {Trigger.FiredFrame}, candidate frame {Trigger.SawCandidateFrame})");
        Assert_True(RecoverIndex >= 0 && CooldownIndex > RecoverIndex, f"the attack ran Strike > Recover > Cooldown (got{Phases})");
        if (RecoverIndex < 0 || CooldownIndex < 0)
        { return; }

        const auto ToRecover = _Records[RecoverIndex];
        Assert_True(ToRecover.Frame == Trigger.SawCandidateFrame + 1,
            f"Recover was entered by the next attack tick (candidate frame {Trigger.SawCandidateFrame}, Recover frame {ToRecover.Frame})");
        Assert_True(ToRecover.DamageCommitted, "the candidate was committed before Recover was entered");
        Assert_True(ToRecover.CommittedSampleId != 0 && ToRecover.CommittedSampleId == ToRecover.AcknowledgedSampleId,
            f"the committed sample is the acknowledged terminal sample (committed {ToRecover.CommittedSampleId}, acknowledged {ToRecover.AcknowledgedSampleId})");
        Assert_True(_Records[CooldownIndex].DamageCommitted, "the spent hit budget survives into Cooldown");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the target lost 15 HP once");
    }
}
