// The server hits leg 0 of a settled crawler that stays put (Sever 20, 0.3 s apart) until its part severs, and samples
// its limb from its first frame until it is gone: a knee moved more than 5 degrees from its angle at the cut and never
// beyond 70, the widest joint gap stayed within 2 cm, no piece's body touched another piece of the same limb, and the
// first piece ended more than 30 from where it started. The
// client samples its copy's limb from the first frame it sees it until it reads at rest: a knee moved more than 5 degrees
// from the angle it had when first seen, at least 5 ledger notifies arrived before the one that read at rest, and at
// rest every joint gap is within 4 cm. Its widest gap in flight is logged. Each machine ends once no limb is near.
// Surface: Ck.Crawler.Net.AS_Crawler_ASeveredLimbFallsLimpOnBothMachines
class UCk_AutoTest_Net_Crawler_ASeveredLimbFallsLimpOnBothMachines : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(837000.0, 0.0, 5000.0);
    private const float64 k_FirstPieceLeastTravel = 30.0;
    private const int32 k_LeastNotifiesBeforeRest = 5;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerRow(k_Base);
        _LimbRow = "ASeveredLimbFallsLimpOnBothMachines";

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
            Follow_ServerLeg0Limb("ASeveredLimbFallsLimpOnBothMachines");
            return;
        }

        if (_LegActions >= k_MaxLegHits)
        {
            Log_CrawlerRow("ASeveredLimbFallsLimpOnBothMachines", "");
            FinishFailure(f"{_LegActions} hits and the server's leg 0 is still attached");
            return;
        }

        _LegActions += 1;
        Hit_ServerLeg(0, k_LegHit);
        WaitSampling(k_LegHitSpacingSeconds, n"OnServerHitDue");
    }

    protected void Assert_ServerLimbTail() override
    {
        if (_Limbs.Num() == 0)
        { return; }

        const auto Record = _Limbs[0];
        auto Widest = 0.0;
        for (auto Swing : Record.KneeSwing)
        { Widest = Math::Max(Widest, Swing); }

        Assert_True(Widest > k_KneeLeastSwingDegrees, f"a server knee moved {Widest} deg from its angle at the cut (more than {k_KneeLeastSwingDegrees})");
        Assert_True(Widest <= k_KneeMostSwingDegrees, f"no server knee moved beyond {k_KneeMostSwingDegrees} deg (the most {Widest})");
        const auto Travel = (Record.FirstPieceLast - Record.FirstPieceStart).Size();
        Assert_True(Travel > k_FirstPieceLeastTravel, f"the server's first piece ended {Travel} from where it started (more than {k_FirstPieceLeastTravel})");
        Assert_True(Record.ContactsBound, "the server watched its limb's piece bodies for contacts");
        Assert_Equals_Int(Record.NeighbourContacts, 0, "no piece of the server's limb touched another piece of the same limb");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EveryLimbAtRest", n"OnClientLimbAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLimbAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Limbs.Num(), 1, "the client saw one limb");
        if (_Limbs.Num() > 0)
        {
            const auto Record = _Limbs[0];
            auto Widest = 0.0;
            for (auto Swing : Record.KneeSwing)
            { Widest = Math::Max(Widest, Swing); }

            Assert_True(Widest > k_KneeLeastSwingDegrees, f"a client knee moved {Widest} deg from the angle it had when first seen (more than {k_KneeLeastSwingDegrees})");
            Assert_True(Record.NotifiesBeforeRest >= k_LeastNotifiesBeforeRest,
                f"{Record.NotifiesBeforeRest} ledger notifies reached the client before the one that read at rest (at least {k_LeastNotifiesBeforeRest})");
        }

        for (auto Limb : Get_LimbsNear())
        {
            const auto Gaps = Get_LimbJointGaps(Limb);
            for (int32 Index = 0; Index < Gaps.Num(); ++Index)
            { Assert_True(Gaps[Index] <= k_CopyGapCm, f"the client's joint {Index} gap {Gaps[Index]} is at most {k_CopyGapCm} at rest"); }
        }

        Log_CrawlerRow("ASeveredLimbFallsLimpOnBothMachines", "limbAtRest");
        WaitUntil(n"Is_SeveredLimbsGone", n"OnClientLimbGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Finish_CrawlerRow("ASeveredLimbFallsLimpOnBothMachines", "");
    }
}
