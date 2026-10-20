// This probe distinguishes managed action return from a subsequent public autonomous recovery. A failed action
// recovery is logged as failed even if its surviving claw can subsequently be recovered through the public API.
class UMars_AutoTest_AttackCatalog_SeverRecoveryEvidence : UMars_AutoTestRig_AttackCatalogPublicSurface
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-380000.0, -180000.0, 600.0);

    private FMars_TESTONLY_AttackCatalog_Stream _Stream;
    private FCk_Handle_BodyPart _SeveredPart;
    private FCk_Handle_ProceduralLeg _Survivor;
    private bool _ObservedProcessedSever = false;
    private bool _RequestedAutonomousRecovery = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_ProbeCrawler(InHandle);
        Add_Step("play a pincer with both real claws", n"Step_Play");
        Add_Step_WaitUntil("a real pincer Strike receipt is accepted", n"Check_Strike", k_SlowPolls, 0);
        Add_Step("apply lethal sever damage to one claw's Health", n"Step_Sever");
        Add_Step_WaitUntil("BodyPart sever and procedural detach have actually processed", n"Check_ProcessedSever", k_SlowPolls, 0);
        Add_Step_WaitUntil("the interrupted action publishes its exact terminal recovery", n"Check_Terminal", k_SlowPolls, 0);
        Add_Step_WaitUntil("terminal acknowledgement releases the managed action", n"Check_Released", k_SlowPolls, 0);
        Add_Step("report managed result and request public recovery if needed", n"Step_RecoverSurvivor");
        Add_Step_WaitUntil("the surviving claw is Default and planted on an operational articulation", n"Check_SurvivorRecovered", k_SlowPolls, 0);
        Add_Step("assert processed-state evidence and explicit recovery distinction", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Play(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle PartEntity = _ProbeClaws[0].Leg;
        _SeveredPart = PartEntity.As_BodyPart();
        _Survivor = _ProbeClaws[1].Leg;
        _Stream = Create_ProbeAction(InHandle, _ProbeClip);
    }

    UFUNCTION()
    private void Check_Strike(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Stream) == false)
        { return; }
        if (_Stream.TerminalSeen)
        {
            FinishFailure("the direct pincer ended before its Strike receipt could be severed");
            return;
        }
        auto Res = OutResult;
        Res.Set(_Stream.Accepted.Count > 0 && _Stream.Accepted.Latest.Get_Interval().Get_PhaseId() == n"Strike");
    }

    UFUNCTION()
    private void Step_Sever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Health = _SeveredPart.Get_Health();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(
            FMars_DamageEvent(1000.0f, GameplayTags::DamageType_Mars_Sever)));
    }

    UFUNCTION()
    private void Check_ProcessedSever(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Stream) == false)
        { return; }
        _ObservedProcessedSever = ck::IsValid(_SeveredPart) && _SeveredPart.Get_Health().Get_IsDepleted() &&
            _SeveredPart.Get_State() == EMars_BodyPart_State::Severed &&
            utils_procedural_leg::Get_IsAttached(_ProbeClaws[0].Leg) == false;
        auto Res = OutResult;
        Res.Set(_ObservedProcessedSever);
    }

    UFUNCTION()
    private void Check_Terminal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Stream) == false)
        { return; }
        auto Res = OutResult;
        Res.Set(_Stream.TerminalSeen);
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsProbeReleased(_Stream));
    }

    UFUNCTION()
    private void Step_RecoverSurvivor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _Stream.Result;
        const auto Unplanted = _Crawler.Get_Articulation().Get_UnplantedLimbIds();
        Log(f"[AttackCatalog SeverRecoveryEvidence] managed outcome {Result.Get_Outcome() :n}, recovery {Result.Get_Recovery() :n}, reason [{Result.Get_Reason()}]; unplanted limbs {Unplanted.Num()}");
        Assert_True(Result.Get_Outcome() != ECk_ProceduralAction_Outcome::Completed,
            "processed loss interrupted the managed pincer");
        // The sever is fixed (claw 0 mid-Strike), so the verdict is too: the managed return fails with a named reason
        // and leaves the surviving claw unplanted for the public recovery.
        Assert_True(Result.Get_Recovery() == ECk_ProceduralAction_Recovery::Failed && Result.Get_Reason() != NAME_None,
            f"the managed recovery fails with a named reason (recovery {Result.Get_Recovery() :n}, reason [{Result.Get_Reason()}])");
        _RequestedAutonomousRecovery = Unplanted.Contains(_ProbeLimbIds[1]);
        Assert_True(_RequestedAutonomousRecovery, "the failed managed return exposes the surviving claw for a separate public autonomous recovery");
        utils_crawler::Recover_UnplantedLimbs(_Crawler);
    }

    UFUNCTION()
    private void Check_SurvivorRecovered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_Articulation().Get_Health() == ECk_ProceduralArticulation_Health::Operational &&
            _Crawler.Get_Articulation().Get_LimbControl(_ProbeLimbIds[1]).Get_State() == ECk_ProceduralLimbControl_State::Default &&
            utils_procedural_leg::Get_Foot(_Survivor).Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_ObservedProcessedSever, "the test observed processed depletion, BodyPart sever and procedural detach");
        Assert_True(_Crawler.Get_Articulation().Get_UnplantedLimbIds().Contains(_ProbeLimbIds[1]) == false,
            "the surviving claw is no longer marked unplanted");
        const auto Endpoint = utils_procedural_leg::Get_Foot(_Survivor).Get_Position();
        Assert_True(utils_crawler::Get_IsFinite(Endpoint), "the recovered surviving foot has a finite world endpoint");
        Log(f"[AttackCatalog SeverRecoveryEvidence] surviving claw Default/Planted; articulation Operational; autonomous recovery requested {_RequestedAutonomousRecovery}");
        Assert_ProbeDidNotEnterGameCombat();
    }
}
