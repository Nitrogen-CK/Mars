// A cancel before any commit hands the return to the clip action. Halfway through Windup (the body well off neutral, the
// target out of reach) a StateExit cancel arrives: the attack runs Windup > CancelRecover > Cooldown > Idle, and
//   - the action is cancelled (Cancelling, then Finished as Cancelled with a successful recovery);
//   - while the attack waits in CancelRecover nothing new is accepted from the action after the cancel's own frame: the
//     game submits no easing samples, the body comes back through the action's dedicated return alone;
//   - the presentation moves back towards neutral on every watched frame of CancelRecover and is at neutral when
//     Cooldown begins, on the action's terminal record, no sooner than about CancelSeconds after the cancel;
//   - no damage request exists and the action is released.
class UMars_AutoTest_CrawlerMelee_CancelReturnsThroughAction : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-310000.0, -150000.0, 600.0);

    private const float64 k_DisplacedCm = 3.0;
    private const float64 k_NeutralToleranceCm = 1.0;
    private const float64 k_ReturnJitterCm = 0.1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target out of reach; watch what the resolver accepts", n"Step_SpawnTargetAndWatch");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("half the windup is accepted", n"Check_HalfWindupAccepted", k_SlowPolls, 0);
        Add_Step("cancel (StateExit)", n"Step_Cancel");
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("the body came back through the action's return", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTargetAndWatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 55.0, FVector(10.0, 20.0, 20.0));
        Watch_Accepts();
    }

    UFUNCTION()
    private void Check_HalfWindupAccepted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Interval = _Crawler.Get_AttackAcceptedInterval();
        const auto HalfWindup = 0.5 * Get_AttackPhaseEnd(EMars_Crawler_AttackPhase::Windup);
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Windup && Interval.Get_PhaseId() == n"Windup" &&
            Interval.Get_ToTime().Get_Seconds() >= HalfWindup);
    }

    UFUNCTION()
    private void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phases = Get_PhaseText(_RecordMark);
        const auto CancelIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover);
        const auto CooldownIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown);
        Assert_True(_Records.Num() - _RecordMark == 4 && CancelIndex == _RecordMark + 1 && CooldownIndex == _RecordMark + 2,
            f"the attack ran Windup > CancelRecover > Cooldown > Idle (got{Phases})");
        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::StateExit,
            f"the attack was cancelled as StateExit (last cancel {Get_LastCancelText()})");
        if (CancelIndex < 0 || CooldownIndex < 0)
        { return; }

        const auto Cancelled = _Records[CancelIndex];
        const auto Cooled = _Records[CooldownIndex];
        Assert_True(Cancelled.PresentationErrorCm >= k_DisplacedCm,
            f"the body was off neutral when the cancel arrived ({Cancelled.PresentationErrorCm :.2} cm)");
        Assert_True(Cooled.TerminalSeen && Cooled.PresentationErrorCm <= k_NeutralToleranceCm,
            f"Cooldown began on the action's terminal record, at neutral ({Cooled.PresentationErrorCm :.3} cm, terminal {Cooled.TerminalSeen})");

        const auto CancelSeconds = float64(_Crawler.Get_Spec().Combat.Timing.CancelSeconds);
        Assert_True(Cooled.Time - Cancelled.Time >= 0.75 * CancelSeconds,
            f"the return took about the action's dedicated return ({Cooled.Time - Cancelled.Time :.3} s for CancelSeconds {CancelSeconds :.3})");

        auto SawCancelling = false;
        auto SawCancelledTerminal = false;
        auto PreviousError = -1.0;
        int64 SampleAfterCancel = -1;
        for (const auto& Frame : Get_AcceptRecords())
        {
            if (Frame.ActionValid && Frame.ActionState == ECk_ProceduralAction_State::Cancelling)
            { SawCancelling = true; }

            if (Frame.ActionValid && Frame.ActionState == ECk_ProceduralAction_State::Finished &&
                Frame.ActionOutcome == ECk_ProceduralAction_Outcome::Cancelled && Frame.ActionRecovery == ECk_ProceduralAction_Recovery::Succeeded)
            { SawCancelledTerminal = true; }

            if (Frame.Phase != EMars_Crawler_AttackPhase::CancelRecover || Frame.Frame <= Cancelled.Frame)
            { continue; }

            if (SampleAfterCancel < 0)
            { SampleAfterCancel = Frame.AckSampleId; }
            Assert_True(Frame.AckSampleId == SampleAfterCancel,
                f"frame {Frame.Frame}: nothing new was accepted from the action during its return (sample {SampleAfterCancel} -> {Frame.AckSampleId})");

            if (PreviousError >= 0.0)
            {
                Assert_True(Frame.PresentationErrorCm <= PreviousError + k_ReturnJitterCm,
                    f"frame {Frame.Frame}: the return moved towards neutral ({PreviousError :.3} -> {Frame.PresentationErrorCm :.3} cm)");
            }
            PreviousError = Frame.PresentationErrorCm;
        }

        Assert_True(SawCancelling, "the action was cancelled (Cancelling)");
        Assert_True(SawCancelledTerminal, "the action finished as Cancelled with a successful recovery");
        Assert_True(ck::Is_NOT_Valid(_Crawler.Get_AttackAction()), "the action was released after its terminal");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "no damage request exists");
    }
}
