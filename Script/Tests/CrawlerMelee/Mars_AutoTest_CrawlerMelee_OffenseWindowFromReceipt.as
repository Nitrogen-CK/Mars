// Whether an accepted sample may sweep and hit is read from its receipt's windows. The target stands where the strike
// reaches it mid-phase (near face 30 cm ahead of the neutral hit centre). One jab with the crawler's own clip runs
// Windup > Strike > Recover > Cooldown > Idle uncancelled; every accepted Strike interval carries Offense, every frame
// that stored a candidate accepted an interval inside Offense, and the target is hit once (100 -> 85).
//
// Not asserted here: that the same jab hits nothing when Offense closes at the end of Windup. A test cannot stage that
// clip: the kernel builds the clip into the crawler's AttackClip object at every admission, so a clip installed
// beforehand is overwritten and the action compiles the crawler's own. Covering it needs a window end on the combat
// profile.
class UMars_AutoTest_CrawlerMelee_OffenseWindowFromReceipt : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-320000.0, -150000.0, 600.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target the strike reaches mid-phase; watch accepts", n"Step_Arm");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the target's Health has taken the hit", n"Check_TargetHit", k_SlowPolls, 0);
        Add_Step("every Strike interval lay inside Offense and the jab hit the target once", n"Step_AssertInside");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Arm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));
        Watch_Accepts();
    }

    UFUNCTION()
    private void Check_TargetHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Target.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void Step_AssertInside(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phases = Get_PhaseText(_RecordMark);
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::Strike) >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Recover) >= 0 &&
            Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown) >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Idle) >= 0,
            f"the jab ran its course (got{Phases})");
        Assert_True(_Crawler.Get_AttackLastCancel().IsSet() == false, f"nothing obstructed or cancelled the jab (last cancel {Get_LastCancelText()})");

        auto StrikeOutside = 0;
        auto StrikeInside = 0;
        auto CandidatesOutside = 0;
        for (const auto& Frame : Get_AcceptRecords())
        {
            if (Frame.CandidatePending && Frame.AcceptedInOffense == false)
            { ++CandidatesOutside; }

            if (Frame.AcceptedPhaseId != n"Strike")
            { continue; }

            if (Frame.AcceptedInOffense)
            { ++StrikeInside; }
            else
            { ++StrikeOutside; }
        }

        Assert_True(StrikeInside > 0 && StrikeOutside == 0,
            f"every accepted Strike interval lay inside Offense (inside {StrikeInside}, outside {StrikeOutside})");
        Assert_Equals_Int(CandidatesOutside, 0, "no candidate was stored on a frame whose accepted interval lay outside Offense");
        Assert_True(_Crawler.Get_AttackDamageCommitted(), "the jab committed its hit");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the target lost the jab's 15 HP once");
    }
}
