// The server hits leg 0 of a spider that stays put (Sever 20, 0.3 s apart, its limb living 8 s) until its part severs.
// The server's one limb has three pieces (two segments and the foot), a body per piece and every joint added; over its
// life its widest joint gap outside spin-spike windows stays within the spider's tolerance (3 cm), no piece touches
// another of the same limb, no piece sinks more than 2 below the floor, and it reads at rest within 6 s of its first
// frame. On the client leg 0 leaves its copy (OnSevered once within ten frames, five legs still attached, gait Ready),
// one copy limb of three pieces arrives, and at rest every piece is within 3 cm and 3 degrees of the server's published
// rest pose with every joint gap within 4 cm. The client's limb is gone within 1 s of the server's.
// Surface: Ck.Crawler.Net.AS_Crawler_ASpidersSeveredLegFallsLimpOnBothMachines
class UCk_AutoTest_Net_Crawler_ASpidersSeveredLegFallsLimpOnBothMachines : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(845000.0, 0.0, 5000.0);
    private const FString k_Row = "ASpidersSeveredLegFallsLimpOnBothMachines";
    private const float32 k_LimbSeconds = 8.0f;
    private const int32 k_LimbPieces = 3;
    private const float64 k_RestWithinSeconds = 6.0;
    private const float64 k_GoneWithinSeconds = 1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _LegCount = 6;
        _Layout = EMars_Crawler_Layout::Spider;
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
        Spec.Vitals.LegDebris.LifetimeSeconds = k_LimbSeconds;
        Spawn_ServerCrawler(Spec);
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerReadout();
        WaitSampling(k_ComposeSeconds, n"OnServerHitDue");
    }

    // One hit every 0.3 s while leg 0 is attached, at most four.
    UFUNCTION()
    private void OnServerHitDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPartState(0, EMars_BodyPart_State::Severed))
        {
            Follow_ServerLeg0Limb(k_Row);
            return;
        }

        if (_LegActions >= k_MaxLegHits)
        {
            Log_CrawlerRow(k_Row, "");
            FinishFailure(f"{_LegActions} hits and the server's leg 0 is still attached");
            return;
        }

        _LegActions += 1;
        Hit_ServerLeg(0, k_LegHit);
        WaitSampling(k_LegHitSpacingSeconds, n"OnServerHitDue");
    }

    protected void Assert_ServerLimbTail() override
    {
        Publish_ServerMark("LimbsGone", int32(utils_time::Get_FrameCounter()));
        Assert_Equals_Int(_Limbs.Num(), 1, "the server saw one limb");
        if (_Limbs.Num() == 0)
        { return; }

        const auto Record = _Limbs[0];
        Assert_Equals_Int(Record.PieceCount, k_LimbPieces, "the server's limb has three pieces (two segments and the foot)");
        Assert_True(Record.ContactsBound, "the server watched its limb's piece bodies for contacts");
        Assert_Equals_Int(Record.NeighbourContacts, 0, "no piece of the server's limb touched another piece of the same limb");
        Assert_True(Record.LowestOverFloor >= -k_BelowFloorCm, f"no piece of the server's limb sank more than 2 below the floor (lowest {Record.LowestOverFloor})");
        Assert_True(Record.RestSeconds >= 0.0 && Record.RestSeconds - Record.FirstSeconds <= k_RestWithinSeconds,
            f"the server's limb read at rest within 6 s ({Record.RestSeconds - Record.FirstSeconds} s)");
        Assert_Equals_Int(_CrawlerMonster.Get_AttachedPartCount(), _LegCount - 1, "the server's spider has five attached parts");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_ServerMark("", n"OnClientReadout");
    }

    UFUNCTION()
    private void OnClientReadout(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_CopyLikeTheServer();
        Follow_ClientLeg0Sever(k_Row);
    }

    // Once its limb is gone: the server's went within a second of it.
    protected void Finish_ClientLeg0Row() override
    {
        Await_ServerMark("LimbsGone", n"OnClientServerLimbGone");
    }

    UFUNCTION()
    private void OnClientServerLimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Limbs.Num(), 1, "the client saw one limb");
        auto Apart = -1.0;
        if (_Limbs.Num() > 0)
        {
            Assert_Equals_Int(_Limbs[0].PieceCount, k_LimbPieces, "the client's limb has three pieces");
            const auto ServerGone = Get_ClockSecondsAtFrame(Get_ServerMark("LimbsGone"));
            Apart = _Limbs[0].GoneSeconds - ServerGone;
            Assert_True(ServerGone >= 0.0 && Math::Abs(Apart) <= k_GoneWithinSeconds,
                f"the client's limb went within 1 s of the server's ({Apart} s)");
        }

        Finish_CrawlerRow(k_Row, f"goneApart={Apart} severedFrame={_ClientSeveredFrame} {Describe_Readout()}");
    }
}
