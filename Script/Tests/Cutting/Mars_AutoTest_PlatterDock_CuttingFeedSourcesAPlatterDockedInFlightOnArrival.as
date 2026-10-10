// A meat platter whose joint has landed is taken in hand by a carrier node 150 cm from the input dock that then slides
// toward it at 60 cm/s for the whole test (the player walking up with it), and is docked while the node still moves. The
// cutting station's feed draws from a docked platter only once it has landed on its dock: in every frame the dock holds
// the platter but it has not arrived, the feed is unsourced (and there is at least one such frame); once it has arrived the
// feed draws from it. Add food then lays the joint on the board at the pile: the board holds the joint, the joint hangs off
// no scene node and its world location is within 2 cm of utils_cutting::Get_PileWorld. Nobody operates the station: the
// feed's source and bridge tasks run in Idle too. Isolated origin (20800, -9000, -30000).
class UMars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(20800.0, -9000.0, -30000.0);
    private const float64 k_StartDistance = 150.0;
    private const float64 k_Speed = 60.0;
    private const float64 k_PileToleranceCm = 2.0;

    private FCk_Handle _Carrier;
    private FCk_Handle_SceneNode _CarrierNode;
    private FVector _Start;
    private FVector _Direction;
    private float64 _MoveStart = 0.0;
    private FCk_Handle_FoodPiece _Joint;
    // Frames the dock held the platter before it arrived, and how many of them the feed was sourced in.
    private int32 _FramesInFlight = 0;
    private int32 _SourcedInFlight = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard, feed and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step("a meat platter spawns on a floor 150 cm from the input dock", n"Step_SpawnPlatter");
        Add_Step_WaitUntil("the platter is constructed and its joint landed", n"Check_PlatterWithJoint", 0, 10.0f);
        Add_Step("a carrier node takes the platter in hand and starts toward the dock", n"Step_HoldOnCarrier");
        Add_Step_WaitUntil("the platter is held on the moving carrier", n"Check_Held", 0, 5.0f);
        Add_Step("dock the platter while the carrier still moves", n"Step_DockInFlight");
        Add_Step_WaitUntil("the platter arrived on the dock and the feed draws from it", n"Check_SourcedOnArrival", 0, 5.0f);
        Add_Step("the feed was unsourced while the platter travelled onto the dock", n"Step_AssertNotSourcedInFlight");
        Add_Step_WaitUntil("the joint is frozen on the docked platter", n"Check_FeedSourced", 0, 5.0f);
        Add_Step("add food", n"Step_AddFood");
        Add_Step_WaitUntil("the feed laid the joint on the board and the glove is back", n"Check_JointOnBoardAndFeedIdle", 0, 5.0f);
        Add_Step_WaitFrames("the pile pose has landed", 2);
        Add_Step("the joint lies on the board at the pile, riding nothing", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnPlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto DockWorld = utils_transform::Get_EntityCurrentTransform(_InputDock.Get_Node());
        _Start = DockWorld.GetLocation() + FVector(0.0, -k_StartDistance, 0.0);
        _Direction = (DockWorld.GetLocation() - _Start).GetSafeNormal();

        _InputPlatterEntity = Spawn_LoadedPlatterAt(InHandle, _Start - _Origin, mars_items::Food_MeatSlab());
    }

    UFUNCTION()
    private void Check_PlatterWithJoint(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = Get_IsPlatterConstructed(_InputPlatterEntity) && _InputPlatterEntity.As_Platter().Get_HeldCount() == 1;
        if (IsReady && ck::Is_NOT_Valid(_Joint))
        {
            _InputPlatter = _InputPlatterEntity.As_Platter();
            _InputPlatterItem = _InputPlatterEntity.As_WorldItem().Get_HeldItem();
            _Joint = _InputPlatter.Get_Held()[0];
            Track_ForCleanup(_Joint);
        }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    // The node's offset this frame: k_Speed toward the dock since the start, never stopping. It also samples the feed in
    // every frame the dock holds the platter that has not landed yet.
    UFUNCTION()
    private void OnCarrierTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_CarrierNode))
        { return; }

        const auto Elapsed = float64(System::GetGameTimeInSeconds()) - _MoveStart;
        utils_scene_node::Request_UpdateOffset_Location(_CarrierNode, _Direction * k_Speed * Elapsed);

        if (ck::Is_NOT_Valid(_InputPlatter) || _InputDock.Get_Platter() != _InputPlatter || _InputDock.Get_HasArrived())
        { return; }

        ++_FramesInFlight;
        if (_Feed.Get_IsSourced())
        { ++_SourcedInFlight; }
    }

    // A carrier node where the platter lies; a Carry onto its hand point, then a Hold: the platter is in hand, as a player
    // carries it to the dock. The node starts moving now and never stops.
    UFUNCTION()
    private void Step_HoldOnCarrier(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = InHandle;
        _Carrier = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, _Start), ECk_Replication::DoesNotReplicate);
        auto Node = utils_scene_node::Create(_Carrier.As_Transform(), FTransform::Identity);
        _CarrierNode = Node;

        FCk_Handle NodeEntity = Node;
        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, Node.As_Transform()));
        utils_attach_points::Add(NodeEntity, AttachPointsSpec);

        auto WorldItem = _InputPlatterEntity.As_WorldItem();
        WorldItem.Request_Carry(FMars_Request_WorldItem_Carry(NodeEntity));
        WorldItem.Request_Hold(FMars_Request_WorldItem_Hold(NodeEntity));

        _MoveStart = float64(System::GetGameTimeInSeconds());
        utils_timer::Create_Tick(Owner, FCk_Delegate_Timer(this, n"OnCarrierTick"));
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_InputPlatterEntity.As_WorldItem().Get_Mount() == EMars_WorldItem_Mount::Held);
    }

    UFUNCTION()
    private void Step_DockInFlight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Travelled = (float64(System::GetGameTimeInSeconds()) - _MoveStart) * k_Speed;
        Log(f"[Mars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival] docking after {Travelled} cm of travel; joint on the platter: {_InputPlatter.Get_HeldCount()}");
        Assert_True(Travelled < k_StartDistance, f"the carrier is still on its way to the dock ({Travelled} of {k_StartDistance} cm)");
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 1, "the joint rides the carried platter");
        Assert_False(_Feed.Get_IsSourced(), "the feed draws from nothing before the dock");

        Dock_Input();
    }

    UFUNCTION()
    private void Check_SourcedOnArrival(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_InputDock.Get_Platter() == _InputPlatter && _InputDock.Get_HasArrived() && _Feed.Get_Source() == _InputPlatter);
    }

    UFUNCTION()
    private void Step_AssertNotSourcedInFlight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[Mars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival] {_FramesInFlight} frame(s) docked before the arrival, sourced in {_SourcedInFlight}");
        Assert_True(_FramesInFlight > 0, "the platter travelled onto the dock for at least one frame");
        Assert_Equals_Int(_SourcedInFlight, 0, "the feed drew from no platter that had not landed");
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Joint), "the platter's joint was found");
        if (ck::Is_NOT_Valid(_Joint))
        { return; }

        Assert_True(_InputDock.Get_Platter() == _InputPlatter, "the platter is docked");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Joint, f"the board holds the joint (board holds {_Board.Get_HeldCount()})");
        Assert_False(ck::IsValid(Get_Parent(_Joint)), "the joint hangs off no scene node");

        const auto Pile = utils_cutting::Get_PileWorld(Get_StationWorld(), _Joint).GetLocation();
        const auto JointWorld = Get_World(_Joint).GetLocation();
        const auto Gap = JointWorld.Distance(Pile);
        Log(f"[Mars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival] joint at {JointWorld}, pile at {Pile}, gap {Gap} cm");
        Assert_True(Gap <= k_PileToleranceCm, f"the joint lies at the pile (gap {Gap} cm: {JointWorld} vs {Pile})");
    }
}
