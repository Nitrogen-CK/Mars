// The client asks its copy of a crawler that stays put to sever part 0 and to take 50 damage on its body Health: a
// machine without authority drops both, so its copy keeps four attached legs, part 0 Attached and a body Health of 120,
// raises no OnSevered and holds no part or Health requests; the server's crawler never changes.
// Surface: Ck.Crawler.Net.AS_Crawler_AClientsRequestsAreDropped
class UCk_AutoTest_Net_Crawler_AClientsRequestsAreDropped : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(836000.0, 0.0, 5000.0);
    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const float32 k_ClientDamage = 50.0f;

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
        Spawn_ServerCrawler(Make_RowSpec(k_StaysPut));
        WaitUntil(n"Is_CrawlerFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_CrawlerMonster.Get_AttachedPartCount(), k_LegCount, "the server's crawler has four attached parts");
        Assert_True(Math::IsNearlyEqual(_Health.Get_Current(), 120.0f, 0.01f), "the server's body Health reads 120");
        for (int32 Index = 0; Index < k_LegCount; ++Index)
        { Assert_Equals_Int(_LegSignals[Index].Severed, 0, f"the server's part {Index} raised no OnSevered"); }

        Hold_CrawlerServerRow("AClientsRequestsAreDropped", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Part = _LegParts[0];
        Part.Request_Sever(FMars_Request_BodyPart_Sever(FMars_DamageEvent(30.0f, GameplayTags::DamageType_Mars_Sever)));
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(k_ClientDamage, GameplayTags::DamageType_Mars_Blunt)));
        WaitSampling(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_AttachedLegs(), k_LegCount, "the client's four legs are attached");
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Attached), "the client's part 0 reads Attached");
        Assert_True(Math::IsNearlyEqual(_Health.Get_Current(), 120.0f, 0.01f), "the client's body Health reads 120");
        for (int32 Index = 0; Index < k_LegCount; ++Index)
        { Assert_Equals_Int(_LegSignals[Index].Severed, 0, f"the client's part {Index} raised no OnSevered"); }

        Assert_False(_LegParts[0].Has_Fragment(FMars_Fragment_BodyPart_Requests), "the client's leg 0 holds no part requests");
        Assert_False(_CrawlerRoot.Has_Fragment(FMars_Fragment_Health_Requests), "the client's root holds no Health requests");
        Finish_CrawlerRow("AClientsRequestsAreDropped", "");
    }
}
