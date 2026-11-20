// A passive armed crawler that stays put attacks the server's prey once; 0.15 s after Windup, or at Strike if sooner,
// its aggression is switched off. The attack is cancelled Disabled and goes straight to Cooldown (Windup, perhaps
// Strike, Cooldown, Idle; no CancelRecover). The client's copy reads Cooldown and the cancel together and cancels the
// action it had started: within ten frames of that notify it is cancelling, it finishes once short of Completed,
// raises Admitted and Interrupted once and Completed never, cues no Recover, keeps a hurt count of 0 and is back at
// neutral within 1.5 s.
// Surface: Ck.Crawler.Net.AS_Crawler_ADisabledAttackStopsOnTheClientsCopy
class UCk_AutoTest_Net_Crawler_ADisabledAttackStopsOnTheClientsCopy : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 32.0f;

    private const FVector k_Base = FVector(840000.0, 0.0, 5000.0);
    private const FString k_Row = "ADisabledAttackStopsOnTheClientsCopy";
    private const float32 k_DisableAfterWindupSeconds = 0.15f;

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

        _DisableAfterWindupSeconds = TOptional<float32>(k_DisableAfterWindupSeconds);
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
        const auto Phases = Describe_Phases(Record.Phases);
        Assert_True(_DisabledFrame >= 0, "the server switched its aggression off during the attack");
        Assert_True(Record.LastCancelAtIdle == "Disabled", f"the server's attack was cancelled Disabled ({Record.LastCancelAtIdle})");
        Assert_True(Phases == "Windup,Cooldown,Idle," || Phases == "Windup,Strike,Cooldown,Idle,",
            f"the server's phases ran Windup, perhaps Strike, Cooldown, Idle, with no CancelRecover ({Phases})");
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

        Assert_Equals_Int(_Crawler.Get_HurtCount(), 0, "the copy's hurt count reads 0");
        Assert_Equals_Int(Count_StartedAttacks(), 1, "the copy started one action");
        Assert_DecoyUntouched();
        Finish_CrawlerRow(k_Row, f"{Describe_AttackState()} {Describe_ServerAttacks()}");
    }
}
