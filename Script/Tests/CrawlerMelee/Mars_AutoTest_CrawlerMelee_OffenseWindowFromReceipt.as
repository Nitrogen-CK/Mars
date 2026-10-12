// Whether an accepted sample may sweep and hit is read from its receipt's windows, not from the attack's phase. The target
// stands where the strike reaches it mid-phase (near face 30 cm ahead of the neutral hit centre). Two jabs:
//   1. the crawler plays a test clip identical to its own except that Offense closes at the end of Windup, so every
//      accepted Strike interval lies outside the window: the attack still runs Windup > Strike > Recover > Cooldown >
//      Idle, but no candidate is ever stored, nothing is obstructed, no damage request exists and the target is
//      untouched;
//   2. with the crawler's own clip restored, the same jab at the same target hits it once (100 -> 85): the miss in 1 was
//      the window, not the geometry.
// The test clip is installed by a test-only write to the crawler's retained spec (its AttackClip), the one input a
// crawler cannot otherwise take from a test.
class UMars_AutoTest_CrawlerMelee_OffenseWindowFromReceipt : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-320000.0, -150000.0, 600.0);

    private UCk_ProceduralAction_Data _NarrowClip;
    private UCk_ProceduralAction_Data _OwnClip;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target the strike reaches mid-phase; install a clip whose Offense ends with Windup; watch accepts", n"Step_Arm");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("(1) select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("(1) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("(1) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds("(1) settle 0.5 s", 0.5f);
        Add_Step("(1) the Strike outside Offense swept and hit nothing; restore the crawler's own clip", n"Step_AssertOutsideAndRestore");
        Add_Step("(2) select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("(2) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("(2) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("(2) the target's Health has taken the hit", n"Check_TargetHit", k_SlowPolls, 0);
        Add_Step("(2) the same jab with Offense over Strike hit the target once", n"Step_AssertInside");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Arm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));

        auto& Params = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Params);
        _OwnClip = Params.Spec.Combat.AttackClip.Get();
        _NarrowClip = utils_crawler::Make_AttackClip(Params.Spec.Combat, this);
        Assert_True(ck::IsValid(_OwnClip) && ck::IsValid(_NarrowClip), "the crawler's clip exists and the test clip was built");
        if (ck::Is_NOT_Valid(_NarrowClip))
        { return; }

        auto Windows = TArray<FCk_ProceduralAction_Window>();
        Windows.Add(FCk_ProceduralAction_Window(utils_crawler::Get_OffenseWindowId(),
            FCk_ProceduralAction_TimeRef(n"Windup", FCk_FloatRange_0to1(0.0f)),
            FCk_ProceduralAction_TimeRef(n"Windup", FCk_FloatRange_0to1(1.0f))));
        _NarrowClip.Set_Windows(Windows);
        const auto Report = utils_procedural_action::Validate_Data(_NarrowClip);
        Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid, "the test clip validates");

        Params.Spec.Combat.AttackClip = _NarrowClip;
        Watch_Accepts();
    }

    UFUNCTION()
    private void Check_TargetHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Target.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void Step_AssertOutsideAndRestore(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phases = Get_PhaseText(_RecordMark);
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::Strike) >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Recover) >= 0 &&
            Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown) >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Idle) >= 0,
            f"(1) the jab ran its course (got{Phases})");
        Assert_True(_Crawler.Get_AttackLastCancel().IsSet() == false, f"(1) nothing obstructed or cancelled the jab (last cancel {Get_LastCancelText()})");

        auto StrikeOutside = 0;
        auto StrikeInside = 0;
        auto Candidates = 0;
        for (const auto& Frame : Get_AcceptRecords())
        {
            if (Frame.CandidatePending)
            { ++Candidates; }

            if (Frame.AcceptedPhaseId != n"Strike")
            { continue; }

            if (Frame.AcceptedInOffense)
            { ++StrikeInside; }
            else
            { ++StrikeOutside; }
        }

        Assert_True(StrikeOutside > 0 && StrikeInside == 0,
            f"(1) every accepted Strike interval lay outside Offense (outside {StrikeOutside}, inside {StrikeInside})");
        Assert_Equals_Int(Candidates, 0, "(1) no candidate was ever stored");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "(1) no damage request exists");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "(1) the target is untouched");

        _Crawler.Get_Fragment(FMars_Fragment_Crawler_Params).Spec.Combat.AttackClip = _OwnClip;
    }

    UFUNCTION()
    private void Step_AssertInside(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackDamageCommitted(), "(2) the jab committed its hit");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "(2) the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "(2) the target lost the jab's 15 HP once");
    }
}
