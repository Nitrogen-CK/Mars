// A client runs the batter station's whole loop. The server loads one whole food onto the large platter, docks an empty
// large platter (the tray) on the Output dock, has the subject hold the food platter and reports (step 1); from then on it
// only answers. The client places its platter on its Input dock through the dock's act and reserves the station through
// the station's act. Once the server's station reads the subject operating with the platter arrived on its Input dock, the
// server seeds the operator's remote state and applies a remote add-food press; once the bowl holds one and the feed is
// Idle it holds Primary remotely, lets it go once the piece is coated, and once the piece rests applies a remote Secondary
// press; once the tray has frozen the piece it publishes the tray's rides (step 2). The client leaves the station through
// the station's act and takes the tray from its Output dock through the dock's act; once the subject holds the tray the
// server reports (step 3). At step 3 the client's subject holds the tray on its own hand, the tray holds one, the client's
// copy of the piece rides it and reads battered, its bowl has no rows and its feed is Idle with one admitted.
// Surface: Ck.Batter.Net.AS_Batter_AClientBattersAPlatterAndCarriesTheTrayAway
class UCk_AutoTest_Net_Batter_AClientBattersAPlatterAndCarriesTheTrayAway : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 29.0f;

    private const float64 k_X = 311000.0;

    private FCk_Handle _Food;
    private FMars_CookingFeed_PieceId _Id;

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
        _Food = Spawn_BesideFood(mars_items::Food_Mushroom(), -1.0);
        Load_WhenReady(_Food, 1);
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
        Mark_Time("press");
        Press_Remote(GameplayTags::Mars_Intent_StationAddFood);
        WaitUntil(n"Is_ServerOneInAndIdle", n"OnServerOneInAndIdle", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOneInAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_PieceCount() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void OnServerOneInAndIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("dip");
        _Id = _Batter.Get_PieceIds()[0];
        _Followed.Add(_Batter.Get_PieceHandle(_Id));
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitUntil(n"Is_ServerCoated", n"OnServerCoated", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCoated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_HasPiece(_Id) && _Batter.Get_PieceCoat(_Id) >= 1.0f);
    }

    UFUNCTION()
    private void OnServerCoated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("lift");
        LetGo_Remote(GameplayTags::Mars_Intent_Interact_Primary);
        WaitUntil(n"Is_ServerRests", n"OnServerRests", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRests(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_CoatedCount() == 1 && utils_cooking_feed::Get_TakeableCount(_Station) == 1);
    }

    UFUNCTION()
    private void OnServerRests(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, "the server's bowl holds none");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the server's feed is Idle ({Describe_Feed()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the server's feed admitted one");
        End_HeatServer(f"tray={_Tray.Get_HeldCount()} {Describe_Feed()} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
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
        const auto IsBattered = Get_IsLive(Copy) && utils_batter::Get_IsBattered(Copy.Get_CookState());
        Assert_True(HeldFault.IsEmpty(), f"the client's subject holds the tray on its own hand ({HeldFault})");
        Assert_Equals_Int(TrayHeld, 1, "the client's tray holds one");
        Assert_True(RideFault.IsEmpty(), f"the client's copy rides its tray at the published ride ({RideFault})");
        Assert_True(IsBattered, "the client's copy reads battered");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, "the client's bowl has no rows");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the client's feed is Idle ({Describe_Feed()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        End_HeatClient(f"held=[{HeldFault}] tray={TrayHeld} ride=[{RideFault}] battered={IsBattered} shell={Get_WearsShell(Copy)} {Describe_Feed()} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
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
