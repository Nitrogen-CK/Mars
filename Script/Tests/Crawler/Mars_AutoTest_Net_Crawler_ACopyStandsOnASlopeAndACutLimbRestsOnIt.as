// Both machines lay a floor that falls 12 degrees toward +X; a four-leg crawler stands on it, staying put. Over two
// seconds of its feet the client's copy plants every foot within 5 of the slope's plane, always trusts at least two
// contacts and its gait never reads Failed. Then the server hits leg 0 (its foot on the downhill side) until its part
// severs: the server's one limb, of three pieces, keeps every joint within 2 cm, touches no piece of itself, sinks no
// piece more than 2 below the slope and reads at rest within 6 s; the client's copy limb at rest has every piece within
// 3 cm and 3 degrees of the server's published rest pose, none below the slope, every joint within 4 cm. The limb's
// birth lift is logged.
// Surface: Ck.Crawler.Net.AS_Crawler_ACopyStandsOnASlopeAndACutLimbRestsOnIt
class UCk_AutoTest_Net_Crawler_ACopyStandsOnASlopeAndACutLimbRestsOnIt : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(846000.0, 0.0, 5000.0);
    private const FString k_Row = "ACopyStandsOnASlopeAndACutLimbRestsOnIt";
    private const float64 k_SlopeDegrees = 12.0;
    private const float32 k_ServerFeetSeconds = 2.0f;
    private const float32 k_ClientFeetSeconds = 1.5f;
    private const float64 k_PlantedOff = 5.0;
    private const int32 k_LeastTrusted = 2;
    private const int32 k_LimbPieces = 3;
    private const float64 k_RestWithinSeconds = 6.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _FloorPitchDegrees = k_SlopeDegrees;
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
        Publish_ServerReadout();
        Begin_FeetRecord();
        WaitSampling(k_ServerFeetSeconds, n"OnServerFeetRecorded");
    }

    UFUNCTION()
    private void OnServerFeetRecorded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _FeetRecording = false;
        _RowExtra = f"serverFeetBeforeTheCut={Describe_Feet()}";
        OnServerHitDue(InTimer, InChrono, InDeltaT);
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
        Assert_Equals_Int(_Limbs.Num(), 1, "the server saw one limb");
        if (_Limbs.Num() == 0)
        { return; }

        const auto Record = _Limbs[0];
        Assert_Equals_Int(Record.PieceCount, k_LimbPieces, "the server's limb has three pieces");
        Assert_True(Record.ContactsBound, "the server watched its limb's piece bodies for contacts");
        Assert_Equals_Int(Record.NeighbourContacts, 0, "no piece of the server's limb touched another piece of the same limb");
        Assert_True(Record.LowestOverFloor >= -k_BelowFloorCm, f"no piece of the server's limb sank more than 2 below the slope (lowest {Record.LowestOverFloor})");
        Assert_True(Record.RestSeconds >= 0.0 && Record.RestSeconds - Record.FirstSeconds <= k_RestWithinSeconds,
            f"the server's limb read at rest within 6 s ({Record.RestSeconds - Record.FirstSeconds} s)");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_ServerMark("", n"OnClientReadout");
    }

    UFUNCTION()
    private void OnClientReadout(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_CrawlerSettled", n"OnClientSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_FeetRecord();
        WaitSampling(k_ClientFeetSeconds, n"OnClientFeetRecorded");
    }

    UFUNCTION()
    private void OnClientFeetRecorded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _FeetRecording = false;
        _RowExtra = f"clientFeetBeforeTheCut={Describe_Feet()}";
        Assert_CopyLikeTheServer();
        Assert_True(_FeetFrames > 0 && _FeetWorstPlanted <= k_PlantedOff,
            f"the client's planted feet stood within 5 of the slope ({_FeetWorstPlanted} over {_FeetFrames} frames)");
        Assert_True(_FeetLowestTrusted >= k_LeastTrusted, f"the client's gait always trusted at least two contacts (lowest {_FeetLowestTrusted})");
        Assert_False(_CrawlerGaitEverFailed, "the client's gait never read Failed on the slope");
        Follow_ClientLeg0Sever(k_Row);
    }
}
