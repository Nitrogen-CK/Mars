// A passive armed crawler that stays put attacks the server's prey once; the frame the attack enters Strike its body
// takes a 5 Blunt hit with no instigator. The attack is cancelled Hurt (Windup, Strike, CancelRecover, Cooldown, Idle),
// and the ledger write that leaves Strike carries the cancel and the hurt count together. The client's copy had
// already started its action: within ten frames of the cancel's notify it is cancelling, it finishes once short of
// Completed, raises Admitted and Interrupted once and Completed never, cues no Recover, reads a hurt count of 1 within
// 0.5 s of the server's hit and is back at neutral within 1.5 s.
// Surface: Ck.Crawler.Net.AS_Crawler_AHurtCancelsTheAttackOnTheClientsCopy
class UCk_AutoTest_Net_Crawler_AHurtCancelsTheAttackOnTheClientsCopy : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 32.0f;

    private const FVector k_Base = FVector(839000.0, 0.0, 5000.0);
    private const FString k_Row = "AHurtCancelsTheAttackOnTheClientsCopy";
    private const float32 k_Hurt = 5.0f;

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

        _HurtAtStrike = TOptional<float32>(k_Hurt);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
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
        WaitSampling(k_ComposeSeconds, n"OnServerReady");
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Run_ServerAttack(n"OnServerAttackDone");
    }

    UFUNCTION()
    private void OnServerAttackDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(1.0f, n"OnServerSampled");
    }

    UFUNCTION()
    private void OnServerSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerAttacks(0, -1.0f, TArray<float32>());
        const auto Index = Find_LastStartedAttack();
        if (Index < 0)
        {
            Hold_CrawlerServerRow(k_Row, Describe_AttackState());
            FinishFailure("the server's attack was never admitted");
            return;
        }

        const auto Record = _Attacks[Index];
        Assert_True(_HitFrame >= 0, "the server hit the body at Strike");
        Assert_True(Record.LastCancelAtIdle == "Hurt", f"the server's attack was cancelled Hurt ({Record.LastCancelAtIdle})");
        Assert_True(Describe_Phases(Record.Phases) == "Windup,Strike,CancelRecover,Cooldown,Idle,",
            f"the server's phases ran Windup, Strike, CancelRecover, Cooldown, Idle ({Describe_Phases(Record.Phases)})");

        auto LeftStrike = -1;
        for (int32 Ledger = 0; Ledger < Record.Ledgers.Num() && LeftStrike < 0; ++Ledger)
        {
            const auto Phase = Record.Ledgers[Ledger].Phase;
            if (Phase != EMars_Crawler_AttackPhase::Windup && Phase != EMars_Crawler_AttackPhase::Strike)
            { LeftStrike = Ledger; }
        }

        Assert_True(LeftStrike >= 0 && Record.Ledgers[LeftStrike].Cancelled && Record.Ledgers[LeftStrike].HurtCount == 1,
            f"the server's ledger write that left Strike reads Cancelled and hurt count 1 (write {LeftStrike})");
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
        Assert_Equals_Int(Readout.Attacks.Num(), 1, "the server's one attack reached the client");
        if (Readout.Attacks.Num() > 0)
        { Assert_CopyCancelledTheAttack(Readout.Attacks[0].Generation); }

        Assert_Equals_Int(_Crawler.Get_HurtCount(), 1, "the copy's hurt count reads 1");
        const auto HitSeconds = Get_SecondsAtFrame(Readout.HitFrame);
        Assert_True(Readout.HitFrame >= 0 && _CopyHurtFrame >= 0 && HitSeconds >= 0.0 && _CopyHurtSeconds - HitSeconds <= 0.5,
            f"the copy's hurt count read 1 within 0.5 s of the server's hit (hit frame {Readout.HitFrame}, copy frame {_CopyHurtFrame}, {_CopyHurtSeconds - HitSeconds} s)");
        Assert_Equals_Int(Count_StartedAttacks(), 1, "the copy started one action");
        Assert_DecoyUntouched();
        Finish_CrawlerRow(k_Row, f"{Describe_AttackState()} {Describe_ServerAttacks()}");
    }
}
