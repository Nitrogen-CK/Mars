// The real searing station (spawned through its entity script, the only station in this world) starts with an empty pan
// and no source for its feed (nothing is docked), and shows no raw proxies: the docked platter is the stock's only visual.
// Nobody operates it here, so no release reaches its feed bridge: the test admits one piece itself (a box food piece wearing
// its own display, as whoever makes a piece dresses it; Request_AddPiece with its middle at the feed's release node, as
// the bridge would) and reads the dressing the station builds from the kernel every frame. The station adds no part to the
// admitted piece: it keeps its own display and nothing hangs off it. After a second of heat with the piece on the pan: the
// kernel sears its down face (NegZ as released), the pan's material shows the piece's footprint at its pan-local XY in the
// mesh's cm with the footprint radius and pool radius of the piece's own size, the oil trail has caught up with it, and the
// footprint node sits under the piece on the cooking surface. A piece teleported across the pan leaves the trail behind at first and the trail
// catches up within a second. The dressing is read back through the station's tagged pan part and footprint node. The
// piece's own display carries its look: on arrival its face slots (0..5) and Shape (9) read the unseared 0, and once its
// down face has seared past 0.05, at a frame a write lands (or the sear has stopped), those slots equal the kernel's face
// sears and their mean within 0.03. The test destroys the station before it finishes: the table's static-world bake is an
// entity of the world, removed only when the table's component tears down.
class UMars_AutoTest_SearingStation_DressingFollowsTheSteak : UMars_AutoTestRig_FoodPiece
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(-60000.0, 16000.0, -60000.0);
    // Where the box piece waits for its release, beside the station, and its mass.
    private const FVector k_ParkLocal = FVector(0.0, -300.0, 0.0);
    private const float k_PieceMassKg = 0.1;
    // The station's pan scale on the art's cm.
    private const float64 k_PanScale = 2.5;
    // Where the piece is teleported, in the pan body's frame (the pan mesh's own): over the base, above the surface.
    private const FVector k_TeleportLocal = FVector(10.0, 0.0, 20.0);
    // Art cm. The swirl keeps the cube gliding under the 0.25 s lag, so the gap never settles below about 0.5 (0.24-0.46 seen).
    private const float64 k_TrailCaughtUp = 0.75;
    // The cook state's display slots: the six face sears at 0..5, Shape at 9.
    private const int32 k_ShapeSlot = 9;
    // The write threshold (0.02) plus the frame or two a deferred write trails the kernel.
    private const float32 k_DisplayTolerance = 0.03f;
    private const float32 k_SearedPast = 0.05f;

    private FCk_Handle_EntityScript _Station;
    private FCk_Handle_Searing _Searing;
    private FCk_Handle_CookingFeed _Feed;
    private FCk_Handle_UnrealComponent _PanPart;
    private FCk_Handle_SceneNode _FootprintNode;
    // The one piece the test admits.
    private FMars_CookingFeed_PieceId _PieceId;
    private FCk_Handle_FoodPiece _Piece;
    // The last poll's NegZ display slot and kernel sear (-1 before the first poll).
    private float32 _PolledNegZSlot = -1.0f;
    private float32 _PolledNegZSear = -1.0f;
    // The display's face slots then Shape, and the kernel's face sears, at the frame Check_DisplayCaughtUp passed.
    private TArray<float32> _SnapSlots;
    private TArray<float32> _SnapSears;

    // The piece's half extent h in the pan mesh's cm, as the station derives it: the mean of its two horizontal half
    // extents (mars_cooking_ue.py LOOKDEV_POOL_NOTE sizes the pool from it).
    private float64 Get_PieceHalfInPanCm() const
    {
        const auto HalfExtents = _Searing.Get_PieceHalfExtents(_PieceId);
        return (HalfExtents.X + HalfExtents.Y) * 0.5 / k_PanScale;
    }

    // The footprint radius: h * sqrt(2) * 0.9.
    private float64 Get_PieceFootprint() const
    {
        return Get_PieceHalfInPanCm() * 1.41421 * 0.9;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_SearingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_SearingStation_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));
        _Piece = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, k_Origin + k_ParkLocal), Make_Spec(k_PieceMassKg));

        Add_Step_WaitUntil("the station composed its Searing and its feed, the pan body exists and the box is ready", n"Check_StationReady", 0, 5.0f);
        Add_Step("dress the box with its own display", n"Step_DressPiece");
        Add_Step_WaitUntil("the box's display is set up", n"Check_PieceShown", 0, 3.0f);
        Add_Step_WaitFrames("the station's state machine settles in Idle (its reset empties the pan)", 3);
        Add_Step("the pan is empty and the feed unsourced; heat the pan and admit a piece at the release node", n"Step_AssertEmptyHeatAndAdd");
        Add_Step_WaitUntil("the piece was admitted", n"Check_PieceAdded", 0, 2.0f);
        Add_Step_WaitFrames("the arrival write drains", 1);
        Add_Step("the piece's display reads its unseared arrival look", n"Step_AssertArrivalWrite");
        Add_Step("find the tagged pan part and footprint node; no raw proxy exists", n"Step_FindParts");
        Add_Step_WaitUntil("the pan's component exists", n"Check_ComponentsExist", 0, 3.0f);
        Add_Step("the admitted piece wears only its own display", n"Step_AssertPieceUndressed");
        Add_Step_WaitUntil("the piece lies on the hot pan", n"Check_OnHotPan", 0, 5.0f);
        Add_Step_WaitUntil("the pan's dynamic instance shows the piece's footprint", n"Check_FootprintShown", 0, 2.0f);
        Add_Step_WaitSeconds("a second of searing", 1.0f);
        Add_Step("the pan material and the footprint node follow the piece", n"Step_AssertDressing");
        Add_Step("teleport the piece across the pan", n"Step_Teleport");
        Add_Step_WaitUntil("the dressing saw the piece move", n"Check_FootprintMoved", 0, 1.0f);
        Add_Step("the trail lags the footprint", n"Step_AssertTrailLags");
        Add_Step_WaitSeconds("the trail catches up", 1.0f);
        Add_Step("the trail is back on the footprint", n"Step_AssertTrailCaughtUp");
        Add_Step_WaitUntil("the down face seared past 0.05 and the display caught up", n"Check_DisplayCaughtUp", 0, 3.0f);
        Add_Step("the piece's display carries its face sears and shape", n"Step_AssertDisplayCarriesTheSear");
        Add_Step("destroy the station", n"Step_DestroyStation");
        Add_Step_WaitUntil("the station is gone", n"Check_StationGone", 0, 2.0f);
        Add_Step_WaitFrames("its components tear down", 2);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Station = InEntityScriptHandle;
        _Searing = InEntityScriptHandle.As_Searing();
        _Feed = InEntityScriptHandle.As_CookingFeed();
    }

    UFUNCTION()
    private void Check_StationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Searing) && ck::IsValid(_Feed)
            && utils_jolt_body::Get_IsBodyAdded(_Searing.Get_Spec().Nodes.PanBaseBody)
            && _Piece.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    // Whoever makes a piece dresses it: the test made the box, so the box wears a food's display (the meat's materials).
    UFUNCTION()
    private void Step_DressPiece(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        mars::Food_MeatSlab_Mars.Add_Display(_Piece);
    }

    UFUNCTION()
    private void Check_PieceShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Piece;
        auto Res = OutResult;
        Res.Set(Entity.Is_RuntimeMeshDisplay()
            && utils_runtime_mesh_display::Get_SetupState(Entity.As_RuntimeMeshDisplay()) == ECk_RuntimeMesh_SetupState::Ready);
    }

    // The bridge's job done by hand: one release of the box, its middle at the feed's release node (over the pan's centre,
    // above the rim), with the feed's generation and slot 0; the feed itself is not asked.
    UFUNCTION()
    private void Step_AssertEmptyHeatAndAdd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, "the station starts with an empty pan");
        Assert_False(_Feed.Get_IsSourced(), "the feed has no source (nothing is docked)");
        Assert_Equals_Int(_Feed.Get_Available(), 0, "so nothing is available");

        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));

        const auto NodeWorld = utils_transform::Get_EntityCurrentTransform(_Feed.Get_ReleaseNode());
        const auto Rotation = NodeWorld.GetRotation();
        const auto ReleaseWorld = FTransform(Rotation, NodeWorld.GetLocation() - Rotation.RotateVector(Get_BoundsCenter(_Piece)));
        _PieceId = FMars_CookingFeed_PieceId(_Feed.Get_Generation(), 0);
        auto Release = FMars_CookingFeed_Release(_PieceId, ReleaseWorld, FVector::ZeroVector, 0);
        Release.Piece = _Piece;
        _Searing.Request_AddPiece(FMars_Request_Searing_AddPiece(Release));
    }

    UFUNCTION()
    private void Check_PieceAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_HasPiece(_PieceId));
    }

    // The station wrote the arrival look (the box's spec seeds no sear) before the piece has touched the pan.
    UFUNCTION()
    private void Step_AssertArrivalWrite(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        { Assert_Equals_Float(Get_DisplaySlot(Face), 0.0f, k_DisplayTolerance, f"display slot {Face} reads the unseared face on arrival"); }

        Assert_Equals_Float(Get_DisplaySlot(k_ShapeSlot), 0.0f, k_DisplayTolerance, "display slot 9 reads the raw shape on arrival");
    }

    UFUNCTION()
    private void Step_FindParts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Pans = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsSearingPan");
        const auto Footprints = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsSearingFootprint");
        const auto RawSlots = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsSearingRawSlot");
        Assert_Equals_Int(Pans.Num(), 1, "one tagged pan part");
        Assert_Equals_Int(Footprints.Num(), 1, "one tagged footprint node");
        Assert_Equals_Int(RawSlots.Num(), 0, "no raw slot proxy: the docked platter is the stock's only visual");
        if (Pans.Num() != 1 || Footprints.Num() != 1)
        { return; }

        _PanPart = Pans[0].As_UnrealComponent();
        _FootprintNode = Footprints[0].As_SceneNode();
    }

    UFUNCTION()
    private void Check_ComponentsExist(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_PanMesh()));
    }

    // A station part would be a scene node hanging off the piece; the piece keeps its own display.
    UFUNCTION()
    private void Step_AssertPieceUndressed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Piece;
        Assert_True(Entity.Is_RuntimeMeshDisplay(), "the admitted piece still wears its own display");

        auto Parts = 0;
        for (const auto& Dependent : utils_entity_lifetime::Get_LifetimeDependents(Entity))
        {
            if (ck::IsValid(Dependent) && Dependent.Is_SceneNode())
            { Parts += 1; }
        }

        Assert_Equals_Int(Parts, 0, "the station hung no part off the admitted piece");
    }

    UFUNCTION()
    private void Check_OnHotPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_IsHot() && _Searing.Get_HasPiece(_PieceId)
            && _Searing.Get_PieceContact(_PieceId) == EMars_Searing_Contact::OnPan);
    }

    UFUNCTION()
    private void Check_FootprintShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto Material = Get_PanMaterial();
        Res.Set(ck::IsValid(Material)
            && Math::Abs(float64(Material.GetVectorParameterValue(n"Meat Footprint").B) - Get_PieceFootprint()) < 0.01);
    }

    UFUNCTION()
    private void Step_AssertDressing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Searing.Get_PieceContact(_PieceId) == EMars_Searing_Contact::OnPan, "the piece still lies on the pan");
        Assert_True(_Searing.Get_DownFace(_PieceId) == EMars_Searing_Face::NegZ, f"NegZ is still down (got {_Searing.Get_DownFace(_PieceId) :n})");

        const auto Sear = _Searing.Get_FaceSear(_PieceId, EMars_Searing_Face::NegZ);
        Assert_True(Sear > 0.05f, f"the piece's NegZ face sears (got {Sear})");

        auto Material = Get_PanMaterial();
        Assert_True(ck::IsValid(Material), "the pan part's slot 0 is a dynamic instance");
        if (ck::Is_NOT_Valid(Material))
        { return; }

        const auto Local = _Searing.Get_PiecePanLocal(_PieceId);
        const auto Footprint = Material.GetVectorParameterValue(n"Meat Footprint");
        const auto Trail = Material.GetVectorParameterValue(n"Oil Trail");
        ck::Trace(f"[SearingStation] piece pan-local {Local}, Meat Footprint {Footprint}, Oil Trail {Trail}");

        Assert_True(Math::Abs(float64(Footprint.R) - Local.X / k_PanScale) < 0.3,
            f"Meat Footprint x [{Footprint.R}] is the piece's pan-local x in art cm [{Local.X / k_PanScale}]");
        Assert_True(Math::Abs(float64(Footprint.G) - Local.Y / k_PanScale) < 0.3,
            f"Meat Footprint y [{Footprint.G}] is the piece's pan-local y in art cm [{Local.Y / k_PanScale}]");
        Assert_True(Math::Abs(float64(Footprint.B) - Get_PieceFootprint()) < 0.01,
            f"Meat Footprint radius [{Footprint.B}] is the piece's footprint [{Get_PieceFootprint()}]");
        const auto PoolRadius = Material.GetScalarParameterValue(n"Pool Radius");
        Assert_True(Math::Abs(float64(PoolRadius) - 1.1 * Get_PieceHalfInPanCm()) < 0.01,
            f"Pool Radius [{PoolRadius}] follows the piece's size [{1.1 * Get_PieceHalfInPanCm()}]");
        Assert_True(Get_TrailGap(Material) < k_TrailCaughtUp, f"the oil trail [{Trail}] has caught up with the footprint (gap {Get_TrailGap(Material)})");

        const auto Offset = utils_scene_node::Get_Offset(_FootprintNode).GetLocation();
        Assert_True(Offset.Distance(FVector(Local.X, Local.Y, 0.0)) < 0.5,
            f"the footprint node [{Offset}] sits under the piece on the cooking surface [{FVector(Local.X, Local.Y, 0.0)}]");
    }

    UFUNCTION()
    private void Step_Teleport(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Body = _Searing.Get_PieceBody(_PieceId);
        Assert_True(utils_jolt_body::Get_IsBodyAdded(Body), "the piece's body is in the simulation");

        // The piece's middle goes to the point: its origin need not be its middle.
        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto CentreLocal = _Searing.Get_PieceState(_PieceId).CentreLocal;
        const auto Location = PanBaseWorld.TransformPosition(k_TeleportLocal) - PanBaseWorld.GetRotation().RotateVector(CentreLocal);
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Location, PanBaseWorld.Rotator()));
    }

    // The first frame the dressing shows the piece near the teleport point (the swirl moves the pan under it by a few uu).
    UFUNCTION()
    private void Check_FootprintMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto Material = Get_PanMaterial();
        Res.Set(ck::IsValid(Material)
            && float64(Material.GetVectorParameterValue(n"Meat Footprint").R) > 0.5 * k_TeleportLocal.X / k_PanScale);
    }

    UFUNCTION()
    private void Step_AssertTrailLags(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Gap = Get_TrailGap(Get_PanMaterial());
        Assert_True(Gap > 1.0, f"the oil trail lags the moved footprint by more than 1 cm (gap {Gap})");
    }

    UFUNCTION()
    private void Step_AssertTrailCaughtUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Material = Get_PanMaterial();
        const auto Footprint = Material.GetVectorParameterValue(n"Meat Footprint");
        const auto Trail = Material.GetVectorParameterValue(n"Oil Trail");
        ck::Trace(f"[SearingStation] after the teleport: piece pan-local {_Searing.Get_PiecePanLocal(_PieceId)}, Meat Footprint {Footprint}, Oil Trail {Trail}");

        const auto Gap = Get_TrailGap(Material);
        Assert_True(Gap < k_TrailCaughtUp, f"the oil trail caught up with the footprint (gap {Gap})");
    }

    // Polled every frame. Passes once the down face has seared past k_SearedPast at a frame where a write has just landed
    // (the NegZ slot changed) or the sear has stopped moving: either way the display trails the kernel by at most the write
    // threshold plus a frame. Snapshots both sides for the next step.
    UFUNCTION()
    private void Check_DisplayCaughtUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Sear = _Searing.Get_FaceSear(_PieceId, EMars_Searing_Face::NegZ);
        const auto Slot = Get_DisplaySlot(int32(EMars_Searing_Face::NegZ));
        const auto Wrote = _PolledNegZSlot >= 0.0f && Slot != _PolledNegZSlot;
        const auto Stopped = Sear == _PolledNegZSear;
        _PolledNegZSlot = Slot;
        _PolledNegZSear = Sear;

        auto Res = OutResult;
        if (Sear < k_SearedPast || (Wrote == false && Stopped == false))
        {
            Res.Set(false);
            return;
        }

        _SnapSlots.Empty();
        _SnapSears.Empty();
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        {
            _SnapSlots.Add(Get_DisplaySlot(Face));
            _SnapSears.Add(_Searing.Get_FaceSear(_PieceId, EMars_Searing_Face(Face)));
        }

        _SnapSlots.Add(Get_DisplaySlot(k_ShapeSlot));
        Res.Set(true);
    }

    UFUNCTION()
    private void Step_AssertDisplayCarriesTheSear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SnapSlots.Num(), utils_searing::k_FaceCount + 1, "the snapshot holds six face slots and Shape");
        Assert_Equals_Int(_SnapSears.Num(), utils_searing::k_FaceCount, "the snapshot holds six face sears");
        if (_SnapSlots.Num() != utils_searing::k_FaceCount + 1 || _SnapSears.Num() != utils_searing::k_FaceCount)
        { return; }

        auto SearSum = 0.0f;
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        {
            Assert_Equals_Float(_SnapSlots[Face], _SnapSears[Face], k_DisplayTolerance,
                f"display slot {Face} [{_SnapSlots[Face]}] is the kernel's face sear [{_SnapSears[Face]}]");
            SearSum += _SnapSears[Face];
        }

        const auto Shape = SearSum / float32(utils_searing::k_FaceCount);
        Assert_Equals_Float(_SnapSlots[utils_searing::k_FaceCount], Shape, k_DisplayTolerance,
            f"display slot 9 [{_SnapSlots[utils_searing::k_FaceCount]}] is the shape, the mean sear [{Shape}]");

        const auto NegZ = int32(EMars_Searing_Face::NegZ);
        Assert_True(_SnapSlots[NegZ] >= k_SearedPast - k_DisplayTolerance,
            f"the display carries the down face's sear [{_SnapSlots[NegZ]}], not the arrival's 0");
    }

    // 0 until the piece's display is Ready.
    private float32 Get_DisplaySlot(int32 InIndex) const
    {
        FCk_Handle Entity = _Piece;
        return utils_runtime_mesh_display::Get_CustomPrimitiveDataFloat(Entity.As_RuntimeMeshDisplay(), InIndex);
    }

    UFUNCTION()
    private void Step_DestroyStation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Station);
    }

    UFUNCTION()
    private void Check_StationGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Station));
    }

    // Art cm between the oil trail and the footprint XY on the pan material.
    private float64 Get_TrailGap(UMaterialInstanceDynamic InMaterial) const
    {
        const auto Footprint = InMaterial.GetVectorParameterValue(n"Meat Footprint");
        const auto Trail = InMaterial.GetVectorParameterValue(n"Oil Trail");
        return FVector2D(float64(Footprint.R - Trail.R), float64(Footprint.G - Trail.G)).Size();
    }

    // Null until the part's component exists.
    private UActorComponent Get_Component(const FCk_Handle_UnrealComponent& InPart) const
    {
        if (ck::Is_NOT_Valid(InPart))
        { return nullptr; }

        return utils_unreal_component::Get_Component(InPart);
    }

    private UStaticMeshComponent Get_PanMesh() const
    {
        return Cast<UStaticMeshComponent>(Get_Component(_PanPart));
    }

    // Null until the dressing created the pan's dynamic instance.
    private UMaterialInstanceDynamic Get_PanMaterial() const
    {
        auto Mesh = Get_PanMesh();
        if (ck::Is_NOT_Valid(Mesh))
        { return nullptr; }

        return Cast<UMaterialInstanceDynamic>(Mesh.GetMaterial(0));
    }
}

class AMars_AutoTest_SearingStation_DressingFollowsTheSteak_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_DressingFollowsTheSteak;
    default _TimeoutSeconds = 20.0f;
}
