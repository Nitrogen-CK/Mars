// A passive armed crawler that stays put loses leg 0 (a front leg, its limb living 2 s) to the server's hits. Without
// both front legs its loadout can no longer pincer: with the prey as its target, its selection reads the body-only jab
// within 4 s of the limb going, and the one attack the server drives runs Windup, Strike, Recover, Cooldown, Idle on a
// plan with no slots. The client's copy, on its three legs, plays that jab: the same attack and clip with no slots,
// started once and Completed, Admitted and Completed cued once with no Interrupted, its cued phases a sub-sequence of
// those its ledger carried, its body peak within a quarter of the server's, and back at neutral within 1.5 s.
// Surface: Ck.Crawler.Net.AS_Crawler_AThreeLeggedCrawlersJabShowsOnTheClientsCopy
class UCk_AutoTest_Net_Crawler_AThreeLeggedCrawlersJabShowsOnTheClientsCopy : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(847000.0, 0.0, 5000.0);
    private const FString k_Row = "AThreeLeggedCrawlersJabShowsOnTheClientsCopy";
    private const float32 k_LimbSeconds = 2.0f;
    private const float64 k_JabWithinSeconds = 4.0;
    private const float64 k_BodyTolerance = 0.25;
    private const float64 k_NeutralSeconds = 1.5;

    private float64 _LimbGoneSeconds = -1.0;
    private int32 _JabGeneration = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerSettled", n"OnClientSettled", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private FString Describe_Jab()
    {
        if (Get_IsCrawlerGone() || Get_IsServer() == false)
        { return f"jab=[gen {_JabGeneration}]"; }

        const auto Evaluation = _Crawler.Get_AttackEvaluation();
        const auto Selected = Evaluation.Selection.Selected;
        const auto SelectedText = Selected.IsSet() ? Selected.GetValue().ToString() : FString("none");
        FString Enabled = "";
        for (int32 Index = 0; Index < _LegParts.Num(); ++Index)
        { Enabled += f"{Get_IsLegAttached(Index)},"; }

        return f"jab=[gen {_JabGeneration} selected {SelectedText} disposition {Evaluation.Selection.Disposition :n} "
            + f"selectionGen {Evaluation.SelectionGeneration} limbGoneAt {_LimbGoneSeconds} legsAttached {Enabled} "
            + f"enabled {utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait())}]";
    }

    private bool Get_IsJabSelected()
    {
        const auto Selected = _Crawler.Get_AttackEvaluation().Selection.Selected;
        return Selected.IsSet() && Selected.GetValue() == GameplayTags::Attack_Mars_Jab;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = Make_ArmedRowSpec(k_StaysPut, ECk_EnableDisable::Disable);
        Spec.Vitals.LegDebris.LifetimeSeconds = k_LimbSeconds;
        Spawn_ServerCrawler(Spec);
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerReadout();
        Begin_AttackRecord();
        Spawn_Prey();
        WaitSampling(k_ComposeSeconds, n"OnServerHitDue");
    }

    // One hit every 0.3 s while leg 0 is attached, at most four; then the prey is its target.
    UFUNCTION()
    private void OnServerHitDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPartState(0, EMars_BodyPart_State::Severed))
        {
            Request_ServerAttack();
            WaitUntil(n"Is_ServerLimbGone", n"OnServerLimbGone", k_SlowPolls);
            return;
        }

        if (_LegActions >= k_MaxLegHits)
        {
            Log_CrawlerRow(k_Row, Describe_Jab());
            FinishFailure(f"{_LegActions} hits and the server's leg 0 is still attached");
            return;
        }

        _LegActions += 1;
        Hit_ServerLeg(0, k_LegHit);
        WaitSampling(k_LegHitSpacingSeconds, n"OnServerHitDue");
    }

    UFUNCTION()
    private void Is_ServerLimbGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(_Limbs.Num() > 0 && Get_HasSeveredLimbLeft() == false);
    }

    UFUNCTION()
    private void OnServerLimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LimbGoneSeconds = Get_WorldSeconds();
        WaitUntil(n"Is_ServerJabChosen", n"OnServerJabChosen", k_SlowPolls);
    }

    // The selection reads the jab, or the time it had to ran out.
    UFUNCTION()
    private void Is_ServerJabChosen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsJabSelected() || Get_WorldSeconds() - _LimbGoneSeconds > k_JabWithinSeconds);
    }

    UFUNCTION()
    private void OnServerJabChosen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsJabSelected() == false)
        {
            Log_CrawlerRow(k_Row, f"{Describe_Jab()} {Describe_AttackState()}");
            FinishFailure("the server's three-legged crawler did not select the jab within 4 s of its limb going");
            return;
        }

        Log_CrawlerRow(k_Row, f"jabChosen {Describe_Jab()}");
        Run_ServerAttack(n"OnServerJabDone");
    }

    UFUNCTION()
    private void OnServerJabDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(1.0f, n"OnServerJabSampled");
    }

    UFUNCTION()
    private void OnServerJabSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Index = Find_LastStartedAttack();
        Assert_True(Index >= 0, "the server started an attack");
        if (Index >= 0)
        {
            const auto Record = _Attacks[Index];
            _JabGeneration = Record.Generation;
            Assert_True(Record.AttackId == GameplayTags::Attack_Mars_Jab, f"the server's attack is the jab ({Record.AttackId.ToString()})");
            Assert_True(Record.Slots.IsEmpty(), f"the server's jab plan has no slots ({Record.Slots})");
            Assert_True(Describe_Phases(Record.Phases) == "Windup,Strike,Recover,Cooldown,Idle,",
                f"the server's jab ran Windup, Strike, Recover, Cooldown, Idle ({Describe_Phases(Record.Phases)})");
        }

        Assert_Equals_Int(Get_AttachedLegs(), _LegCount - 1, "the server's crawler stands on three legs");
        Publish_ServerAttacks(_JabGeneration, -1.0f, TArray<float32>());
        Hold_CrawlerServerRow(k_Row, f"{Describe_Jab()} {Describe_AttackState()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_AttackRecord();
        Spawn_Prey();
        Await_ServerAttacks(n"OnClientArrived");
    }

    // Each of InCued appears in InNotified, in order.
    private bool Get_IsSubsequenceOf(const TArray<EMars_Crawler_AttackPhase>& InCued, const TArray<EMars_Crawler_AttackPhase>& InNotified) const
    {
        auto At = 0;
        for (const auto Phase : InCued)
        {
            while (At < InNotified.Num() && InNotified[At] != Phase)
            { ++At; }

            if (At >= InNotified.Num())
            { return false; }

            ++At;
        }

        return true;
    }

    UFUNCTION()
    private void OnClientArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsCrawlerGone())
        { FinishFailure("the client's copy was gone before it asserted"); return; }

        Assert_CopyLikeTheServer();
        const auto Readout = Get_ServerAttacks();
        Assert_True(Get_HasServerAttacks() && Readout.StruckGeneration > 0, "the server's jab reached the client");
        auto ServerIndex = -1;
        for (int32 Index = 0; Index < Readout.Attacks.Num(); ++Index)
        {
            if (Readout.Attacks[Index].Generation == Readout.StruckGeneration)
            { ServerIndex = Index; }
        }

        const auto Index = Find_Attack(Readout.StruckGeneration, false);
        Assert_True(ServerIndex >= 0 && Index >= 0, f"the client recorded the server's jab (gen {Readout.StruckGeneration})");
        if (ServerIndex >= 0 && Index >= 0)
        {
            const auto Server = Readout.Attacks[ServerIndex];
            const auto Record = _Attacks[Index];
            Assert_True(Record.AttackId == GameplayTags::Attack_Mars_Jab && Record.SourceClip == Server.SourceClip && Record.Slots.IsEmpty(),
                f"the copy played the jab, the server's clip, no slots (copy {Record.AttackId.ToString()} {Record.SourceClip} [{Record.Slots}]; server {Server.SourceClip})");
            Assert_Equals_Int(Record.Started, 1, "the copy started one action for the jab");
            Assert_True(Record.Outcome == ECk_ProceduralAction_Outcome::Completed, f"the copy's jab Completed ({Record.Outcome :n})");
            Assert_True(Record.Admitted == 1 && Record.Completed == 1 && Record.Interrupted == 0,
                f"the copy raised Admitted 1, Completed 1, Interrupted 0 ({Record.Admitted}/{Record.Completed}/{Record.Interrupted})");
            Assert_True(Get_IsSubsequenceOf(Record.Phases, Record.Notified),
                f"the copy's cued phases are a sub-sequence of the notified ones (cued {Describe_Phases(Record.Phases)} notified {Describe_Phases(Record.Notified)})");
            Assert_True(Math::Abs(Record.BodyPeak - Server.BodyPeak) <= k_BodyTolerance * Server.BodyPeak,
                f"the copy's body peak is within 25 percent of the server's ({Record.BodyPeak} against {Server.BodyPeak})");
            Assert_True(Record.BackAtNeutralSeconds >= 0.0 && Record.BackAtNeutralSeconds - Record.FinishedSeconds <= k_NeutralSeconds,
                f"the copy is back at neutral within 1.5 s of its OnFinished ({Record.BackAtNeutralSeconds - Record.FinishedSeconds} s)");
        }

        Assert_Equals_Int(Get_AttachedLegs(), 3, "the client's copy stands on three legs");
        Assert_DecoyUntouched();
        Finish_CrawlerRow(k_Row, f"{Describe_AttackState()} {Describe_ServerAttacks()} {Describe_Readout()}");
    }
}
