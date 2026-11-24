// A threat anchor, local to the server, resolves its pinned row 0: its sentry crawler spawns under the replicated spawn
// owner and replicates, homed on the anchor's 600 cm. The client's copy is the server's (no authority, four legs, the
// anchor's HomeRadius and the same RoamBounds) and no anchor exists on the client. The production pawn 300 from it is
// possessed by the client's controller; within 5 s the sentry takes it as its target. Its aggression is switched off and
// the server clears the anchor: its crawler is pending destroy within 0.5 s, and the client's copy is gone within 2 s
// of the clear.
// Surface: Ck.Crawler.Net.AS_Crawler_AnAnchorSentryReachesTheClientAndHuntsIt
class UCk_AutoTest_Net_Crawler_AnAnchorSentryReachesTheClientAndHuntsIt : UMars_AutoTestRig_NetCrawlerPawn
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(850000.0, 0.0, 5000.0);
    private const FVector k_PawnOffset = FVector(300.0, 0.0, 0.0);
    private const FString k_Row = "AnAnchorSentryReachesTheClientAndHuntsIt";
    private const float32 k_ThreatHomeRadius = 600.0f;
    private const float64 k_TargetWithinSeconds = 5.0;
    // The clear is announced this many frames ahead, so the mark reaches the client before the destroy does.
    private const int32 k_ClearLeadFrames = 30;
    private const float64 k_PendingWithinSeconds = 0.5;
    private const float64 k_CopyGoneWithinSeconds = 2.0;

    private float64 _PossessSeconds = -1.0;
    private int32 _ClearAtFrame = -1;
    private int32 _ClearedFrame = -1;
    private int32 _PendingFrame = -1;
    private int32 _CopyGoneFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _Runner = InHandle;
        Begin_CrawlerPawnRow(k_Base, k_PawnOffset);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private FString Describe_Sentry()
    {
        return f"sentry=[clearAt {_ClearAtFrame} cleared {_ClearedFrame} pending {_PendingFrame} copyGone {_CopyGoneFrame} "
            + f"targetFrame {_BlowTargetFrame}] {Describe_Anchor()} {Describe_BlowPawn()}";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerAnchor(UMars_Anchor_Threat_EntityScript, 0, EMars_Anchor_Role::Other);
        WaitUntil(n"Is_ServerSentrySettled", n"OnServerSentrySettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSentrySettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound() && Get_IsAnchorsCrawler() && Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready
            && _CrawlerMonster.Get_Parts().Num() == _LegCount);
    }

    UFUNCTION()
    private void OnServerSentrySettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(utils_net::Get_HasAuthority(_CrawlerRoot), "the server has authority over its sentry");
        Assert_True(utils_mars_net::Get_ReplicatesHere(_CrawlerRoot), "the server's sentry replicates");
        Assert_True(_CrawlerRoot.Get_LifetimeOwner() != _Anchor, "the sentry lives under the spawn owner, not the anchor");
        Assert_True(Math::IsNearlyEqual(_Crawler.Get_Spec().Combat.Targeting.HomeRadius, k_ThreatHomeRadius, 0.01f),
            f"the server's sentry is homed on the anchor's 600 ({_Crawler.Get_Spec().Combat.Targeting.HomeRadius})");
        Publish_ServerReadout();
        Begin_AttackRecord();
        Spawn_ServerBlowPawn();
        WaitUntil(n"Is_BlowPawnComposed", n"OnServerPawnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPawnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessBlowPawn() == false)
        {
            Log_CrawlerRow(k_Row, f"remoteController=none {Describe_Sentry()}");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        _PossessSeconds = Get_WorldSeconds();
        WaitUntil(n"Is_ServerTargetChosen", n"OnServerTargetChosen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTargetChosen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        Sample_BlowTarget();
        auto Result = OutResult;
        Result.Set(_BlowTargetFrame >= 0 || Get_WorldSeconds() - _PossessSeconds > k_TargetWithinSeconds);
    }

    UFUNCTION()
    private void OnServerTargetChosen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_BlowTargetFrame < 0)
        {
            Log_CrawlerRow(k_Row, f"{Describe_Sentry()} {Describe_AttackState()}");
            FinishFailure("the server's sentry did not take the pawn as its target within 5 s of the possession");
            return;
        }

        Request_ServerDisable();
        _ClearAtFrame = int32(utils_time::Get_FrameCounter()) + k_ClearLeadFrames;
        Publish_ServerMark("ClearAt", _ClearAtFrame);
        WaitUntil(n"Is_ServerClearDue", n"OnServerClearDue", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerClearDue(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(int32(utils_time::Get_FrameCounter()) >= _ClearAtFrame);
    }

    UFUNCTION()
    private void OnServerClearDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClearedFrame = int32(utils_time::Get_FrameCounter());
        Request_ServerClearAnchor();
        WaitUntil(n"Is_ServerSentryPending", n"OnServerSentryPending", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSentryPending(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        if (_PendingFrame < 0 && Get_IsCrawlerGone())
        { _PendingFrame = int32(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(_PendingFrame >= 0 || Get_SecondsBetweenFrames(_ClearedFrame, int32(utils_time::Get_FrameCounter())) > 1.0);
    }

    UFUNCTION()
    private void OnServerSentryPending(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Pending = Get_SecondsBetweenFrames(_ClearedFrame, _PendingFrame);
        Assert_True(_PendingFrame >= 0 && Pending <= k_PendingWithinSeconds,
            f"the server's sentry was pending destroy within 0.5 s of the clear ({Pending} s)");
        Assert_True(_ClearedFrame - _ClearAtFrame <= 1, f"the server cleared on the announced frame ({_ClearedFrame} against {_ClearAtFrame})");
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSampling(3.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_CrawlerRow(k_Row, Describe_Sentry());
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
        Assert_Equals_Int(Get_AttachedLegs(), 4, "the client's sentry stands on four legs");
        const auto Home = _Crawler.Get_Spec().Combat.Targeting.HomeRadius;
        Assert_True(Math::IsNearlyEqual(Home, k_ThreatHomeRadius, 0.01f) && Math::IsNearlyEqual(Home, _Readout.HomeRadius, 0.01f),
            f"the client's sentry has the anchor's HomeRadius 600 ({Home}, server {_Readout.HomeRadius})");
        WaitUntil(n"Is_ClientCopyGone", n"OnClientCopyGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientCopyGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerGone());
    }

    UFUNCTION()
    private void OnClientCopyGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _CopyGoneFrame = int32(utils_time::Get_FrameCounter());
        const auto ClearAt = Get_ServerMark("ClearAt");
        const auto AfterClear = Get_SecondsBetweenFrames(ClearAt, _CopyGoneFrame);
        Assert_True(ClearAt >= 0 && AfterClear >= 0.0 && AfterClear <= k_CopyGoneWithinSeconds,
            f"the client's sentry went within 2 s of the server's clear ({AfterClear} s, clear frame {ClearAt}, gone {_CopyGoneFrame})");
        Assert_Equals_Int(Count_AnchorsNear(), 0, "no anchor exists near the base on the client");
        Log_CrawlerRow(k_Row, f"{Describe_Sentry()} {Describe_Readout()}");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_BlowPawn();
        FinishSuccess();
    }
}
