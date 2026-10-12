// A frame longer than a whole phase cannot skip it. The crawler's windup lasts 0.1 s and its strike 0.05 s, and the world
// runs at 8x time dilation through the attack, so every tick's delta is longer than the strike (and, at the usual lane
// frame rate, than the windup too). The clip action stops each accepted interval at a phase boundary, so every phase
// still gets an accepted interval of its own, and the attack enters each phase on a later tick than the one before.
// Strike's interval starts where Windup ended (the windup key) and Recover's where Strike ended (the strike key), the
// strike is swept in one sample no longer than MaxSampleTravel, the target in its path takes the jab's one request
// (100 -> 85) and the recovery sweeps nothing more.
//
// The zero-delta half is not driven: SetGlobalTimeDilation clamps to the engine's MinGlobalTimeDilation (0.0001 in
// BaseGame.ini), so the world never ticks with a zero delta. A tick with no positive time running cancellation only is
// the attack tick's `InDeltaSeconds <= 0` return, read rather than run.
//
// The dilation is restored to 1 in the last step and in DoEndPlay, whatever ended the test.
class UMars_AutoTest_CrawlerMelee_HitchAndZeroTime : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-290000.0, -150000.0, 600.0);

    private const float32 k_Dilation = 8.0f;

    private bool _Dilated = false;
    private float64 _DilatedDeltaSeconds = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_ArmedCrawlerSpec(4);
        Spec.Combat.Timing.WindupSeconds = 0.1f;
        Spec.Combat.Timing.StrikeSeconds = 0.05f;
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("spawn a target the strike reaches", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("dilate world time 8x", n"Step_Dilate");
        Add_Step_WaitFrames("let the dilation reach the frame delta", 3);
        Add_Step("record the dilated frame delta; select the target and request one attack", n"Step_RecordDeltaAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the target's Health has taken the hit", n"Check_TargetHit", k_SlowPolls, 0);
        Add_Step("restore time dilation 1; every phase ran on its acknowledged endpoint", n"Step_RestoreAndAssert");
        Run_Steps(InHandle);
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        RestoreDilation();
    }

    private void RestoreDilation()
    {
        if (_Dilated == false)
        { return; }

        Gameplay::SetGlobalTimeDilation(1.0f);
        _Dilated = false;
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));
    }

    UFUNCTION()
    private void Step_Dilate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dilated = true;
        Gameplay::SetGlobalTimeDilation(k_Dilation);
    }

    UFUNCTION()
    private void Step_RecordDeltaAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DilatedDeltaSeconds = Gameplay::GetWorldDeltaSeconds();
        Step_TargetAndStart(InHandle, InPayload);
    }

    UFUNCTION()
    private void Check_TargetHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Target.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void Step_RestoreAndAssert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        RestoreDilation();

        const auto Combat = _Crawler.Get_Spec().Combat;
        Assert_True(_DilatedDeltaSeconds > Combat.Timing.StrikeSeconds,
            f"the dilated frame delta ({_DilatedDeltaSeconds :.3} s) is longer than the whole strike ({Combat.Timing.StrikeSeconds :.3} s; windup {Combat.Timing.WindupSeconds :.3} s)");

        const auto Phases = Get_PhaseText(_RecordMark);
        Assert_True(_Records.Num() - _RecordMark == 5, f"exactly five phase changes (got{Phases})");
        if (_Records.Num() - _RecordMark != 5)
        { return; }

        const auto ToWindup = _Records[_RecordMark];
        const auto ToStrike = _Records[_RecordMark + 1];
        const auto ToRecover = _Records[_RecordMark + 2];
        Assert_True(ToWindup.New == EMars_Crawler_AttackPhase::Windup && ToStrike.New == EMars_Crawler_AttackPhase::Strike &&
            ToRecover.New == EMars_Crawler_AttackPhase::Recover && _Records[_RecordMark + 3].New == EMars_Crawler_AttackPhase::Cooldown &&
            _Records[_RecordMark + 4].New == EMars_Crawler_AttackPhase::Idle,
            f"no phase was skipped: Windup > Strike > Recover > Cooldown > Idle (got{Phases})");

        Assert_True(ToStrike.Frame - ToWindup.Frame >= 1, f"Windup ended on a later tick than its admission (frames {ToWindup.Frame} -> {ToStrike.Frame})");
        // Approved change: phases follow accepted clip intervals, so Strike lasts one accepted interval here, not a
        // posing tick plus an acknowledged endpoint.
        Assert_True(ToRecover.Frame - ToStrike.Frame >= 1, f"Strike ended on a later tick than it began (frames {ToStrike.Frame} -> {ToRecover.Frame})");
        const auto WindupEnd = float64(Combat.Timing.WindupSeconds);
        const auto StrikeEnd = WindupEnd + float64(Combat.Timing.StrikeSeconds);
        Assert_True(ToStrike.AcceptedPhaseId == n"Strike" && Math::Abs(ToStrike.AcceptedFrom - WindupEnd) <= 1.0e-4,
            f"Strike began on an accepted Strike interval from the windup key (got {ToStrike.AcceptedPhaseId} from [{ToStrike.AcceptedFrom :.4}] s)");
        Assert_True(ToRecover.AcceptedPhaseId == n"Recover" && Math::Abs(ToRecover.AcceptedFrom - StrikeEnd) <= 1.0e-4,
            f"Recover began on an accepted Recover interval from the strike key (got {ToRecover.AcceptedPhaseId} from [{ToRecover.AcceptedFrom :.4}] s)");
        Assert_True(ToRecover.DamageCommitted, "the strike's hit was committed before Recover");
        Assert_True(_Crawler.Get_AttackLongestSweep() <= Combat.Hit.MaxSampleTravel,
            f"no sweep was longer than MaxSampleTravel [{Combat.Hit.MaxSampleTravel}] (longest {_Crawler.Get_AttackLongestSweep() :.2} cm)");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the target lost 15 HP once");
    }
}
