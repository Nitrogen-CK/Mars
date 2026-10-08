// The CookingFeed rig: a feed on a transform-only station root at an isolated origin, its release node 100 up (a test may
// move it). The rig is the test receiver: it records every signal (phases, releases with the release node's pose at that
// moment, settles, refusals, stock edges), and its steps answer the last release Accepted or Rejected.
UCLASS(Abstract)
class UMars_AutoTestRig_CookingFeed : UCk_AutoTest_Base
{
    protected const FVector k_Origin = FVector(-60000.0, 34000.0, -60000.0);
    protected const FVector k_ReleaseLocal = FVector(0.0, 0.0, 100.0);
    protected const int32 k_Stock = 6;

    protected FCk_Handle _Station;
    protected FCk_Handle_CookingFeed _Feed;
    protected FCk_Handle_SceneNode _ReleaseNode;
    protected FMars_CookingFeed_Spec _Spec;

    protected TArray<EMars_CookingFeed_Phase> _Phases;
    // Game time of each phase change, in parallel.
    protected TArray<float32> _PhaseTimes;
    protected TArray<FMars_CookingFeed_Release> _Releases;
    // The release node's world pose when each release was broadcast, in parallel.
    protected TArray<FTransform> _ReleaseNodeAtRelease;
    // In parallel: one entry per OnTransferSettled.
    protected TArray<FMars_CookingFeed_PieceId> _SettledPieces;
    protected TArray<EMars_CookingFeed_Settle> _Settles;
    protected TArray<EMars_CookingFeed_Refusal> _Refusals;
    // In parallel: one entry per OnStockChanged.
    protected TArray<int32> _StockAvailable;
    protected TArray<int32> _StockAdmitted;

    // Six pieces, quick timed phases, the default motion.
    protected FMars_CookingFeed_Spec Make_TestSpec()
    {
        return FMars_CookingFeed_Spec(
            FMars_CookingFeed_SupplySpec(k_Stock, k_Stock),
            FMars_CookingFeed_TimingSpec(0.1f, 0.05f, 0.1f, 0.1f),
            FMars_CookingFeed_MotionSpec());
    }

    protected void BuildFeed(FCk_Handle InHandle, FMars_CookingFeed_Spec InSpec)
    {
        _Station = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Station, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        _ReleaseNode = utils_scene_node::Create(Root, FTransform(k_ReleaseLocal));

        _Spec = InSpec;
        _Spec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode.As_Transform());
        _Feed = utils_cooking_feed::Add(_Station, _Spec);

        _Feed.BindTo_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnPhaseChanged"));
        _Feed.BindTo_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseRequested"));
        _Feed.BindTo_OnTransferSettled(FMars_Delegate_CookingFeed_OnTransferSettled(this, n"OnTransferSettled"));
        _Feed.BindTo_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnTransferRefused"));
        _Feed.BindTo_OnStockChanged(FMars_Delegate_CookingFeed_OnStockChanged(this, n"OnStockChanged"));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Requests
    //----------------------------------------------------------------------------------------------------------------------

    protected void Begin()
    {
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    protected void Cancel()
    {
        _Feed.Request_Cancel(FMars_Request_CookingFeed_Cancel());
    }

    protected void Reset()
    {
        _Feed.Request_Reset(FMars_Request_CookingFeed_Reset());
    }

    protected void Resolve(FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission)
    {
        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(InPieceId, InAdmission, "test receiver"));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_Begin(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin();
    }

    UFUNCTION()
    protected void Step_AcceptPending(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Releases.Num() > 0, "a release is pending");
        if (_Releases.Num() > 0)
        { Resolve(_Releases.Last().PieceId, EMars_CookingFeed_Admission::Accepted); }
    }

    UFUNCTION()
    protected void Step_RejectPending(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Releases.Num() > 0, "a release is pending");
        if (_Releases.Num() > 0)
        { Resolve(_Releases.Last().PieceId, EMars_CookingFeed_Admission::Rejected); }
    }

    UFUNCTION()
    protected void Check_AwaitingAdmission(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::AwaitAdmission);
    }

    UFUNCTION()
    protected void Check_Idle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Queries
    //----------------------------------------------------------------------------------------------------------------------

    protected int32 Get_SettleCount(EMars_CookingFeed_Settle InSettle) const
    {
        auto Count = 0;
        for (const auto Settle : _Settles)
        {
            if (Settle == InSettle)
            { Count += 1; }
        }

        return Count;
    }

    protected int32 Get_RefusalCount(EMars_CookingFeed_Refusal InRefusal) const
    {
        auto Count = 0;
        for (const auto Refusal : _Refusals)
        {
            if (Refusal == InRefusal)
            { Count += 1; }
        }

        return Count;
    }

    protected int32 Get_PhaseCount(EMars_CookingFeed_Phase InPhase) const
    {
        auto Count = 0;
        for (const auto Phase : _Phases)
        {
            if (Phase == InPhase)
            { Count += 1; }
        }

        return Count;
    }

    protected void Assert_Ledger(int32 InAvailable, int32 InAdmitted, const FString& InWhen)
    {
        Assert_Equals_Int(_Feed.Get_Available(), InAvailable, f"{InWhen}: available");
        Assert_Equals_Int(_Feed.Get_Admitted(), InAdmitted, f"{InWhen}: admitted");
        Assert_True(_Feed.Get_IsLedgerConsistent(), f"{InWhen}: the ledger is consistent (initial = available + reserved + admitted)");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers (the feed may be gone: they only record)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase)
    {
        _Phases.Add(InPhase);
        _PhaseTimes.Add(float32(System::GetGameTimeInSeconds()));
    }

    UFUNCTION()
    protected void OnReleaseRequested(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease)
    {
        _Releases.Add(InRelease);
        _ReleaseNodeAtRelease.Add(ck::IsValid(_ReleaseNode)
            ? utils_transform::Get_EntityCurrentTransform(_ReleaseNode.As_Transform()) : FTransform::Identity);
    }

    UFUNCTION()
    protected void OnTransferSettled(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle)
    {
        _SettledPieces.Add(InPieceId);
        _Settles.Add(InSettle);
    }

    UFUNCTION()
    protected void OnTransferRefused(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal)
    {
        _Refusals.Add(InRefusal);
    }

    UFUNCTION()
    protected void OnStockChanged(FCk_Handle_CookingFeed InFeed, int32 InAvailable, int32 InAdmitted)
    {
        _StockAvailable.Add(InAvailable);
        _StockAdmitted.Add(InAdmitted);
    }
}
