// The expedition spider, its placement class (six legs, its spider layout, aggressive, its court-wide radii and the
// spider's parity loadout) spawned through the channel a spawner with authority queues it under, 300 from where the
// server spawns the production pawn. Once the client's controller possesses the pawn the spider takes it as its target
// within 5 s, closes in and strikes; after the pawn's first OnDamaged its aggression is switched off. The client's copy
// is the server's spider (its spec's layout, legs and AcquireRadius 1100) and played the attack that struck, with the
// server's attack, clip and slots; the pawn's Health and OnDamaged match on both machines.
// Surface: Ck.Crawler.Net.AS_Crawler_TheExpeditionSpiderHuntsAndStrikesAClientsPawn
class UCk_AutoTest_Net_Crawler_TheExpeditionSpiderHuntsAndStrikesAClientsPawn : UMars_AutoTestRig_NetCrawlerPawn
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(849000.0, 0.0, 5000.0);
    private const FVector k_PawnOffset = FVector(300.0, 0.0, 0.0);
    private const float32 k_TargetWithinSeconds = 5.0f;
    private const float32 k_ExpeditionAcquireRadius = 1100.0f;
    private const FString k_Row = "TheExpeditionSpiderHuntsAndStrikesAClientsPawn";

    private int32 _PossessFrame = -1;
    private float64 _PossessSeconds = -1.0;
    private float64 _TargetSeconds = -1.0;
    private int32 _StruckGeneration = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _LegCount = 6;
        _Layout = EMars_Crawler_Layout::Spider;
        Begin_CrawlerPawnRow(k_Base, k_PawnOffset);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerSettled", n"OnClientSettled", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private float32 Get_AppliedSum() const
    {
        auto Sum = 0.0f;
        for (const auto Amount : _BlowApplied)
        { Sum += Amount; }

        return Sum;
    }

    private FString Describe_Hunt()
    {
        auto PawnAt = FVector::ZeroVector;
        if (ck::IsValid(_BlowPlayer))
        { PawnAt = utils_transform::Get_EntityCurrentLocation(_BlowPlayer.As_Transform()); }

        const auto FromHome = (PawnAt - _CrawlerAt).Size2D();
        const auto FromCrawler = Get_IsCrawlerGone() ? -1.0 : (PawnAt - Get_RootLocation()).Size2D();
        const auto Rejection = Get_IsCrawlerGone() || ck::Is_NOT_Valid(_BlowPlayer) ? TOptional<EMars_Crawler_AttackReject>()
            : _Crawler.Get_StartRejection(_BlowPlayer);
        const auto RejectionText = Rejection.IsSet() ? f"{Rejection.GetValue() :n}" : FString("none");
        const auto Stage = Get_IsCrawlerGone() ? EMars_Crawler_EngageStage::None : _Crawler.Get_EngageStage();
        return f"hunt=[possessFrame {_PossessFrame} targetAfter {_TargetSeconds - _PossessSeconds} struck {_StruckGeneration} "
            + f"pawnFromHome {FromHome} pawnFromCrawler {FromCrawler} rejection {RejectionText} stage {Stage :n}] {Describe_BlowPawn()}";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Clearance = float64(utils_crawler::Get_LayoutClearance(_Layout));
        Spawn_ServerCrawlerAt(Make_RowSpec(k_StaysPut), UMars_Expedition_Crawler_EntityScript,
            FTransform(FRotator::ZeroRotator, _CrawlerAt + FVector(0.0, 0.0, Clearance)), false);
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerReadout();
        Begin_AttackRecord();
        Spawn_ServerBlowPawn();
        WaitUntil(n"Is_BlowPawnComposed", n"OnServerPawnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPawnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(ck::IsValid(_Crawler.Get_CombatTarget()), "the server's crawler holds no target before the possession");
        Assert_False(Get_BlowPawnHasTag(n"TAG_MarsSharedCombatTarget"), "the server's pawn carries no shared tag before the possession");
        if (Request_ServerPossessBlowPawn() == false)
        {
            Log_CrawlerRow(k_Row, f"remoteController=none {Describe_BlowPawn()}");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        _PossessFrame = int32(utils_time::Get_FrameCounter());
        _PossessSeconds = Get_WorldSeconds();
        WaitUntil(n"Is_ServerTargetChosen", n"OnServerTargetChosen", k_SlowPolls);
    }

    // The pawn became the crawler's combat target, or the time it had to did run out.
    UFUNCTION()
    private void Is_ServerTargetChosen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        Sample_BlowTarget();
        if (_BlowTargetFrame >= 0 && _TargetSeconds < 0.0)
        { _TargetSeconds = Get_WorldSeconds(); }

        auto Result = OutResult;
        Result.Set(_BlowTargetFrame >= 0 || Get_WorldSeconds() - _PossessSeconds > k_TargetWithinSeconds);
    }

    UFUNCTION()
    private void OnServerTargetChosen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_BlowTargetFrame < 0)
        {
            Log_CrawlerRow(k_Row, f"{Describe_Hunt()} {Describe_AttackState()}");
            FinishFailure("the server's crawler did not take the pawn as its target within 5 s of the possession");
            return;
        }

        WaitUntil(n"Is_ServerPawnStruck", n"OnServerPawnStruck", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPawnStruck(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerGone() == false && _BlowApplied.Num() > 0);
    }

    UFUNCTION()
    private void OnServerPawnStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _StruckGeneration = _Crawler.Get_AttackAdmission().AttemptGeneration;
        Request_ServerDisable();
        WaitSampling(1.0f, n"OnServerStruckSampled");
    }

    UFUNCTION()
    private void OnServerStruckSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerAttacks(_StruckGeneration, _BlowHealth.Get_Current(), _BlowApplied);
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSampling(2.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_CrawlerRow(k_Row, f"{Describe_Hunt()} {Describe_AttackState()}");
        Assert_True(_TargetSeconds >= 0.0 && _TargetSeconds - _PossessSeconds <= k_TargetWithinSeconds,
            f"the server's crawler took the pawn as its target within 5 s of the possession ({_TargetSeconds - _PossessSeconds} s)");
        Assert_True(Get_BlowPawnHasTag(n"TAG_MarsSharedCombatTarget"), "the server's pawn carries TAG_MarsSharedCombatTarget");
        Assert_False(Get_BlowPawnHasTag(n"TAG_MarsCombatTarget"), "the server's pawn carries no TAG_MarsCombatTarget (the host does not control it)");
        Assert_True(_BlowHealth.Get_Current() < 100.0f && Math::IsNearlyEqual(100.0f - _BlowHealth.Get_Current(), Get_AppliedSum(), 0.01f),
            f"the server's pawn's Health fell by exactly what was applied (reads {_BlowHealth.Get_Current()}, applied {Get_AppliedSum()})");
        Assert_True(_StruckGeneration > 0, "the blow came from an admitted attack");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerReturned");
    }

    UFUNCTION()
    private void OnServerReturned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TearDown_BlowPawn();
        FinishSuccess();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_AttackRecord();
        Await_ServerMark("", n"OnClientReadout");
    }

    UFUNCTION()
    private void OnClientReadout(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_CopyLikeTheServer();
        const auto Spec = _Crawler.Get_Spec();
        Assert_True(Spec.Layout == EMars_Crawler_Layout::Spider && Spec.LegCount == 6, f"the client's copy is the six-leg spider ({Spec.Layout :n} {Spec.LegCount})");
        Assert_True(Math::IsNearlyEqual(Spec.Combat.Targeting.AcquireRadius, k_ExpeditionAcquireRadius, 0.01f),
            f"the client's copy has the expedition's AcquireRadius 1100 ({Spec.Combat.Targeting.AcquireRadius})");
        WaitUntil(n"Is_ClientPawnHurt", n"OnClientHurt", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientPawnHurt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsBlowPawnComposed() && _BlowPawn.IsLocallyControlled() && _BlowApplied.Num() > 0);
    }

    UFUNCTION()
    private void OnClientHurt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_ServerAttacks(n"OnClientArrived");
    }

    UFUNCTION()
    private void OnClientArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsCrawlerGone())
        { FinishFailure("the client's copy was gone before it asserted"); TearDown_BlowPawn(); return; }

        Log_CrawlerRow(k_Row, f"{Describe_Hunt()} {Describe_AttackState()} {Describe_ServerAttacks()} {Describe_Readout()}");
        Assert_CopyKeepsNoAttackOfItsOwn();
        const auto Readout = Get_ServerAttacks();
        Assert_True(Get_HasServerAttacks(), "the server's readout reached the client");
        Assert_True(_BlowPawn.IsLocallyControlled(), "the client controls its copy of the pawn");
        Assert_True(Math::IsNearlyEqual(_BlowHealth.Get_Current(), Readout.PawnHealth, 0.01f) && _BlowHealth.Get_Current() < 100.0f,
            f"the client's pawn's Health equals the server's and is below 100 (reads {_BlowHealth.Get_Current()}, server {Readout.PawnHealth})");
        auto SameAmounts = _BlowApplied.Num() == Readout.PawnApplied.Num();
        for (int32 Index = 0; Index < _BlowApplied.Num() && SameAmounts; ++Index)
        { SameAmounts = Math::IsNearlyEqual(_BlowApplied[Index], Readout.PawnApplied[Index], 0.01f); }

        Assert_True(SameAmounts, f"the client's pawn raised OnDamaged as often as the server's, with the same amounts ({_BlowApplied.Num()} against {Readout.PawnApplied.Num()})");
        Assert_False(_BlowHealth.Get_IsDepleted(), "the client's pawn is not depleted");

        const auto Index = Find_Attack(Readout.StruckGeneration, false);
        Assert_True(Readout.StruckGeneration > 0 && Index >= 0, f"the client's copy recorded the attack that struck (gen {Readout.StruckGeneration})");
        if (Index >= 0)
        {
            Assert_Equals_Int(_Attacks[Index].Admitted, 1, "the client's copy raised Admitted once for the attack that struck");
            Assert_True(_Attacks[Index].Started > 0, "the client's copy started an action for the attack that struck");
            for (const auto& Server : Readout.Attacks)
            {
                if (Server.Generation != Readout.StruckGeneration)
                { continue; }

                const auto Record = _Attacks[Index];
                Assert_True(Record.AttackId == Server.AttackId && Record.SourceClip == Server.SourceClip && Record.Slots == Server.Slots,
                    f"the copy played the server's attack, clip and slots (copy {Record.AttackId.ToString()} {Record.SourceClip} {Record.Slots}; server {Server.AttackId.ToString()} {Server.SourceClip} {Server.Slots})");
            }
        }

        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_BlowPawn();
        FinishSuccess();
    }
}
