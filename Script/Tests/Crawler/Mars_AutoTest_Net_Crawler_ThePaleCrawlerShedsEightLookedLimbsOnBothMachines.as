// The Room 5 pale crawler, its placed class at its placed spot (Room 5's own coordinates on this machine's floor) and
// wearing its look, through the channel a spawner with authority queues it under (corpse 3 s, limbs 8 s). Its copy's
// body sizes from the look's body mesh, as the server's does, not from the box. A 1000 hit kills it on the server: a
// second later it is dead with eight parts Severed and eight limbs near, each of three pieces, whose joints stay within
// the pale crawler's tolerance (4 cm) at every sample outside spin-spike windows; the spikes are counted and logged.
// The client's copy raises OnDied once and OnSevered once per part; it shows eight limbs, each the server's (its first
// piece within 10 cm of the server's at rest), each piece with the server's half extents and at rest within 3 cm and 3
// degrees of the server's pose; the crawler and its limbs go about when the server's do.
// Surface: Ck.Crawler.Net.AS_Crawler_ThePaleCrawlerShedsEightLookedLimbsOnBothMachines
class UCk_AutoTest_Net_Crawler_ThePaleCrawlerShedsEightLookedLimbsOnBothMachines : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(-3000.0, 0.0, 0.0);
    private const FVector k_PlacedAt = FVector(-2600.0, 350.0, 30.0);
    private const FString k_Row = "ThePaleCrawlerShedsEightLookedLimbsOnBothMachines";
    private const float32 k_CorpseSeconds = 3.0f;
    private const float32 k_LimbSeconds = 8.0f;
    private const float32 k_LethalBlow = 1000.0f;
    private const int32 k_LimbPieces = 3;
    private const FVector k_BoxBody = FVector(40.0, 30.0, 15.0);
    private const float64 k_PairCm = 10.0;
    // The server's crawler and limbs go between these after its hit (the limbs outlive the corpse); a copy's within a
    // second either side of them.
    private const float64 k_GoneEarliest = 7.5;
    private const float64 k_GoneLatest = 9.0;
    private const float64 k_CopySlack = 1.0;

    private float64 _HitSeconds = -1.0;
    private float64 _GoneAfterHit = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _LegCount = 8;
        _Layout = EMars_Crawler_Layout::PaleCrawler;
        _LimbNearCm = 1500.0;
        Begin_CrawlerRow(k_Base);
        _CrawlerAt = FVector(k_PlacedAt.X, k_PlacedAt.Y, k_Base.Z);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_CrawlerGoneAndLimbsGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerGone() && Get_HasSeveredLimbLeft() == false);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = Make_RowSpec(k_StaysPut);
        Spec.Vitals.CorpseSeconds = k_CorpseSeconds;
        Spec.Vitals.LegDebris.LifetimeSeconds = k_LimbSeconds;
        Spawn_ServerCrawlerAt(Spec, UMars_Sandbox_PaleCrawler8_EntityScript, FTransform(FRotator::ZeroRotator, k_PlacedAt), true);
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerReadout();
        WaitSampling(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(k_LethalBlow, GameplayTags::DamageType_Mars_Blunt)));
        _HitSeconds = Get_WorldSeconds();
        Publish_ServerMark("Hit", int32(utils_time::Get_FrameCounter()));
        WaitSampling(k_SettleSeconds, n"OnServerStruck");
    }

    UFUNCTION()
    private void OnServerStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_CrawlerMonster.Get_IsDead(), "the server's pale crawler is dead");
        for (int32 Index = 0; Index < _LegCount; ++Index)
        { Assert_True(Get_IsPartState(Index, EMars_BodyPart_State::Severed), f"the server's part {Index} is Severed"); }

        const auto Limbs = Get_LimbsNear();
        Assert_Equals_Int(Limbs.Num(), _LegCount, "eight limbs are near the server's base");
        for (auto Limb : Limbs)
        {
            const auto Pieces = Get_LimbPieces(Limb).Num();
            Assert_Equals_Int(Pieces, k_LimbPieces, "each server limb has three pieces");
            Assert_Equals_Int(Get_LimbBodies(Limb), Pieces, "every piece of each server limb carries a Jolt body");
            Assert_Equals_Int(Get_LimbJointsAdded(Limb), Pieces - 1, "every joint of each server limb is added");
        }

        Log_CrawlerRow(k_Row, "struck");
        WaitUntil(n"Is_CrawlerGoneAndLimbsGone", n"OnServerAllGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerAllGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _GoneAfterHit = Get_WorldSeconds() - _HitSeconds;
        Assert_Equals_Int(_Limbs.Num(), _LegCount, "the server saw eight limbs");
        const auto Bound = Get_AuthorityGapCm();
        for (int32 Index = 0; Index < _Limbs.Num(); ++Index)
        {
            const auto Record = _Limbs[Index];
            Assert_True(Record.WidestGap <= Bound, f"server limb {Index}'s widest joint gap outside spin-spike windows {Record.WidestGap} is at most {Bound}");
            Assert_True(Record.Diag.Samples > 0, f"server limb {Index}'s spin spikes were counted ({Record.Diag.Spikes})");
            Log_LimbDiag(Index);
        }

        Assert_True(_GoneAfterHit >= k_GoneEarliest && _GoneAfterHit <= k_GoneLatest,
            f"the server's crawler and limbs went {_GoneAfterHit} s after its hit ({k_GoneEarliest} to {k_GoneLatest})");
        Hold_CrawlerServerRow(k_Row, f"goneAfterHit={_GoneAfterHit}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

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
        Assert_CopyLikeTheServer();
        const auto Body = _Crawler.Get_Spec().Rig.BodyHalfExtents;
        Assert_True(Get_IsNearlyEqualVector(Body, _Readout.BodyHalfExtents, 0.01),
            f"the client's body half extents are the server's ({Body} against {_Readout.BodyHalfExtents})");
        Assert_False(Get_IsNearlyEqualVector(Body, k_BoxBody, 0.01), f"the client's body sizes from the look, not the box ({Body})");
        _RowExtra = f"body={Body}";
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
        for (int32 Index = 0; Index < _LegCount; ++Index)
        { Assert_Equals_Int(_LegSignals[Index].Severed, 1, f"the client's part {Index} raised OnSevered once"); }

        Log_CrawlerRow(k_Row, "dead");
        WaitUntil(n"Is_EveryCopyLimbAtRestAndPublished", n"OnClientLimbsAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_EveryCopyLimbAtRestAndPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Limbs = Get_LimbsNear();
        auto Ready = Limbs.Num() == _LegCount;
        for (auto Limb : Limbs)
        { Ready = Ready && Get_LimbIsAtRest(Limb) && Get_HasPublishedRestPose(Limb); }

        auto Result = OutResult;
        Result.Set(Ready || Get_HasSeveredLimbLeft() == false);
    }

    // Each copy limb is one server limb: the pose and half extents the server published on that limb's root.
    UFUNCTION()
    private void OnClientLimbsAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Limbs = Get_LimbsNear();
        Assert_Equals_Int(Limbs.Num(), _LegCount, "eight limbs are near the client's base at rest");
        FString Pairs = "";
        for (int32 LimbIndex = 0; LimbIndex < Limbs.Num(); ++LimbIndex)
        {
            const auto Limb = Limbs[LimbIndex];
            Assert_False(utils_net::Get_HasAuthority(Limb), f"the client's limb {LimbIndex} has no authority");
            if (Get_HasPublishedRestPose(Limb) == false)
            {
                Assert_True(false, f"the server's rest pose reached the client's limb {LimbIndex}");
                continue;
            }

            const auto Pieces = Get_LimbPieces(Limb);
            const auto Severed = Limb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
            const auto Published = Limb.Get_Fragment(FMars_TESTONLY_Fragment_SeveredLimb_RestPose);
            Assert_Equals_Int(Pieces.Num(), k_LimbPieces, f"the client's limb {LimbIndex} has three pieces");
            Assert_Equals_Int(Published.Pieces.Num(), Pieces.Num(), f"the client's limb {LimbIndex} has the server's piece count");
            if (Pieces.Num() == 0 || Published.Pieces.Num() == 0)
            { continue; }

            const auto Pair = (utils_transform::Get_EntityCurrentLocation(Pieces[0]) - Published.Pieces[0].GetLocation()).Size();
            Pairs += f"{Pair},";
            Assert_True(Pair <= k_PairCm, f"the client's limb {LimbIndex} pairs to the server's by its first piece ({Pair} cm)");
            for (int32 Index = 0; Index < Pieces.Num() && Index < Published.Pieces.Num() && Index < Published.HalfExtents.Num(); ++Index)
            {
                const auto Mine = utils_transform::Get_EntityCurrentTransform(Pieces[Index]);
                const auto Distance = (Mine.GetLocation() - Published.Pieces[Index].GetLocation()).Size();
                const auto Degrees = Math::RadiansToDegrees(Mine.GetRotation().AngularDistance(Published.Pieces[Index].GetRotation()));
                Assert_True(Distance <= k_RestPoseCm && Degrees <= k_RestPoseDegrees,
                    f"the client's limb {LimbIndex} piece {Index} is {Distance} cm and {Degrees} deg from the server's rest pose");
                const auto Extents = Severed.Get_PieceHalfExtents(Index);
                Assert_True(Get_IsNearlyEqualVector(Extents, Published.HalfExtents[Index], 0.01),
                    f"the client's limb {LimbIndex} piece {Index} has the server's half extents ({Extents} against {Published.HalfExtents[Index]})");
            }
        }

        _RowExtra += f" pairs={Pairs}";
        WaitUntil(n"Is_CrawlerGoneAndLimbsGone", n"OnClientAllGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAllGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HitSeconds = Get_ClockSecondsAtFrame(Get_ServerMark("Hit"));
        const auto GoneAfterHit = HitSeconds < 0.0 ? -1.0 : Get_WorldSeconds() - HitSeconds;
        Assert_True(GoneAfterHit >= k_GoneEarliest - k_CopySlack && GoneAfterHit <= k_GoneLatest + k_CopySlack,
            f"the client's crawler and limbs went {GoneAfterHit} s after the server's hit (within a second of the server's window)");
        Finish_CrawlerRow(k_Row, f"goneAfterHit={GoneAfterHit} {Describe_Readout()}");
    }
}
