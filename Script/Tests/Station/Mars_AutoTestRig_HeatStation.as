// Which heat station a heat-station test spawned.
enum EMars_AutoTest_HeatStation
{
    Searing,
    Fry
}

// The heat-station rig: the real searing or fry station, spawned at an isolated origin through its entity script with its
// two platter docks, and a bare operator (no input, no display) that takes and leaves it, so the station's own state
// machine runs Idle and Operated: the feed draws from the docked raw platter, its bridge hands each release to the
// station's admission inbox, and the kernel loads every piece a take-out hands back onto the tray the take-out names (a
// piece the tray refuses goes back to the kernel). A press is the request the operator's input task would issue. Platters are World-mode
// platter world items under the test (large ones unless a test asks for another), each lying on a static floor beside the
// station (a platter drops what it is given only while it lies still) until a test docks them. The station, the platters,
// the boxes, docking and readiness are the shared heat-station fixture's (UMars_AutoTestHelper_HeatStation). The handlers
// record the docks' signals, the feed's settles and the kernel's take-outs.
UCLASS(Abstract)
class UMars_AutoTestRig_HeatStation : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    protected EMars_AutoTest_HeatStation _Kind = EMars_AutoTest_HeatStation::Searing;
    protected FVector _Origin;
    protected FCk_Handle_Station _Station;
    protected FCk_Handle_CookingFeed _Feed;
    // Invalid on the fry station.
    protected FCk_Handle_Searing _Searing;
    // Invalid on the searing station.
    protected FCk_Handle_Fry _Fry;
    protected FCk_Handle_PlatterDock _InputDock;
    protected FCk_Handle_PlatterDock _OutputDock;
    protected FCk_Handle_Operator _Operator;

    // In arrival order.
    protected TArray<FCk_Handle_Platter> _Docked;
    protected TArray<EMars_PlatterDock_Refusal> _DockRefusals;
    protected TArray<EMars_CookingFeed_Settle> _Settles;
    protected TArray<FCk_Handle_FoodPiece> _TakenOut;

    private UMars_AutoTestHelper_HeatStation _Fixture;

    // The real searing station at InOrigin with InTiming on its feed.
    protected void Spawn_Searing(FCk_Handle InHandle, FVector InOrigin, FMars_CookingFeed_TimingSpec InTiming)
    {
        _Kind = EMars_AutoTest_HeatStation::Searing;
        _Origin = InOrigin;
        Make_Fixture();
        Spawn_Station(InHandle, _Fixture.Spawn_Searing(InHandle, InOrigin, InTiming));
    }

    // The real fry station at InOrigin with InTiming on its feed.
    protected void Spawn_Fry(FCk_Handle InHandle, FVector InOrigin, FMars_CookingFeed_TimingSpec InTiming)
    {
        _Kind = EMars_AutoTest_HeatStation::Fry;
        _Origin = InOrigin;
        Make_Fixture();
        Spawn_Station(InHandle, _Fixture.Spawn_Fry(InHandle, InOrigin, InTiming));
    }

    // A large platter (wide enough for the whole meat slab) lying on a floor beside the station at InOffset from its origin,
    // with InFoodItem's whole joint loaded onto it (null = empty; the kernel path: no hand); the entity is under
    // construction until Get_IsPlatterReady says otherwise.
    protected FCk_Handle Spawn_Platter(FCk_Handle InHandle, FVector InOffset, UCk_InventoryItem_Definition InFoodItem)
    {
        auto PlatterEntity = _Fixture.Spawn_EmptyPlatter(InHandle, _Origin + InOffset, mars_items::Platter_Large());
        if (ck::IsValid(InFoodItem))
        { Track_ForCleanup(_Fixture.Spawn_FoodOnto(PlatterEntity, InFoodItem, _Origin + InOffset + FVector(0.0, 0.0, 60.0))); }

        return PlatterEntity;
    }

    // An empty InPlatterItem platter lying on a floor beside the station at InOffset from its origin; under construction until
    // Get_IsPlatterReady says otherwise.
    protected FCk_Handle Spawn_EmptyPlatterOf(FCk_Handle InHandle, FVector InOffset, UCk_InventoryItem_Definition InPlatterItem)
    {
        return _Fixture.Spawn_EmptyPlatter(InHandle, _Origin + InOffset, InPlatterItem);
    }

    // The FoodPiece rig's box fixture with InKind and no definition, under the world's transient entity, tracked for cleanup.
    protected FCk_Handle_FoodPiece Build_Box(FTransform InWorld, FGameplayTag InKind)
    {
        const auto Box = _Fixture.Build_Box(InWorld, InKind);
        FCk_Handle BoxEntity = Box;
        Track_ForCleanup(BoxEntity);
        return Box;
    }

    // Constructed (a World-mode platter whose holder holds its item) with InHeld pieces landed on it.
    protected bool Get_IsPlatterReady(FCk_Handle InEntity, int32 InHeld) const
    {
        return _Fixture.Get_IsPlatterReady(InEntity, InHeld);
    }

    // Pieces live under the world's transient entity: one that ends on a test-owned platter would outlive the test's leak
    // check, so every piece a platter brings is tracked for cleanup.
    protected void Track_Held(FCk_Handle InPlatterEntity)
    {
        for (const auto& Piece : InPlatterEntity.As_Platter().Get_Held())
        { Track_ForCleanup(Piece); }
    }

    protected void Dock(FCk_Handle_PlatterDock InDock, FCk_Handle InPlatterEntity)
    {
        _Fixture.Dock(InDock, InPlatterEntity);
    }

    // Docked on InDock and no longer lerping onto it.
    protected bool Get_IsDocked(FCk_Handle_PlatterDock InDock, FCk_Handle InPlatterEntity) const
    {
        return _Fixture.Get_IsDocked(InDock, InPlatterEntity);
    }

    protected void Take()
    {
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    protected void Leave()
    {
        _Station.Request_Release(FMars_Request_Station_Release(_Operator, EMars_Station_ReleaseReason::OperatorRequested));
    }

    // The kernel's admitted pieces, in admission order.
    protected TArray<FMars_CookingFeed_PieceId> Get_PieceIds() const
    {
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        { return _Searing.Get_PieceIds(); }

        return _Fry.Get_PieceIds();
    }

    protected FCk_Handle_FoodPiece Get_PieceHandle(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        { return _Searing.Get_PieceHandle(InPieceId); }

        return _Fry.Get_PieceHandle(InPieceId);
    }

    // InPiece onto the docked finished tray (the kernel lands it, and readopts it if the tray refuses it).
    protected void Request_TakeOut(FCk_Handle_FoodPiece InPiece)
    {
        const auto Piece = TOptional<FCk_Handle_FoodPiece>(InPiece);
        const auto Tray = _OutputDock.Get_Platter();
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        {
            _Searing.Request_TakeOut(FMars_Request_Searing_TakeOut(Piece, TOptional<int32>(), Tray));
            return;
        }

        _Fry.Request_TakeOut(FMars_Request_Fry_TakeOut(Piece, TOptional<int32>(), Tray));
    }

    protected int32 Get_TakenOutCount() const
    {
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        { return _Searing.Get_Summary().TakenOut; }

        return _Fry.Get_Summary().TakenOut;
    }

    protected int32 Get_SettleCount(EMars_CookingFeed_Settle InSettle) const
    {
        auto Count = 0;
        for (const auto& Settle : _Settles)
        {
            if (Settle == InSettle)
            { ++Count; }
        }

        return Count;
    }

    // The node InPiece hangs off; invalid while it is not a scene node.
    protected FCk_Handle_Transform Get_Parent(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    protected bool Get_IsKinematic(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        return Entity.Is_JoltBody() && utils_jolt_body::Get_MotionType(Entity.As_JoltBody()) == ECk_MotionType::Kinematic;
    }

    // Spawn_Searing / Spawn_Fry make the fixture, and every test calls one of them first.
    private void Make_Fixture()
    {
        if (ck::Is_NOT_Valid(_Fixture))
        { _Fixture = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation)); }
    }

    private void Spawn_Station(FCk_Handle InHandle, FCk_Handle_PendingEntityScript InPending)
    {
        auto Pending = InPending;
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Operator = utils_operator::Add(OperatorEntity);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Take();
    }

    UFUNCTION()
    protected void Step_Leave(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Leave();
    }

    UFUNCTION()
    protected void Step_BeginTransfer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

    // The kernel, the feed and both docks are composed and the kernel's static furniture is in the simulation.
    UFUNCTION()
    protected void Check_StationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsStationReady(_Station));
    }

    UFUNCTION()
    protected void Check_Operated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOperated());
    }

    UFUNCTION()
    protected void Check_Idle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsIdle());
    }

    protected bool Get_IsOperated() const
    {
        return _Fixture.Get_IsOperated(_Station, _Kind);
    }

    protected bool Get_IsIdle() const
    {
        return _Fixture.Get_IsIdle(_Station, _Kind);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave the station alive into later tests.
        Track_ForCleanup(InEntityScriptHandle);
        _Station = InEntityScriptHandle.As_Station();
        _Feed = InEntityScriptHandle.As_CookingFeed();
        _Searing = InEntityScriptHandle.As_Searing(ECk_SanityCheck::UnChecked);
        _Fry = InEntityScriptHandle.As_Fry(ECk_SanityCheck::UnChecked);
        _InputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Input);
        _OutputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Output);

        _Feed.BindTo_OnTransferSettled(FMars_Delegate_CookingFeed_OnTransferSettled(this, n"OnTransferSettled"));
        _InputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDocked"));
        _InputDock.BindTo_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnDockRefused"));
        _OutputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDocked"));
        _OutputDock.BindTo_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnDockRefused"));

        if (ck::IsValid(_Searing))
        { _Searing.BindTo_OnPieceTakenOut(FMars_Delegate_Searing_OnPieceTakenOut(this, n"OnSearingPieceTakenOut")); }

        if (ck::IsValid(_Fry))
        { _Fry.BindTo_OnPieceTakenOut(FMars_Delegate_Fry_OnPieceTakenOut(this, n"OnFryPieceTakenOut")); }
    }

    UFUNCTION()
    private void OnTransferSettled(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle)
    {
        _Settles.Add(InSettle);
    }

    UFUNCTION()
    private void OnDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        _Docked.Add(InPlatter);
    }

    UFUNCTION()
    private void OnDockRefused(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        _DockRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnSearingPieceTakenOut(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        _TakenOut.Add(InPiece);
    }

    UFUNCTION()
    private void OnFryPieceTakenOut(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        _TakenOut.Add(InPiece);
    }
}
