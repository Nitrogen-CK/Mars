// The server hits leg 0 of a crawler that stays put (Sever 20, 0.3 s apart) until its part severs. On the client the
// part reads Severed and within ten frames leg 0 left its copy, OnSevered raised once and its zone off; a second later
// the three other legs are attached, the gait and the body pose read Ready and the gait trusts a contact. The released
// rig parts are logged, not asserted. Each machine's limb dies on that machine before the row ends.
// Surface: Ck.Crawler.Net.AS_Crawler_AHostsSeverDropsTheLegOnBothMachines
class UCk_AutoTest_Net_Crawler_AHostsSeverDropsTheLegOnBothMachines : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(832000.0, 0.0, 5000.0);

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
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ComposeSeconds, n"OnServerHitDue");
    }

    // One hit every 0.3 s while leg 0 is attached, at most four.
    UFUNCTION()
    private void OnServerHitDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPartState(0, EMars_BodyPart_State::Severed))
        {
            WaitUntil(n"Is_SeveredLimbsGone", n"OnServerLimbGone", k_SlowPolls);
            return;
        }

        if (_LegActions >= k_MaxLegHits)
        {
            Log_CrawlerRow("AHostsSeverDropsTheLegOnBothMachines", "");
            FinishFailure(f"{_LegActions} hits and the server's leg 0 is still attached");
            return;
        }

        _LegActions += 1;
        Hit_ServerLeg(0, k_LegHit);
        WaitSampling(k_LegHitSpacingSeconds, n"OnServerHitDue");
    }

    UFUNCTION()
    private void OnServerLimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Segments = _LegRigs[0].Segments.Num();
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Severed), "the server's part 0 is Severed");
        Assert_Equals_Int(_LegSignals[0].Severed, 1, "the server's part 0 raised OnSevered once");
        Assert_Equals_Int(_LegSignals[0].Released, Segments + 1, "the server's sever released every segment and the foot");
        Assert_Equals_Int(_CrawlerMonster.Get_AttachedPartCount(), k_LegCount - 1, "the server's crawler has three attached parts");
        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the server's gait reads Ready");
        Hold_CrawlerServerRow("AHostsSeverDropsTheLegOnBothMachines", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Follow_ClientLeg0Sever("AHostsSeverDropsTheLegOnBothMachines");
    }
}
