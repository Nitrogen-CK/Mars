// The client, armed with the server's cleaver, claims blows on leg 0 of a crawler that stays put with that leg's
// rest foot 60 in front of its hand (0.6 s apart, each at its own copy's last segment of leg 0) until its part 0
// reads Severed. The server applied at least one claim and refused none, and its part 0 severed once. On the client
// leg 0 left its copy within ten frames, OnSevered raised once and its zone off; a second later the three other legs
// walk on, and its body Health raised OnDamaged (the spill). From the sever on, both machines follow the one limb as
// the host's sever row does.
// Surface: Ck.Crawler.Net.AS_Crawler_AClientsBlowsSeverTheLegOnBothMachines
class UCk_AutoTest_Net_Crawler_AClientsBlowsSeverTheLegOnBothMachines : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(833000.0, 0.0, 5000.0);

    private float64 _ClaimDueAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerStrikeRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToClaimALeg", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Arm_Server();
        WaitUntil(n"Is_Armed", n"OnServerArmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCrawler(Make_RowSpec(k_StaysPut));
        WaitUntil(n"Is_Leg0Severed", n"OnServerSevered", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSevered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Follow_ServerLeg0Limb("AClientsBlowsSeverTheLegOnBothMachines");
    }

    protected void Assert_ServerLimbTail() override
    {
        const auto Tally = Get_Tally();
        Assert_True(Tally.Applied >= 1, f"the server applied at least one claim ({Tally.Applied})");
        Assert_Equals_Int(Tally.Refused, 0, "the server refused no claim");
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Severed), "the server's part 0 is Severed");
        Assert_Equals_Int(_LegSignals[0].Severed, 1, "the server's part 0 raised OnSevered once");
    }

    UFUNCTION()
    private void Is_ClientReadyToClaimALeg(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsArmed() && Get_IsCrawlerFound()
            && Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready);
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientClaimDue");
    }

    // One claim every 0.6 s while part 0 is attached, at most six.
    UFUNCTION()
    private void OnClientClaimDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPartState(0, EMars_BodyPart_State::Severed))
        {
            _ExpectBodySpill = true;
            Follow_ClientLeg0Sever("AClientsBlowsSeverTheLegOnBothMachines");
            return;
        }

        if (_LegActions >= k_MaxLegClaims)
        {
            Log_CrawlerRow("AClientsBlowsSeverTheLegOnBothMachines", "");
            FinishFailure(f"{_LegActions} claims and the client's part 0 is still attached");
            return;
        }

        _LegActions += 1;
        const auto Claim = Make_LegClaim(0);
        _RowExtra += f"claim={(Claim.Location - Get_HandLocation()).Size()}@{utils_time::Get_FrameCounter()} ";
        Fire_Claim(Claim);
        _ClaimDueAt = Get_WorldSeconds() + k_ClaimSpacingSeconds;
        WaitUntil(n"Is_ClaimDueOrSevered", n"OnClientClaimDue", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClaimDueOrSevered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsPartState(0, EMars_BodyPart_State::Severed) || Get_WorldSeconds() >= _ClaimDueAt);
    }
}
