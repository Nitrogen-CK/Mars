// Every piece on the searing pan gets its own oil pool. The real searing station (spawned through its entity script, the
// only station in this world, nobody operating it) has two box food pieces admitted by hand, as its feed bridge would, each
// wearing its own display (the station hangs no part off either), and each is teleported (its middle) to its own point on the cooking surface, one either side of the centre. The pan's material then carries both
// pools: Meat Footprint (slot 0, the first piece admitted) and Meat Footprint 1 (slot 1, the second) both have their piece's
// own footprint radius and sit at their own piece's pan-local XY in art cm, as far apart as the two points, and slot 2 has no
// pool. The second piece is then teleported off the pan, beside the rim over the table: its slot's radius drops to 0 (no
// pool hugs a piece that is not on the pan) while the first piece's pool stays where it is. The dressing is read back
// through the station's tagged pan part. The test destroys the station before it finishes: the table's static-world bake
// is an entity of the world, removed only when the table's component tears down.
class UMars_AutoTest_SearingStation_DressingGivesEachPieceItsOwnPool : UMars_AutoTestRig_FoodPiece
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(-60000.0, 16000.0, -60000.0);
    // Where the box pieces wait for their release, beside the station, and their mass.
    private const FVector k_ParkLocal = FVector(0.0, -300.0, 0.0);
    private const float k_PieceMassKg = 0.1;
    // The station's pan scale on the art's cm.
    private const float64 k_PanScale = 2.5;
    // Where the two pieces are teleported, in the pan body's frame (the pan mesh's own, uu): either side of the centre on
    // the flat base (radius 9.5 art cm = 23.75 uu), clear of each other and of the release point over the centre, a little
    // above the surface.
    private const FVector k_FirstLocal = FVector(-13.0, 0.0, 15.0);
    private const FVector k_SecondLocal = FVector(13.0, 0.0, 15.0);
    // Off the pan: beside the rim (radius 14.5 art cm = 36.25 uu) over the table, where the second piece is sent.
    private const FVector k_OffPanLocal = FVector(0.0, -55.0, 15.0);
    // Art cm a settling piece may slide from its teleport point before the pools are read.
    private const float64 k_SettleTolerance = 2.0;

    private FCk_Handle_EntityScript _Station;
    private FCk_Handle_Searing _Searing;
    private FCk_Handle_CookingFeed _Feed;
    private FCk_Handle_UnrealComponent _PanPart;
    private FMars_CookingFeed_PieceId _FirstId;
    private FMars_CookingFeed_PieceId _SecondId;
    // Indexed by the slot each is released for.
    private TArray<FCk_Handle_FoodPiece> _Pieces;

    // The piece's footprint radius in the pan mesh's cm, as the station derives it (mars_cooking_ue.py LOOKDEV_POOL_NOTE:
    // the piece's half extent h in pan cm * sqrt(2) * 0.9, h the mean of its two horizontal half extents).
    private float64 Get_PieceFootprint(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        const auto HalfExtents = _Searing.Get_PieceHalfExtents(InPieceId);
        return (HalfExtents.X + HalfExtents.Y) * 0.5 / k_PanScale * 1.41421 * 0.9;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_SearingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_SearingStation_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));
        for (int32 Index = 0; Index < 2; ++Index)
        {
            const auto Park = k_Origin + k_ParkLocal - FVector(0.0, 20.0 * float64(Index), 0.0);
            _Pieces.Add(Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, Park), Make_Spec(k_PieceMassKg)));
        }

        Add_Step_WaitUntil("the station composed its Searing and its feed, the pan body exists and the boxes are ready", n"Check_StationReady", 0, 5.0f);
        Add_Step("dress both boxes with their own displays", n"Step_DressPieces");
        Add_Step_WaitFrames("the station's state machine settles in Idle (its reset empties the pan)", 3);
        Add_Step("heat the pan and admit the first piece at the release node", n"Step_HeatAndAddFirst");
        Add_Step_WaitUntil("the first piece's body is in the simulation", n"Check_FirstBodyAdded", 0, 2.0f);
        Add_Step("teleport the first piece to its point and admit the second", n"Step_PlaceFirstAndAddSecond");
        Add_Step_WaitUntil("the second piece's body is in the simulation", n"Check_SecondBodyAdded", 0, 2.0f);
        Add_Step("teleport the second piece to its point", n"Step_PlaceSecond");
        Add_Step("find the tagged pan part", n"Step_FindPan");
        Add_Step_WaitUntil("both pieces lie on the pan and the pan's material shows two pools apart", n"Check_TwoPools", 0, 3.0f);
        Add_Step("each pool sits at its own piece", n"Step_AssertTwoPools");
        Add_Step("teleport the second piece off the pan", n"Step_LiftSecond");
        Add_Step_WaitUntil("the second piece's pool is gone", n"Check_SecondPoolGone", 0, 2.0f);
        Add_Step("the first piece's pool stayed", n"Step_AssertFirstPoolStayed");
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
            && _Pieces[0].Get_Status() == EMars_FoodPiece_Status::Ready && _Pieces[1].Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    // Whoever makes a piece dresses it: the test made the boxes, so each wears a food's display (the meat's materials).
    UFUNCTION()
    private void Step_DressPieces(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _Pieces)
        { mars::Food_MeatSlab_Mars.Add_Display(Piece); }
    }

    UFUNCTION()
    private void Step_HeatAndAddFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, "the station starts with an empty pan");
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
        _FirstId = FMars_CookingFeed_PieceId(_Feed.Get_Generation(), 0);
        Release(_FirstId);
    }

    UFUNCTION()
    private void Check_FirstBodyAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsBodyAdded(_FirstId));
    }

    UFUNCTION()
    private void Step_PlaceFirstAndAddSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Teleport(_FirstId, k_FirstLocal);
        _SecondId = FMars_CookingFeed_PieceId(_Feed.Get_Generation(), 1);
        Release(_SecondId);
    }

    UFUNCTION()
    private void Check_SecondBodyAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsBodyAdded(_SecondId));
    }

    UFUNCTION()
    private void Step_PlaceSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Teleport(_SecondId, k_SecondLocal);
    }

    UFUNCTION()
    private void Step_FindPan(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Pans = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsSearingPan");
        Assert_Equals_Int(Pans.Num(), 1, "one tagged pan part");
        if (Pans.Num() != 1)
        { return; }

        _PanPart = Pans[0].As_UnrealComponent();
    }

    UFUNCTION()
    private void Check_TwoPools(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto Material = Get_PanMaterial();
        if (ck::Is_NOT_Valid(Material) || Get_IsOnPan(_FirstId) == false || Get_IsOnPan(_SecondId) == false)
        {
            Res.Set(false);
            return;
        }

        const auto First = Material.GetVectorParameterValue(n"Meat Footprint");
        const auto Second = Material.GetVectorParameterValue(n"Meat Footprint 1");
        Res.Set(Math::Abs(float64(First.B) - Get_PieceFootprint(_FirstId)) < 0.01
            && Math::Abs(float64(Second.B) - Get_PieceFootprint(_SecondId)) < 0.01
            && Get_Distance(First, Second) >= Get_PointsApart() - k_SettleTolerance);
    }

    UFUNCTION()
    private void Step_AssertTwoPools(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Material = Get_PanMaterial();
        const auto First = Material.GetVectorParameterValue(n"Meat Footprint");
        const auto Second = Material.GetVectorParameterValue(n"Meat Footprint 1");
        const auto Third = Material.GetVectorParameterValue(n"Meat Footprint 2");
        ck::Trace(f"[SearingStation] Meat Footprint {First}, Meat Footprint 1 {Second}, Meat Footprint 2 {Third}");

        Assert_Pool(First, _FirstId, "slot 0 (the first piece admitted)");
        Assert_Pool(Second, _SecondId, "slot 1 (the second piece admitted)");
        Assert_True(Third.B == 0.0f, f"slot 2 (no third piece) has no pool (radius {Third.B})");

        for (const auto& Piece : _Pieces)
        { Assert_Undressed(Piece); }
    }

    UFUNCTION()
    private void Step_LiftSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Teleport(_SecondId, k_OffPanLocal);
    }

    UFUNCTION()
    private void Check_SecondPoolGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto Material = Get_PanMaterial();
        Res.Set(ck::IsValid(Material) && Material.GetVectorParameterValue(n"Meat Footprint 1").B == 0.0f);
    }

    UFUNCTION()
    private void Step_AssertFirstPoolStayed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsOnPan(_FirstId), "the first piece still lies on the pan");
        Assert_True(Get_IsOnPan(_SecondId) == false, "the second piece is off the pan");
        Assert_Pool(Get_PanMaterial().GetVectorParameterValue(n"Meat Footprint"), _FirstId, "slot 0 after the second piece left");
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

    // InFootprint has the piece's own footprint radius and sits at the piece's pan-local XY in art cm.
    private void Assert_Pool(FLinearColor InFootprint, const FMars_CookingFeed_PieceId& InPieceId, FString InWhich)
    {
        const auto Local = _Searing.Get_PiecePanLocal(InPieceId);
        const auto Gap = FVector2D(float64(InFootprint.R) - Local.X / k_PanScale, float64(InFootprint.G) - Local.Y / k_PanScale).Size();
        Assert_True(Math::Abs(float64(InFootprint.B) - Get_PieceFootprint(InPieceId)) < 0.01,
            f"{InWhich}: the radius [{InFootprint.B}] is the piece's footprint [{Get_PieceFootprint(InPieceId)}]");
        Assert_True(Gap < 0.3, f"{InWhich}: the footprint [{InFootprint}] is the piece's pan-local XY [{Local}] in art cm (gap {Gap})");
    }

    // A station part would be a scene node hanging off the piece; the piece keeps its own display.
    private void Assert_Undressed(const FCk_Handle_FoodPiece& InPiece)
    {
        FCk_Handle Entity = InPiece;
        Assert_True(Entity.Is_RuntimeMeshDisplay(), f"[{InPiece.ToString()}] still wears its own display");

        auto Parts = 0;
        for (const auto& Dependent : utils_entity_lifetime::Get_LifetimeDependents(Entity))
        {
            if (ck::IsValid(Dependent) && Dependent.Is_SceneNode())
            { Parts += 1; }
        }

        Assert_Equals_Int(Parts, 0, f"the station hung no part off [{InPiece.ToString()}]");
    }

    // The bridge's job done by hand: a release of the box for slot InPieceId.StockIndex, its middle at the feed's release
    // node (over the pan's centre, above the rim); the feed itself is not asked.
    private void Release(const FMars_CookingFeed_PieceId& InPieceId)
    {
        const auto Piece = _Pieces[InPieceId.StockIndex];
        const auto NodeWorld = utils_transform::Get_EntityCurrentTransform(_Feed.Get_ReleaseNode());
        const auto Rotation = NodeWorld.GetRotation();
        const auto ReleaseWorld = FTransform(Rotation, NodeWorld.GetLocation() - Rotation.RotateVector(Get_BoundsCenter(Piece)));

        auto PieceRelease = FMars_CookingFeed_Release(InPieceId, ReleaseWorld, FVector::ZeroVector, 0);
        PieceRelease.Piece = Piece;
        _Searing.Request_AddPiece(FMars_Request_Searing_AddPiece(PieceRelease));
    }

    // The piece's middle to InLocal in the pan body's frame, the pan's rotation kept.
    private void Teleport(const FMars_CookingFeed_PieceId& InPieceId, FVector InLocal)
    {
        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto CentreLocal = _Searing.Get_PieceState(InPieceId).CentreLocal;
        const auto Location = PanBaseWorld.TransformPosition(InLocal) - PanBaseWorld.GetRotation().RotateVector(CentreLocal);
        utils_jolt_body::Request_Teleport(_Searing.Get_PieceBody(InPieceId), FCk_Request_JoltBody_Teleport(Location, PanBaseWorld.Rotator()));
    }

    private bool Get_IsBodyAdded(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        return _Searing.Get_HasPiece(InPieceId) && utils_jolt_body::Get_IsBodyAdded(_Searing.Get_PieceBody(InPieceId));
    }

    private bool Get_IsOnPan(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        return _Searing.Get_HasPiece(InPieceId)
            && _Searing.Get_PieceStatus(InPieceId) != EMars_Searing_PieceStatus::Lost
            && _Searing.Get_PieceContact(InPieceId) == EMars_Searing_Contact::OnPan;
    }

    // Art cm between the two teleport points.
    private float64 Get_PointsApart() const
    {
        return FVector2D(k_SecondLocal.X - k_FirstLocal.X, k_SecondLocal.Y - k_FirstLocal.Y).Size() / k_PanScale;
    }

    // Art cm between two footprints' XY.
    private float64 Get_Distance(FLinearColor InA, FLinearColor InB) const
    {
        return FVector2D(float64(InA.R - InB.R), float64(InA.G - InB.G)).Size();
    }

    // Null until the dressing created the pan's dynamic instance.
    private UMaterialInstanceDynamic Get_PanMaterial() const
    {
        if (ck::Is_NOT_Valid(_PanPart))
        { return nullptr; }

        auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(_PanPart));
        if (ck::Is_NOT_Valid(Mesh))
        { return nullptr; }

        return Cast<UMaterialInstanceDynamic>(Mesh.GetMaterial(0));
    }
}

class AMars_AutoTest_SearingStation_DressingGivesEachPieceItsOwnPool_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_DressingGivesEachPieceItsOwnPool;
}
