// A passive armed crawler that stays put attacks a prey the server drives it at with fresh selection, until it has
// completed one jab and one pincer or made four attacks, each waited back to Idle (the shipped loadout waits for its
// preferred pincer, so a jab is played only when one is selected). Every attack runs Windup, Strike, Recover, Cooldown,
// Idle with no cancel, the body moves and the pincer's claws swing. The client's copy plays each of them: an action of
// the same clip with the same slots, created within ten frames of the ledger that carried the attack, started once and
// Completed, its cues Admitted and Completed once and its phases the posed phases its ledger carried, its body and
// claws within a quarter of the server's motion, and back at neutral within 1.5 s; it never sweeps, deals or hurts.
// Surface: Ck.Crawler.Net.AS_Crawler_AHostsAttackShowsOnTheClientsCopy
class UCk_AutoTest_Net_Crawler_AHostsAttackShowsOnTheClientsCopy : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 32.0f;

    private const FVector k_Base = FVector(838000.0, 0.0, 5000.0);
    private const FString k_Row = "AHostsAttackShowsOnTheClientsCopy";
    private const int32 k_MaxAttacks = 4;
    private const float64 k_BodyFloor = 2.0;
    private const float64 k_ClawFloor = 10.0;

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

    // The server's attacks without a cancel at their Idle, of InId.
    private int32 Count_Completed(FGameplayTag InId) const
    {
        auto Count = 0;
        for (const auto& Record : _Attacks)
        {
            if (Record.AttackId == InId && Record.Phases.Contains(EMars_Crawler_AttackPhase::Recover) && Record.LastCancelAtIdle.IsEmpty())
            { Count += 1; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCrawler(Make_ArmedRowSpec(k_StaysPut, ECk_EnableDisable::Disable));
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_AttackRecord();
        Spawn_Prey();
        WaitSampling(k_ComposeSeconds, n"OnServerAttackDone");
    }

    UFUNCTION()
    private void OnServerAttackDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Done = Count_Completed(GameplayTags::Attack_Mars_Jab) > 0 && Count_Completed(GameplayTags::Attack_Mars_Pincer) > 0;
        if (Done == false && Count_StartedAttacks() < k_MaxAttacks)
        {
            Run_ServerAttack(n"OnServerAttackDone");
            return;
        }

        WaitSampling(1.0f, n"OnServerSampled");
    }

    UFUNCTION()
    private void OnServerSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerAttacks(0, -1.0f, TArray<float32>());
        Assert_True(Count_Completed(GameplayTags::Attack_Mars_Pincer) > 0, "the server completed a pincer");
        Assert_True(Count_StartedAttacks() >= 2, f"the server made at least two attacks ({Count_StartedAttacks()}; jabs completed {Count_Completed(GameplayTags::Attack_Mars_Jab)})");

        auto Committed = 0;
        for (const auto& Record : _Attacks)
        {
            if (Record.FirstFrame < 0)
            { continue; }

            const auto Gen = Record.Generation;
            Assert_True(Describe_Phases(Record.Phases) == "Windup,Strike,Recover,Cooldown,Idle,",
                f"gen {Gen}: the server's phases ran Windup, Strike, Recover, Cooldown, Idle ({Describe_Phases(Record.Phases)})");
            Assert_True(Record.LastCancelAtIdle.IsEmpty(), f"gen {Gen}: the server's attack was never cancelled ({Record.LastCancelAtIdle})");
            Assert_True(Record.BodyPeak >= k_BodyFloor, f"gen {Gen}: the server's body moved at least 2 ({Record.BodyPeak})");
            if (Record.AttackId == GameplayTags::Attack_Mars_Pincer)
            { Assert_True(Record.FootPeak >= k_ClawFloor, f"gen {Gen}: the server's pincer claws moved at least 10 ({Record.FootPeak})"); }

            if (Record.CommittedAtIdle)
            { Committed += 1; }
        }

        Assert_Equals_Int(_PreyApplied.Num(), Committed, "the prey raised OnDamaged once per committed attack");
        Hold_CrawlerServerRow(k_Row, Describe_AttackState());
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

    UFUNCTION()
    private void OnClientArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsCrawlerGone())
        { FinishFailure("the client's copy was gone before it asserted"); return; }

        Assert_CopyKeepsNoAttackOfItsOwn();
        Assert_True(_AttackCues > 0, "the client's copy raised OnAttackCue");
        const auto Readout = Get_ServerAttacks();
        Assert_True(Readout.Attacks.Num() > 0, "the server's attacks reached the client");
        for (const auto& Server : Readout.Attacks)
        {
            Assert_CopyPlayedTheServersAttack(Server, 0.25, 1.5);
            const auto Index = Find_Attack(Server.Generation, false);
            if (Index < 0)
            { continue; }

            const auto Record = _Attacks[Index];
            const auto Gen = Server.Generation;
            Assert_True(Record.FirstFrame >= Record.NotifyFrame && Record.FirstFrame - Record.NotifyFrame <= 10,
                f"gen {Gen}: the copy's action was created within ten frames of the notify that carried it (notify {Record.NotifyFrame}, created {Record.FirstFrame}, server Windup {Server.FirstFrame})");
            Assert_True(Record.Outcome == ECk_ProceduralAction_Outcome::Completed, f"gen {Gen}: the copy's action Completed ({Record.Outcome :n})");
            Assert_True(Record.Admitted == 1 && Record.Completed == 1 && Record.Interrupted == 0,
                f"gen {Gen}: the copy raised Admitted 1, Completed 1, Interrupted 0 ({Record.Admitted}/{Record.Completed}/{Record.Interrupted})");
        }

        Assert_Equals_Int(Count_StartedAttacks(), Readout.Attacks.Num(), "the copy played the server's attacks and no other");
        Assert_Equals_Int(Get_CopyStarted(), Readout.Attacks.Num(), "the copy's show started one action per attack");
        Assert_Equals_Int(_Crawler.Get_HurtCount(), 0, "the copy's hurt count reads 0");
        Assert_DecoyUntouched();
        Finish_CrawlerRow(k_Row, f"{Describe_AttackState()} {Describe_ServerAttacks()}");
    }
}
