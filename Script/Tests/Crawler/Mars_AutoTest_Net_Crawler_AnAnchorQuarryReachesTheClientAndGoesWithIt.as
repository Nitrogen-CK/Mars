// A hunt anchor, local to the server, resolves its pinned row 0 as the quarry: its crawler spawns under the replicated
// spawn owner and replicates, aggressive, homed on the anchor's 1000 cm. The client's copy is the server's (no
// authority, the anchor's HomeRadius and the same RoamBounds, its gait Ready). Two seconds on, the server clears the
// anchor: its quarry is pending destroy within 0.5 s, and the client's copy is gone within 2 s of the clear.
// Surface: Ck.Crawler.Net.AS_Crawler_AnAnchorQuarryReachesTheClientAndGoesWithIt
class UCk_AutoTest_Net_Crawler_AnAnchorQuarryReachesTheClientAndGoesWithIt : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(851000.0, 0.0, 5000.0);
    private const FString k_Row = "AnAnchorQuarryReachesTheClientAndGoesWithIt";
    private const float32 k_HuntHomeRadius = 1000.0f;
    private const float32 k_HoldSeconds = 2.0f;
    // The clear is announced this many frames ahead, so the mark reaches the client before the destroy does.
    private const int32 k_ClearLeadFrames = 30;
    private const float64 k_PendingWithinSeconds = 0.5;
    private const float64 k_CopyGoneWithinSeconds = 2.0;

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
        Begin_CrawlerRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private FString Describe_Quarry()
    {
        return f"quarry=[clearAt {_ClearAtFrame} cleared {_ClearedFrame} pending {_PendingFrame} copyGone {_CopyGoneFrame}] {Describe_Anchor()}";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerAnchor(UMars_Anchor_Hunt_EntityScript, 0, EMars_Anchor_Role::Quarry);
        WaitUntil(n"Is_ServerQuarrySettled", n"OnServerQuarrySettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerQuarrySettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound() && Get_IsAnchorsCrawler() && Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready
            && _CrawlerMonster.Get_Parts().Num() == _LegCount);
    }

    UFUNCTION()
    private void OnServerQuarrySettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(utils_net::Get_HasAuthority(_CrawlerRoot), "the server has authority over its quarry");
        Assert_True(utils_mars_net::Get_ReplicatesHere(_CrawlerRoot), "the server's quarry replicates");
        Assert_True(_CrawlerRoot.Get_LifetimeOwner() != _Anchor, "the quarry lives under the spawn owner, not the anchor");
        Assert_True(_Crawler.Get_IsAggressive(), "the server's quarry is aggressive");
        Assert_True(Math::IsNearlyEqual(_Crawler.Get_Spec().Combat.Targeting.HomeRadius, k_HuntHomeRadius, 0.01f),
            f"the server's quarry is homed on the anchor's 1000 ({_Crawler.Get_Spec().Combat.Targeting.HomeRadius})");
        Publish_ServerReadout();
        WaitSampling(k_HoldSeconds, n"OnServerHeldBeforeClear");
    }

    UFUNCTION()
    private void OnServerHeldBeforeClear(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
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
        WaitUntil(n"Is_ServerQuarryPending", n"OnServerQuarryPending", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerQuarryPending(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        if (_PendingFrame < 0 && Get_IsCrawlerGone())
        { _PendingFrame = int32(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(_PendingFrame >= 0 || Get_SecondsBetweenFrames(_ClearedFrame, int32(utils_time::Get_FrameCounter())) > 1.0);
    }

    UFUNCTION()
    private void OnServerQuarryPending(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Pending = Get_SecondsBetweenFrames(_ClearedFrame, _PendingFrame);
        Assert_True(_PendingFrame >= 0 && Pending <= k_PendingWithinSeconds,
            f"the server's quarry was pending destroy within 0.5 s of the clear ({Pending} s)");
        Assert_True(_ClearedFrame - _ClearAtFrame <= 1, f"the server cleared on the announced frame ({_ClearedFrame} against {_ClearAtFrame})");
        Hold_CrawlerServerRow(k_Row, Describe_Quarry());
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
        const auto Home = _Crawler.Get_Spec().Combat.Targeting.HomeRadius;
        Assert_True(Math::IsNearlyEqual(Home, k_HuntHomeRadius, 0.01f) && Math::IsNearlyEqual(Home, _Readout.HomeRadius, 0.01f),
            f"the client's quarry has the anchor's HomeRadius 1000 ({Home}, server {_Readout.HomeRadius})");
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
            f"the client's quarry went within 2 s of the server's clear ({AfterClear} s, clear frame {ClearAt}, gone {_CopyGoneFrame})");
        Finish_CrawlerRow(k_Row, f"{Describe_Quarry()} {Describe_Readout()}");
    }
}
