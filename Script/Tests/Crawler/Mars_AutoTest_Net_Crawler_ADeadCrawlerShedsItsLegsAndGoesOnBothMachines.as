// The server lands a 1000 hit on the body Health of a crawler that stays put (corpse 3 s). A second later its crawler
// is dead with four parts Severed and its body zone off. On the client the copy reads dead; a second later it raised
// OnDied once, its four parts read Severed and raised OnSevered once each, no leg is attached, its body zone is off and
// its body pose reads Ready. Then the copy goes with the server's crawler, and every limb dies on each machine.
// Surface: Ck.Crawler.Net.AS_Crawler_ADeadCrawlerShedsItsLegsAndGoesOnBothMachines
class UCk_AutoTest_Net_Crawler_ADeadCrawlerShedsItsLegsAndGoesOnBothMachines : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(835000.0, 0.0, 5000.0);
    private const float32 k_CorpseSeconds = 3.0f;
    private const float32 k_LethalBlow = 1000.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = Make_RowSpec(k_StaysPut);
        Spec.Vitals.CorpseSeconds = k_CorpseSeconds;
        Spawn_ServerCrawler(Spec);
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(k_LethalBlow, GameplayTags::DamageType_Mars_Blunt)));
        WaitSampling(k_SettleSeconds, n"OnServerStruck");
    }

    UFUNCTION()
    private void OnServerStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_CrawlerMonster.Get_IsDead(), "the server's crawler is dead");
        for (int32 Index = 0; Index < k_LegCount; ++Index)
        { Assert_True(Get_IsPartState(Index, EMars_BodyPart_State::Severed), f"the server's part {Index} is Severed"); }

        Assert_False(_Zone.Get_IsEnabled(), "the server's body zone is disabled");
        Log_CrawlerRow("ADeadCrawlerShedsItsLegsAndGoesOnBothMachines", "struck");
        WaitUntil(n"Is_CrawlerGoneAndLimbsGone", n"OnServerAllGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_CrawlerGoneAndLimbsGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerGone() && Get_HasSeveredLimbLeft() == false);
    }

    UFUNCTION()
    private void OnServerAllGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hold_CrawlerServerRow("ADeadCrawlerShedsItsLegsAndGoesOnBothMachines", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_CrawlerDead", n"OnClientDead", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientDeadSettled");
    }

    UFUNCTION()
    private void OnClientDeadSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_CrawlerDied, 1, "the client's monster raised OnDied once");
        for (int32 Index = 0; Index < k_LegCount; ++Index)
        {
            Assert_True(Get_IsPartState(Index, EMars_BodyPart_State::Severed), f"the client's part {Index} reads Severed");
            Assert_Equals_Int(_LegSignals[Index].Severed, 1, f"the client's part {Index} raised OnSevered once");
        }

        Assert_Equals_Int(Get_AttachedLegs(), 0, "no leg of the client's copy is attached");
        Assert_False(_Zone.Get_IsEnabled(), "the client's body zone is disabled");
        Assert_True(Get_BodyPoseStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's body pose reads Ready");
        Log_CrawlerRow("ADeadCrawlerShedsItsLegsAndGoesOnBothMachines", "dead");
        WaitUntil(n"Is_CrawlerGone", n"OnClientCopyGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientCopyGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EveryRigPartGone", n"OnClientAllGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAllGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Finish_CrawlerRow("ADeadCrawlerShedsItsLegsAndGoesOnBothMachines", "");
    }
}
