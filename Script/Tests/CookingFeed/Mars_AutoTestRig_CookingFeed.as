// The CookingFeed rig, on the FoodPiece rig (pieces under the world's transient entity, tracked for cleanup): a feed on a
// transform-only station root at an isolated origin, its release node 100 up (a test may move it), and its stock: a
// platter (a plain Transform entity under the test, 200 to the side, the platter item's eight slots) loaded with k_Stock
// box pieces. Add_Steps_SourceTheFeed waits for the pieces to land and sources the feed. The rig is the test receiver and
// stands in for the station's bridge: it records every signal (phases, releases with the release node's pose at that
// moment, settles, refusals, stock edges), unloads a released piece from the platter at once, and puts a piece whose
// release was rejected or cancelled back on it. Its steps answer the last release Accepted or Rejected.
UCLASS(Abstract)
class UMars_AutoTestRig_CookingFeed : UMars_AutoTestRig_FoodPiece
{
    protected const FVector k_Origin = FVector(-60000.0, 34000.0, -60000.0);
    protected const FVector k_ReleaseLocal = FVector(0.0, 0.0, 100.0);
    protected const FVector k_PlatterLocal = FVector(0.0, 200.0, 0.0);
    protected const int32 k_Stock = 6;

    protected FCk_Handle _Station;
    protected FCk_Handle_CookingFeed _Feed;
    protected FCk_Handle_SceneNode _ReleaseNode;
    protected FMars_CookingFeed_Spec _Spec;
    protected FCk_Handle_Platter _Platter;
    // In load order (slot order once landed).
    protected TArray<FCk_Handle_FoodPiece> _Stock;

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

    // Quick timed phases, the default motion.
    protected FMars_CookingFeed_Spec Make_TestSpec()
    {
        return FMars_CookingFeed_Spec(
            FMars_CookingFeed_TimingSpec(0.1f, 0.05f, 0.1f, 0.1f),
            FMars_CookingFeed_MotionSpec());
    }

    // The feed (unsourced), and the platter with k_Stock box pieces asked onto it, each built at its own pose beside it.
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

        const UCk_InventoryItem_Definition PlatterItem = mars_items::Platter();
        const UMars_ItemTrait_Platter PlatterTrait = PlatterItem.Get_ItemTraitByClass(UMars_ItemTrait_Platter);

        auto PlatterEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(PlatterEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterLocal), ECk_Replication::DoesNotReplicate);
        _Platter = utils_platter::Add(PlatterEntity, PlatterTrait.Platter);

        for (int32 Index = 0; Index < k_Stock; ++Index)
        {
            const auto PieceWorld = FTransform(FRotator(0.0, 15.0 * float64(Index), 0.0),
                k_Origin + k_PlatterLocal + FVector(50.0, 30.0 * float64(Index), 0.0));
            auto Piece = Build_Piece(Get_BoxMesh(), PieceWorld, Make_Spec(0.1));
            _Stock.Add(Piece);
            _Platter.Request_Load(FMars_Request_Platter_Load(Piece));
        }
    }

    // The shared opening: the stock lands on the platter, then the feed draws from it.
    protected void Add_Steps_SourceTheFeed()
    {
        Add_Step_WaitUntil("the stock lands on the platter", n"Check_StockLanded", 0, 5.0f);
        Add_Step("source the feed from the platter", n"Step_SetSource");
        Add_Step_WaitUntil("the feed draws from the platter", n"Check_Sourced", 0, 1.0f);
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

    protected void SetSource(FCk_Handle_Platter InSource)
    {
        _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(InSource));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_StockLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == k_Stock);
    }

    UFUNCTION()
    protected void Step_SetSource(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetSource(_Platter);
    }

    UFUNCTION()
    protected void Check_Sourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Source() == _Platter && _Feed.Get_Available() == k_Stock);
    }

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

    UFUNCTION()
    protected void Check_Reaching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Reach);
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
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers (the feed may be gone: they record, and touch only the platter)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase)
    {
        _Phases.Add(InPhase);
        _PhaseTimes.Add(float32(System::GetGameTimeInSeconds()));
    }

    // What the bridge does: the released piece comes off the platter before any kernel sees it.
    UFUNCTION()
    protected void OnReleaseRequested(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease)
    {
        _Releases.Add(InRelease);
        _ReleaseNodeAtRelease.Add(ck::IsValid(_ReleaseNode)
            ? utils_transform::Get_EntityCurrentTransform(_ReleaseNode.As_Transform()) : FTransform::Identity);

        if (ck::IsValid(_Platter) && InRelease.Piece.TryGet_Platter() == _Platter)
        { _Platter.Request_Unload(FMars_Request_Platter_Unload(InRelease.Piece)); }
    }

    // A released piece that was not admitted goes back on the platter (the bridge's rejection and leave paths). A load
    // queued behind a pending unload drains after it.
    UFUNCTION()
    protected void OnTransferSettled(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle)
    {
        _SettledPieces.Add(InPieceId);
        _Settles.Add(InSettle);

        const auto IsReleasedPiece = _Releases.Num() > 0 && _Releases.Last().PieceId.Get_IsSame(InPieceId);
        if (InSettle == EMars_CookingFeed_Settle::Admitted || IsReleasedPiece == false || ck::Is_NOT_Valid(_Platter))
        { return; }

        auto Piece = _Releases.Last().Piece;
        if (ck::Is_NOT_Valid(Piece))
        { return; }

        _Platter.Request_Load(FMars_Request_Platter_Load(Piece, Get_World(Piece)));
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
