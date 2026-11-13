// A client runs the fry station's whole loop, at half a second's drain. The server freezes a battered slab on the large
// platter, docks an empty large platter (the tray) on the Output dock, has the subject hold the food platter and reports
// (step 1); from then on it only answers. The client places its platter on its Input dock through the dock's act and
// reserves the station through the station's act. Once the server's station reads the subject operating with the platter
// arrived on its Input dock, the server seeds the operator's remote state and applies a remote add-food press; once the
// piece is in the oil it puts it on the basket floor; once it drained it applies a remote Secondary press; once the tray
// has frozen the piece it publishes the tray's rides (step 2). The client's add-food row read "add food - 1 left" before
// step 2. The client leaves the station through the station's act and takes the tray from its Output dock through the
// dock's act; once the subject holds the tray the server reports (step 3). At step 3 the client's subject holds the tray on
// its own hand, the tray holds one, the client's copy of the piece rides it with the drained oil coat, its fryer has no rows
// and its feed is Idle with one admitted.
// Surface: Ck.Fry.Net.AS_Fry_AClientFriesAPieceAndCarriesTheTrayAway
class UCk_AutoTest_Net_Fry_AClientFriesAPieceAndCarriesTheTrayAway : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 29.0f;

    private const float64 k_X = 371000.0;
    private const float32 k_DrainSeconds = 0.5f;
    private const float32 k_CoatTolerance = 0.01f;

    private FCk_Handle _Slab;
    private FMars_CookingFeed_PieceId _Id;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
    }

    protected FMars_Fry_Spec Make_FrySpec() const override
    {
        auto Spec = FMars_Fry_Spec();
        Spec.Receiver.DrainSeconds = k_DrainSeconds;
        return Spec;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_HeatStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        WaitUntil(n"Is_ServerSlabReady", n"OnServerSlabReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_Slab));
    }

    UFUNCTION()
    private void OnServerSlabReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Followed.Add(_Slab.As_FoodPiece());
        TArray<FCk_Handle_FoodPiece> Battered;
        Battered.Add(_Slab.As_FoodPiece());
        Batter_Then(Battered, n"OnServerBattered");
    }

    UFUNCTION()
    private void OnServerBattered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        Dock_TrayThen(n"OnServerTrayDocked");
    }

    UFUNCTION()
    private void OnServerTrayDocked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hold_Platter(Get_PlatterWorldItem());
    }

    protected void On_ServerHeld() override
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitUntil(n"Is_ServerReadyToFeed", n"OnServerReadyToFeed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReadyToFeed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSubjectOperating() && _InputDock.Get_Item() == Get_PlatterItem() && _InputDock.Get_HasArrived()
            && Get_IsSourcedWith(1));
    }

    UFUNCTION()
    private void OnServerReadyToFeed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("operated");
        Seed_HeatRemoteThen(n"OnServerSeeded");
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("addFood");
        Press_Remote(GameplayTags::Mars_Intent_StationAddFood);
        WaitUntil(n"Is_ServerInOil", n"OnServerInOil", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerInOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ids = _Fry.Get_PieceIds();
        auto Result = OutResult;
        Result.Set(Ids.Num() == 1 && Get_IsInOil(Ids[0]));
    }

    UFUNCTION()
    private void OnServerInOil(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("basket");
        _Id = _Fry.Get_PieceIds()[0];
        Put_IntoBasket(_Id);
        WaitUntil(n"Is_ServerDrained", n"OnServerDrained", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_HasPiece(_Id) && _Fry.Get_PieceDrain(_Id) == EMars_Fry_Drain::Drained);
    }

    UFUNCTION()
    private void OnServerDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("takeOut");
        Press_Remote(GameplayTags::Mars_Intent_Interact_Secondary);
        WaitUntil(n"Is_ServerTrayFrozen", n"OnServerTrayFrozen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTrayFrozen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tray.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void OnServerTrayFrozen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStepWithRidesOf(2, _Tray);
        WaitUntil(n"Is_ServerTrayHeld", n"OnServerTrayHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTrayHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_HeldBySubjectFault(Get_TrayWorldItem()).IsEmpty());
    }

    UFUNCTION()
    private void OnServerTrayHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step3");
        Report_HeatStep(3);
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 0, "the server's fryer holds none");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the server's feed is Idle ({Describe_Feed()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the server's feed admitted one");
        End_HeatServer(f"tray={_Tray.Get_HeldCount()} {Describe_Feed()} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            WaitUntil(n"Is_PlaceOffered", n"OnPlaceOffered", k_SlowPolls);
            return;
        }

        if (InStep == 2)
        {
            Mark_Time("step2");
            Assert_True(Get_SawRow("add food - 1 left", 1), f"before step 2 the client's add-food row read add food - 1 left ({Describe_Seen(_RowsSeen)})");
            auto Station = _Station.As_Station();
            utils_station::Request_ActFor(Station, Get_SubjectEntity(), EMars_Station_Verb::Leave);
            WaitUntil(n"Is_TakeOffered", n"OnTakeOffered", k_SlowPolls);
            return;
        }

        Mark_Time("step3");
        const auto Report = Get_PlatterReport();
        const auto HeldFault = Try_FindTray() ? Get_HeldOnHandFault(_Tray) : "no tray found";
        const auto TrayHeld = ck::IsValid(_Tray) ? _Tray.Get_HeldCount() : -1;
        const auto Copy = Get_FollowedCopy(0);
        const auto RideFault = ck::IsValid(_Tray) && Report.Count == 1 ? Get_RideFaultOn(_Tray, Copy, Get_Slot(Report, 0)) : "no tray or no ride";
        const auto Coat = Get_IsLive(Copy) ? Copy.Get_CookState().OilCoat : -1.0f;
        const auto Drained = _Fry.Get_Spec().Receiver.DrainedOilCoat;
        Assert_True(HeldFault.IsEmpty(), f"the client's subject holds the tray on its own hand ({HeldFault})");
        Assert_Equals_Int(TrayHeld, 1, "the client's tray holds one");
        Assert_True(RideFault.IsEmpty(), f"the client's copy rides its tray at the published ride ({RideFault})");
        Assert_True(Math::Abs(Coat - Drained) <= k_CoatTolerance, f"the client's copy carries the drained oil coat (got {Coat}, spec {Drained})");
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 0, f"the client's fryer has no rows ({Describe_FryLedger()})");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the client's feed is Idle ({Describe_Feed()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        End_HeatClient(f"held=[{HeldFault}] tray={TrayHeld} ride=[{RideFault}] coat={Coat} {Describe_Feed()} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    UFUNCTION()
    private void Is_PlaceOffered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_HeldFault().IsEmpty() && _InputDock.Get_ActionFor(Get_SubjectEntity()) == EMars_PlatterDock_Action::Place);
    }

    UFUNCTION()
    private void OnPlaceOffered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("place");
        Act(_InputDock, EMars_PlatterDock_Action::Place);
        WaitUntil(n"Is_ClientPlaced", n"OnClientPlaced", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_InputDock.Get_Item() == Get_PlatterItem() && _InputDock.Get_HasArrived());
    }

    UFUNCTION()
    private void OnClientPlaced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("reserve");
        auto Station = _Station.As_Station();
        utils_station::Request_ActFor(Station, Get_SubjectEntity(), EMars_Station_Verb::Reserve);
        Await_Step(2);
    }

    UFUNCTION()
    private void Is_TakeOffered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Station.As_Station().Get_IsOperated() == false
            && _OutputDock.Get_ActionFor(Get_SubjectEntity()) == EMars_PlatterDock_Action::Take);
    }

    UFUNCTION()
    private void OnTakeOffered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("take");
        Act(_OutputDock, EMars_PlatterDock_Action::Take);
        Await_Step(3);
    }
}
