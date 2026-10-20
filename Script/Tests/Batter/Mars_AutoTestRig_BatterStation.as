// The batter station's spawn params as the test hands them over: matched to the station's ExposeOnSpawn properties by name
// (the generated FMars_BatterStation_EntityScript_SpawnParams carries the same fields).
struct FMars_AutoTest_BatterStation_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Batter_Spec Batter;
}

// The batter-station rig: the real batter station, spawned at an isolated origin through its entity script as its own
// context (as the map's entity spawner does) with its two platter docks, and a bare operator (no input, no display) that
// takes and leaves it, so the station's own state machine runs Idle and Operated: the feed draws from the docked raw
// platter, the feed hands each release to the station's admission inbox, and the kernel lands every piece a take-out
// hands back on the tray the take-out names. A press is the request the operator's input task would issue. Platters are
// World-mode platter world items lying on static floors beside the station (the heat-station fixture's) until a test docks
// them.
UCLASS(Abstract)
class UMars_AutoTestRig_BatterStation : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 45.0f;

    protected const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    protected const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // A short coat so a test fills it within its time.
    protected const float32 k_CoatSeconds = 0.5f;
    // A poll budget, not a ceiling: the station composes, platters construct, drop, dock and settle, a transfer carries.
    protected const int32 k_SlowPolls = 900;

    protected FVector _Origin;
    protected FCk_Handle_Station _Station;
    protected FCk_Handle_Batter _Batter;
    protected FCk_Handle_CookingFeed _Feed;
    protected FCk_Handle_PlatterDock _InputDock;
    protected FCk_Handle_PlatterDock _OutputDock;
    protected FCk_Handle_Operator _Operator;
    protected UMars_AutoTestHelper_HeatStation _Fixture;

    protected FCk_Handle _Raw;
    protected FCk_Handle _Tray;
    // The piece the raw platter brought (Step_Dock reads it).
    protected FCk_Handle_FoodPiece _Food;

    // The real batter station at InOrigin (a short coat), a bare operator, a large raw platter with InFoodItem's whole
    // joint loaded onto it and an empty tray, each on a floor beside the station.
    protected void Spawn_All(FCk_Handle InHandle, FVector InOrigin, UCk_InventoryItem_Definition InFoodItem)
    {
        _Origin = InOrigin;
        _Fixture = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation));

        auto SpawnParams = FMars_AutoTest_BatterStation_SpawnParams();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        SpawnParams.Batter.Coat.CoatSeconds = k_CoatSeconds;
        auto Owner = InHandle;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_BatterStation_EntityScript, SpawnParams);
        auto Station = Pending.Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Operator = utils_operator::Add(OperatorEntity);

        _Raw = _Fixture.Spawn_EmptyPlatter(InHandle, InOrigin + k_RawOffset, mars_items::Platter_Large());
        Track_ForCleanup(_Fixture.Spawn_FoodOnto(_Raw, InFoodItem, InOrigin + k_RawOffset + FVector(0.0, 0.0, 60.0)));
        _Tray = _Fixture.Spawn_EmptyPlatter(InHandle, InOrigin + k_TrayOffset, mars_items::Platter_Large());
    }

    // The station is composed, the platters are constructed with the food on the raw one, and both are docked: the steps
    // every station test starts with.
    protected void Add_Steps_DockedAndTaken()
    {
        Add_Step_WaitUntil("the station composed its Batter, feed and docks", n"Check_StationReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the platters are constructed and the food landed", n"Check_PlattersReady", k_SlowPolls, 0);
        Add_Step("dock the raw platter and the empty tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", k_SlowPolls, 0);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", k_SlowPolls, 0);
    }

    protected bool Get_IsOperated() const
    {
        return utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Batter_Operated;
    }

    protected bool Get_IsIdle() const
    {
        return utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Batter_Idle;
    }

    // The bowl's one piece's Id; a default Id while it holds none.
    protected FMars_CookingFeed_PieceId Get_FirstId() const
    {
        const auto Ids = _Batter.Get_PieceIds();
        if (Ids.Num() == 0)
        { return FMars_CookingFeed_PieceId(); }

        return Ids[0];
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_StationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Batter) && ck::IsValid(_Feed) && ck::IsValid(_InputDock) && ck::IsValid(_OutputDock));
    }

    UFUNCTION()
    protected void Check_PlattersReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsPlatterReady(_Raw, 1) && _Fixture.Get_IsPlatterReady(_Tray, 0));
    }

    UFUNCTION()
    protected void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _Raw.As_Platter().Get_Held())
        { Track_ForCleanup(Piece); }

        _Food = _Raw.As_Platter().Get_Held()[0];
        _Fixture.Dock(_InputDock, _Raw);
        _Fixture.Dock(_OutputDock, _Tray);
    }

    UFUNCTION()
    protected void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsDocked(_InputDock, _Raw) && _Fixture.Get_IsDocked(_OutputDock, _Tray));
    }

    UFUNCTION()
    protected void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    UFUNCTION()
    protected void Step_Leave(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Station.Request_Release(FMars_Request_Station_Release(_Operator, EMars_Station_ReleaseReason::OperatorRequested));
    }

    UFUNCTION()
    protected void Check_OperatedAndSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOperated() && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == 1);
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

    UFUNCTION()
    protected void Step_BeginTransfer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    UFUNCTION()
    protected void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_PieceCount() == 1 && _Raw.As_Platter().Get_Occupancy() == 0);
    }

    UFUNCTION()
    protected void Step_Dip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Batter.Request_Dip(FMars_Request_Batter_Dip());
    }

    UFUNCTION()
    protected void Step_Lift(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Batter.Request_Lift(FMars_Request_Batter_Lift());
    }

    UFUNCTION()
    protected void Check_Coated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_PieceCount() == 1 && _Batter.Get_PieceCoat(Get_FirstId()) >= 1.0f);
    }

    // Lifted back to rest with its coat complete: the station's take-out readout lists it.
    UFUNCTION()
    protected void Check_Takeable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Station = _Station;
        auto Res = OutResult;
        Res.Set(utils_cooking_feed::Get_Takeable(Station).Num() == 1);
    }

    UFUNCTION()
    protected void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Station = _Station;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(4, _Tray.As_Platter()));
    }

    // The docked tray holds one piece (a docked platter's world item no longer holds its item: count the pile).
    UFUNCTION()
    protected void Check_OnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tray.As_Platter().Get_HeldCount() == 1);
    }

    // The food wears its battered shell in its display's place, the shell's dip slot written.
    UFUNCTION()
    protected void Check_WearsShell(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Food;
        const auto Shell = utils_food::TryGet_BatteredShell(_Food);
        auto Res = OutResult;
        Res.Set(Entity.Is_RuntimeMeshDisplay() && Entity.As_RuntimeMeshDisplay().Get_Visibility() == ECk_EnableDisable::Disable
            && ck::IsValid(Shell) && ck::IsValid(utils_unreal_component::Get_Component(Shell))
            && utils_unreal_component::Get_CustomPrimitiveDataFloat(Shell, 13) > 0.5f);
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
        _Batter = InEntityScriptHandle.As_Batter(ECk_SanityCheck::UnChecked);
        _InputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Input);
        _OutputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Output);
    }
}
