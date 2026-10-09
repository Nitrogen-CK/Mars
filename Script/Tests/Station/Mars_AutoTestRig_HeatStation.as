// Which heat station a heat-station test spawned.
enum EMars_AutoTest_HeatStation
{
    Searing,
    Fry
}

// The heat-station rig: the real searing or fry station, spawned at an isolated origin through its entity script with its
// two platter docks, and a bare operator (no input, no display) that takes and leaves it, so the station's own state
// machine runs Idle and Operated: the feed draws from the docked raw platter, its bridge hands each release to the kernel,
// and the take-out bridge loads every piece the kernel hands back onto the docked finished tray. A press is the request the
// operator's input task would issue. Platters are World-mode platter world items under the test, lying beside the station
// (falling freely: no floor at these Z bands) until a test docks them. The handlers record the docks' signals, the feed's
// settles and the kernel's take-outs.
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

    // The real searing station at InOrigin with InTiming on its feed.
    protected void Spawn_Searing(FCk_Handle InHandle, FVector InOrigin, FMars_CookingFeed_TimingSpec InTiming)
    {
        _Kind = EMars_AutoTest_HeatStation::Searing;
        _Origin = InOrigin;

        auto SpawnParams = UMars_SearingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        SpawnParams.Feed.Timing = InTiming;
        Spawn_Station(InHandle, utils_entity_script::Request_SpawnEntity(InHandle, UMars_SearingStation_EntityScript, SpawnParams));
    }

    // The real fry station at InOrigin with InTiming on its feed.
    protected void Spawn_Fry(FCk_Handle InHandle, FVector InOrigin, FMars_CookingFeed_TimingSpec InTiming)
    {
        _Kind = EMars_AutoTest_HeatStation::Fry;
        _Origin = InOrigin;

        auto SpawnParams = UMars_FryStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        SpawnParams.Feed.Timing = InTiming;
        Spawn_Station(InHandle, utils_entity_script::Request_SpawnEntity(InHandle, UMars_FryStation_EntityScript, SpawnParams));
    }

    // A platter beside the station at InOffset from its origin, with InFood's whole joint on it (null = empty); the entity is
    // under construction until Get_IsPlatterReady says otherwise.
    protected FCk_Handle Spawn_Platter(FCk_Handle InHandle, FVector InOffset, UMars_Food_Def InFood)
    {
        auto Owner = InHandle;
        const auto World = FTransform(FRotator::ZeroRotator, _Origin + InOffset);
        if (ck::IsValid(InFood))
        { return utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(World, InFood)); }

        return utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(World));
    }

    // The FoodPiece rig's box fixture (a CPU-readable 1000 cm3 cube) with InKind and no definition: Transform, RuntimeMesh
    // and FoodPiece on a new entity under the world's transient entity, tracked for cleanup.
    protected FCk_Handle_FoodPiece Build_Box(FTransform InWorld, FGameplayTag InKind)
    {
        auto Spec = FMars_FoodPiece_Spec();
        Spec.Data.MassKg = 0.1;
        Spec.Data.Kind.AddTag(InKind);
        Spec.Tuners = FMars_FoodPiece_Tuners(0.0001, 0.05);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(ck::TransientEntity());
        Track_ForCleanup(Entity);
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        utils_runtime_mesh::Add(Entity, FCk_RuntimeMesh_Spec(
            TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/CkTests/CkRuntimeMesh/Cooked/SM_Import_CPU.SM_Import_CPU"))));
        return utils_foodpiece::Add(Entity, Spec);
    }

    // Constructed (a World-mode platter whose holder holds its item) with InHeld pieces landed on it.
    protected bool Get_IsPlatterReady(FCk_Handle InEntity, int32 InHeld) const
    {
        return ck::IsValid(InEntity) && InEntity.Is_WorldItem() && InEntity.Is_Platter()
            && ck::IsValid(InEntity.As_WorldItem().Get_HeldItem()) && InEntity.As_Platter().Get_HeldCount() == InHeld;
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
        auto Target = InDock;
        Target.Request_Dock(FMars_Request_PlatterDock_Dock(InPlatterEntity.As_WorldItem().Get_HeldItem()));
    }

    // Docked on InDock and no longer lerping onto it: a station torn down under a platter still arriving leaves the arrival
    // writing an offset under a dead parent.
    protected bool Get_IsDocked(FCk_Handle_PlatterDock InDock, FCk_Handle InPlatterEntity) const
    {
        if (ck::Is_NOT_Valid(InPlatterEntity) || InPlatterEntity.Is_Platter() == false || InDock.Get_Platter() != InPlatterEntity.As_Platter())
        { return false; }

        return InPlatterEntity.As_WorldItem().Get_Mount() == EMars_WorldItem_Mount::Carried
            && InPlatterEntity.Has_Fragment(FMars_Fragment_WorldItem_Arrival) == false;
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

    protected void Request_TakeOut(FCk_Handle_FoodPiece InPiece)
    {
        const auto Piece = TOptional<FCk_Handle_FoodPiece>(InPiece);
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        {
            _Searing.Request_TakeOut(FMars_Request_Searing_TakeOut(Piece, TOptional<int32>()));
            return;
        }

        _Fry.Request_TakeOut(FMars_Request_Fry_TakeOut(Piece, TOptional<int32>()));
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

    private void Spawn_Station(FCk_Handle InHandle, FCk_Handle_PendingEntityScript InPending)
    {
        auto Pending = InPending;
        // As the map's entity spawner does: the station is its own context, so its state machine's ck::Ctx is the station.
        auto Station = Pending.Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
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
        auto IsReady = ck::IsValid(_Feed) && ck::IsValid(_InputDock) && ck::IsValid(_OutputDock);
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        { IsReady = IsReady && ck::IsValid(_Searing) && utils_jolt_body::Get_IsBodyAdded(_Searing.Get_Spec().Nodes.PanBaseBody); }
        else
        { IsReady = IsReady && ck::IsValid(_Fry); }

        auto Res = OutResult;
        Res.Set(IsReady);
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
        const auto StateClass = utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm());
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        { return StateClass == UMars_SmState_Searing_Operated; }

        return StateClass == UMars_SmState_Fry_Operated;
    }

    protected bool Get_IsIdle() const
    {
        const auto StateClass = utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm());
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        { return StateClass == UMars_SmState_Searing_Idle; }

        return StateClass == UMars_SmState_Fry_Idle;
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
