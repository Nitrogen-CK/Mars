// The CookingFeed rig, on the FoodPiece rig (pieces under the world's transient entity, tracked for cleanup): a feed on a
// transform-only station root at an isolated origin, its release node 100 up (a test may move it), its hand node, which
// the feed itself moves by the test spec's hand geometry (Make_TestSpec: resting at k_HandLocal, its middle on the
// reserved piece's middle at the grasp and on the release node at the release, the held piece's middle on the node: nothing
// here draws or moves a glove), and its stock: a platter (a plain Transform entity under the test, 200 to the side, standing
// on a kinematic floor box, the large platter item's bounds and capacity with quick settle tuners so a pile re-settles
// within a few frames) loaded with k_Stock box pieces. Add_Steps_SourceTheFeed waits for the pieces to land and sources the feed. The rig is the test receiver and
// stands in for the station's bridge: it records every signal (phases, releases with the release node's pose at that
// moment, settles, refusals, stock edges) and puts nothing back itself (the feed gives back every piece it took and nobody
// admitted). Its steps answer the last release Accepted or Rejected. A test that needs a receiving kernel builds a Searing
// under the release node (Build_Searing), on its own station entity, whose admission inbox it hands releases to.
UCLASS(Abstract)
class UMars_AutoTestRig_CookingFeed : UMars_AutoTestRig_FoodPiece
{
    protected const FVector k_Origin = FVector(-60000.0, 34000.0, -60000.0);
    protected const FVector k_ReleaseLocal = FVector(0.0, 0.0, 100.0);
    protected const FVector k_HandLocal = FVector(0.0, 100.0, 60.0);
    // Make_TestSpec's lift: past the box fixture's 10 cm height, so a lifted piece clears its neighbours.
    protected const float32 k_LiftClearCm = 20.0f;
    protected const FVector k_PlatterLocal = FVector(0.0, 200.0, 0.0);
    protected const int32 k_Stock = 6;
    // A poll budget, not a ceiling: the stock drops onto the platter and the pile settles and re-settles under physics.
    protected const int32 k_SlowPolls = 900;
    // Build_Searing's pan: a kinematic box whose top lies k_PanBelowReleaseCm under the release node, so a piece released
    // there (its middle on the node) drops onto it.
    protected const FVector k_PanHalfExtents = FVector(60.0, 60.0, 1.0);
    protected const float64 k_PanBelowReleaseCm = 10.0;

    protected FCk_Handle _Station;
    protected FCk_Handle_CookingFeed _Feed;
    protected FCk_Handle_SceneNode _ReleaseNode;
    protected FCk_Handle_SceneNode _HandNode;
    protected FMars_CookingFeed_Spec _Spec;
    protected FCk_Handle_Platter _Platter;
    // In load order.
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
    // One entry per OnLoaded of the platter: a piece's every landing on it (the stock's first, and any return).
    protected TArray<FCk_Handle_FoodPiece> _Landed;
    // One entry per OnPieceLetGo: a piece the feed let go where it lies, no platter being left to take it back.
    protected TArray<FCk_Handle_FoodPiece> _LetGo;

    // Build_Searing's kernel, its station entity and its pan's base body.
    protected FCk_Handle_Searing _Searing;
    protected FCk_Handle _SearingStation;
    protected FCk_Handle_JoltBody _PanBaseBody;
    private UMars_AutoTestHelper_CookingFixture _CookingFixture;

    // Quick timed phases, the default motion (the held piece's middle on the hand node, world-aligned), and the hand
    // geometry: rest at k_HandLocal, the hand node on the reserved piece's middle at the grasp and on the release node at the
    // release, the stations' carry arc, and a lift of k_LiftClearCm, so the carried piece leaves the pile above its
    // neighbours instead of shoving them while they re-settle.
    protected FMars_CookingFeed_Spec Make_TestSpec()
    {
        auto Spec = FMars_CookingFeed_Spec(
            FMars_CookingFeed_TimingSpec(0.1f, 0.05f, 0.1f, 0.1f),
            FMars_CookingFeed_MotionSpec());

        auto Hand = FMars_CookingFeed_HandGeometry();
        Hand.RestLocal = FTransform(k_HandLocal);
        Hand.ClearanceCm = k_LiftClearCm;
        Spec.Hand = TOptional<FMars_CookingFeed_HandGeometry>(Hand);
        return Spec;
    }

    // The feed (unsourced), and the platter with k_Stock box pieces asked onto it, each built at its own pose beside it.
    protected void BuildFeed(FCk_Handle InHandle, FMars_CookingFeed_Spec InSpec)
    {
        _Station = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Station, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        _ReleaseNode = utils_scene_node::Create(Root, FTransform(k_ReleaseLocal));
        _HandNode = utils_scene_node::Create(Root, FTransform(k_HandLocal));

        _Spec = InSpec;
        _Spec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode.As_Transform(), _HandNode.As_Transform());
        _Feed = utils_cooking_feed::Add(_Station, _Spec);

        _Feed.BindTo_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnPhaseChanged"));
        _Feed.BindTo_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseRequested"));
        _Feed.BindTo_OnTransferSettled(FMars_Delegate_CookingFeed_OnTransferSettled(this, n"OnTransferSettled"));
        _Feed.BindTo_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnTransferRefused"));
        _Feed.BindTo_OnStockChanged(FMars_Delegate_CookingFeed_OnStockChanged(this, n"OnStockChanged"));
        _Feed.BindTo_OnPieceLetGo(FMars_Delegate_CookingFeed_OnPieceLetGo(this, n"OnPieceLetGo"));

        const UCk_InventoryItem_Definition PlatterItem = mars_items::Platter_Large();
        const UMars_ItemTrait_Platter PlatterTrait = PlatterItem.Get_ItemTraitByClass(UMars_ItemTrait_Platter);
        auto PlatterSpec = PlatterTrait.Platter;
        PlatterSpec.Settle.DropCadenceSeconds = 0.05f;
        PlatterSpec.Settle.SampleSeconds = 0.05f;
        PlatterSpec.Settle.DwellSeconds = 0.1f;

        auto PlatterEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto PlatterRoot = utils_transform::Add(PlatterEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterLocal), ECk_Replication::DoesNotReplicate);
        Get_CookingFixture().Add_PlatterFloorBox(PlatterRoot, PlatterSpec.Bounds);
        _Platter = utils_platter::Add(PlatterEntity, PlatterSpec);
        _Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnPlatterLoaded"));

        for (int32 Index = 0; Index < k_Stock; ++Index)
        {
            const auto PieceWorld = FTransform(FRotator(0.0, 15.0 * float64(Index), 0.0),
                k_Origin + k_PlatterLocal + FVector(50.0, 30.0 * float64(Index), 0.0));
            auto Piece = Build_Piece(Get_BoxMesh(), PieceWorld, Make_Spec(0.1));
            _Stock.Add(Piece);
            _Platter.Request_Load(FMars_Request_Platter_Load(Piece));
        }
    }

    private UMars_AutoTestHelper_CookingFixture Get_CookingFixture()
    {
        if (ck::Is_NOT_Valid(_CookingFixture))
        { _CookingFixture = Cast<UMars_AutoTestHelper_CookingFixture>(NewObject(this, UMars_AutoTestHelper_CookingFixture)); }

        return _CookingFixture;
    }

    // A Searing on its own station entity, its pan an Implement on a node k_PanBelowReleaseCm under the release node and its
    // base body a kinematic box: cold, so nothing sears. The test binds whatever it watches on _SearingStation.
    protected void Build_Searing(FCk_Handle& InOwner)
    {
        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        _SearingStation = StationEntity;
        // Tracked with the pieces so it is torn down in the frame they are, as a station's own teardown ends them: left
        // to the runner's cascade it would tick on after they are gone, and a piece gone from under a live kernel is a
        // defect the kernel ensures on.
        Track_ForCleanup(StationEntity);
        const auto PanTop = k_Origin + k_ReleaseLocal - FVector(0.0, 0.0, k_PanBelowReleaseCm);
        auto Root = utils_transform::Add(StationEntity, FTransform(FRotator::ZeroRotator, PanTop), ECk_Replication::DoesNotReplicate);
        auto PanNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Nodes = FMars_Implement_Nodes(PanNode);
        auto Pan = utils_implement::Add(PanNode.H(), PanSpec);

        auto BodyNode = utils_scene_node::Create(PanNode.As_Transform(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -k_PanHalfExtents.Z)));
        _PanBaseBody = Get_CookingFixture().Add_KinematicBox(BodyNode, k_PanHalfExtents);

        auto Spec = FMars_Searing_Spec();
        Spec.Nodes = FMars_Searing_Nodes(Pan, _PanBaseBody);
        _Searing = utils_searing::Add(StationEntity, Spec);
    }

    // The shared opening: the stock lands on the platter, then the feed draws from it.
    protected void Add_Steps_SourceTheFeed()
    {
        Add_Step_WaitUntil("the stock lands on the platter", n"Check_StockLanded", k_SlowPolls, 0);
        Add_Step("source the feed from the platter", n"Step_SetSource");
        Add_Step_WaitUntil("the feed draws from the platter", n"Check_Sourced", 0, 0);
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

    // Nothing on the platter is queued or settling: a press finds a frozen top to reach for.
    UFUNCTION()
    protected void Check_PileSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    protected void Check_PanAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_IsBodyAdded(_PanBaseBody));
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

    // How many times InPiece has landed on the platter (OnLoaded): once for the stock's first drop, once more per return.
    protected int32 Get_LandedCount(const FCk_Handle_FoodPiece& InPiece) const
    {
        auto Count = 0;
        for (const auto& Piece : _Landed)
        {
            if (Piece == InPiece)
            { Count += 1; }
        }

        return Count;
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

    // The feed took the piece off the platter at its grasp; the release only records.
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

    UFUNCTION()
    protected void OnPlatterLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        _Landed.Add(InPiece);
    }

    UFUNCTION()
    protected void OnPieceLetGo(FCk_Handle_CookingFeed InFeed, FCk_Handle_FoodPiece InPiece)
    {
        _LetGo.Add(InPiece);
    }
}
