// A client runs the cutting station's whole loop. The server loads one slab onto the large platter, spawns a second, empty
// large platter (the tray) and docks it on the Output dock, has the subject hold the food platter and reports (step 1);
// from then on it only answers. The client places its platter on its Input dock through the dock's act and reserves the
// station through the station's act. Once the server's station reads the subject operating with the platter arrived on
// its Input dock, the server seeds the operator's remote state and applies a remote add-food press. Once the client's
// board holds the joint and its feed is Idle, the client chops through the station's chop helper with aim 0. Once the
// server's board holds the two halves and is quiet it applies a remote sweep press, and once the tray has frozen both
// halves it publishes the tray's rides (step 2). The client leaves the station through the station's act and takes the
// tray from its Output dock through the dock's act; once the subject holds the tray the server reports (step 3). At
// step 3 the client's subject holds the tray on its own hand, the tray holds two, both cut pieces stand riding it at the
// published rides, the board holds none and the feed is Idle with one admitted; its label never said "no tray" from step
// 1 until step 2. On the server the board holds none, the feed is Idle with one admitted and the input platter is docked
// and empty.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_AClientRunsTheWholeLoop
class UCk_AutoTest_Net_CookingFeed_AClientRunsTheWholeLoop : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 29.0f;

    private const float64 k_X = 287000.0;
    private const int32 k_Halves = 2;

    private FCk_Handle _Slab;
    // Server: the tray it spawned; this machine's copy of it, once found.
    private FCk_Handle _TrayEntity;
    private FCk_Handle_Platter _Tray;
    private int32 _QuietFrames = 0;
    // Client: sampled frames between its step 1 and step 2 on which its label said no tray.
    private bool _IsWatchingNoTray = false;
    private int32 _NoTrayFrames = 0;
    private int32 _NoTrayWatched = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FeedStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    // This machine's tray: the large platter world item near the test's X that is not the food platter.
    private bool Try_FindTray()
    {
        if (ck::IsValid(_Tray))
        { return true; }

        if (Try_FindPlatter() == false)
        { return false; }

        const auto Capacity = Get_CapacityOf(mars_items::Platter_Large());
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) == false || Candidate.Is_Transform() == false || Candidate.Is_Platter() == false
                || Candidate.Has_Fragment(FMars_Fragment_Platter_Params) == false || Get_IsNear(Candidate, _FloorTop) == false)
            { continue; }

            if (Candidate.As_Platter().Get_Capacity() == Capacity && Candidate.As_Platter() != _Platter)
            {
                _Tray = Candidate.As_Platter();
                return true;
            }
        }

        return false;
    }

    private FCk_Handle_WorldItem Get_TrayWorldItem()
    {
        FCk_Handle Entity = _Tray;
        return Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
    }

    protected void On_FeedStationSample() override
    {
        if (_IsWatchingNoTray == false)
        { return; }

        ++_NoTrayWatched;
        if (Get_ShownLabel().Contains("no tray"))
        { ++_NoTrayFrames; }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Spawn_FeedStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Root = FTransform(FRotator::ZeroRotator,
            _FloorTop + FVector(k_BesideCm, 0.0, constants_platter::k_FloorAboveBase + 0.5));
        _TrayEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(Root, mars_items::Platter_Large()));
        Track_ForCleanup(_TrayEntity);
        WaitUntil(n"Is_ServerTrayBuilt", n"OnServerTrayBuilt", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTrayBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_TrayEntity) && _TrayEntity.Is_Platter() && _TrayEntity.Has_Fragment(FMars_Feature_WorldItem) && Try_FindTray());
    }

    UFUNCTION()
    private void OnServerTrayBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Tray == _TrayEntity, "the server finds the tray it spawned");
        Dock_Item(_OutputDock, Get_TrayWorldItem().Get_Item());
    }

    protected void On_ServerDocked() override
    {
        Hold_Platter(Get_PlatterWorldItem());
    }

    protected void On_ServerHeld() override
    {
        Mark_Time("step1");
        Report_Step(1, _Slab.As_FoodPiece());
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
        Seed_RemoteThen(n"OnServerSeeded");
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("press");
        Press_RemoteAddFood(1);
        WaitUntil(n"Is_ServerBoardQuiet", n"OnServerBoardQuiet", k_SlowPolls);
    }

    // Two halves on the board and no cut pending for k_QuietFrames frames in a row.
    UFUNCTION()
    private void Is_ServerBoardQuiet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto IsQuiet = _Board.Get_HeldCount() == k_Halves;
        for (const auto& Piece : _Board.Get_Held())
        {
            if (Piece.Get_HasBoardCutPending())
            { IsQuiet = false; }
        }

        _QuietFrames = IsQuiet ? _QuietFrames + 1 : 0;
        auto Result = OutResult;
        Result.Set(_QuietFrames >= constants_feed_station_net_autotest::k_QuietFrames);
    }

    UFUNCTION()
    private void OnServerBoardQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("sweep");
        Press_RemoteSweep();
        WaitUntil(n"Is_ServerTrayFrozen", n"OnServerTrayFrozen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTrayFrozen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tray.Get_HeldCount() == k_Halves);
    }

    UFUNCTION()
    private void OnServerTrayFrozen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_StepWithRidesOf(2, _Tray, FCk_Handle_FoodPiece());
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
        Report_Step(3, FCk_Handle_FoodPiece());
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto DockedFault = Get_DockedFault(_InputDock);
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the server's board holds none");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the server's feed is Idle ({Describe_Feed()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the server's feed admitted one");
        Assert_True(DockedFault.IsEmpty(), f"the input platter is docked on the server ({DockedFault})");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the server's input platter is empty");
        End_FeedStationServer(f"docked=[{DockedFault}] input={_Platter.Get_HeldCount()} tray={_Tray.Get_HeldCount()} {Describe_Feed()} {Describe_Record()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            _IsWatchingNoTray = true;
            WaitUntil(n"Is_PlaceOffered", n"OnPlaceOffered", k_SlowPolls);
            return;
        }

        if (InStep == 2)
        {
            Mark_Time("step2");
            _IsWatchingNoTray = false;
            auto Station = _Station.As_Station();
            utils_station::Request_ActFor(Station, Get_SubjectEntity(), EMars_Station_Verb::Leave);
            WaitUntil(n"Is_TakeOffered", n"OnTakeOffered", k_SlowPolls);
            return;
        }

        Mark_Time("step3");
        const auto Report = Get_PlatterReport();
        const auto HeldFault = Try_FindTray() ? Get_HeldOnHandFault(_Tray) : "no tray found";
        const auto TrayHeld = ck::IsValid(_Tray) ? _Tray.Get_HeldCount() : -1;
        auto RideFault = FString();
        auto Standing = 0;
        for (int32 Index = 0; Index < Report.Count; ++Index)
        {
            const auto Slot = Get_Slot(Report, Index);
            const auto Piece = Find_PieceById(Slot.Id);
            if (Get_Stands(Piece))
            { ++Standing; }

            const auto Fault = ck::IsValid(_Tray) ? Get_RideFaultOn(_Tray, Piece, Slot) : "no tray found";
            if (Fault.IsEmpty() == false && RideFault.IsEmpty())
            { RideFault = f"slot {Index}: {Fault}"; }
        }

        Assert_True(HeldFault.IsEmpty(), f"the client's subject holds the tray on its own hand ({HeldFault})");
        Assert_Equals_Int(TrayHeld, k_Halves, "the client's tray holds two");
        Assert_Equals_Int(Report.Count, k_Halves, "the server published two rides");
        Assert_Equals_Int(Standing, k_Halves, "both cut pieces stand on the client");
        Assert_True(RideFault.IsEmpty(), f"both cut pieces ride the client's tray at the published rides ({RideFault})");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the client's board holds none");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the client's feed is Idle ({Describe_Feed()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        Assert_Equals_Int(_NoTrayFrames, 0, f"the client's label never said no tray from step 1 until step 2 ({_NoTrayFrames} of {_NoTrayWatched} frames)");
        End_FeedStationClient(f"held=[{HeldFault}] tray={TrayHeld} standing={Standing} rides=[{RideFault}] noTray={_NoTrayFrames}/{_NoTrayWatched} {Describe_Feed()} {Describe_Record()}");
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
        WaitUntil(n"Is_ClientJointOnBoard", n"OnClientJointOnBoard", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientJointOnBoard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSubjectOperating() && _Board.Get_HeldCount() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void OnClientJointOnBoard(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("chop");
        utils_cutting::Request_ChopFor(_Cutting, Get_SubjectEntity(), 0.0f);
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
