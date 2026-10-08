// Every piece on the searing pan gets its own oil pool. The real searing station (spawned through its entity script, the
// only station in this world, nobody operating it) has two pieces admitted by hand, as its feed bridge would, and each is
// teleported to its own point on the cooking surface, one either side of the centre. The pan's material then carries both
// pools: Meat Footprint (slot 0, the first piece admitted) and Meat Footprint 1 (slot 1, the second) both have the cube's
// footprint radius and sit at their own piece's pan-local XY in art cm, as far apart as the two points, and slot 2 has no
// pool. The second piece is then teleported off the pan, beside the rim over the table: its slot's radius drops to 0 (no
// pool hugs a cube that is not on the pan) while the first piece's pool stays where it is. The dressing is read back
// through the station's tagged pan part. The test destroys the station before it finishes: the table's static-world bake
// is an entity of the world, removed only when the table's component tears down.
class UMars_AutoTest_SearingStation_DressingGivesEachPieceItsOwnPool : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(-60000.0, 16000.0, -60000.0);
    // The station's pan and cube scales on the art's cm and the cube's half extent in art cm (cooking_spec.py CUBE_HALF_CM).
    private const float64 k_PanScale = 2.5;
    private const float64 k_CubeScale = 3.0;
    private const float64 k_CubeHalf = 2.0;
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

    // The cube's footprint radius in the pan mesh's cm, as the station derives it (mars_cooking_ue.py LOOKDEV_POOL_NOTE:
    // the cube's half extent in pan cm * sqrt(2) * 0.9).
    private float64 Get_CubeFootprint() const
    {
        return k_CubeHalf * k_CubeScale / k_PanScale * 1.41421 * 0.9;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_SearingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_SearingStation_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        Add_Step_WaitUntil("the station composed its Searing and its feed, and the pan body exists", n"Check_StationReady", 0, 5.0f);
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
            && utils_jolt_body::Get_IsBodyAdded(_Searing.Get_Spec().Nodes.PanBaseBody));
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
        Res.Set(Math::Abs(float64(First.B) - Get_CubeFootprint()) < 0.01
            && Math::Abs(float64(Second.B) - Get_CubeFootprint()) < 0.01
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

    // InFootprint has the cube's footprint radius and sits at the piece's pan-local XY in art cm.
    private void Assert_Pool(FLinearColor InFootprint, const FMars_CookingFeed_PieceId& InPieceId, FString InWhich)
    {
        const auto Local = _Searing.Get_PiecePanLocal(InPieceId);
        const auto Gap = FVector2D(float64(InFootprint.R) - Local.X / k_PanScale, float64(InFootprint.G) - Local.Y / k_PanScale).Size();
        Assert_True(Math::Abs(float64(InFootprint.B) - Get_CubeFootprint()) < 0.01,
            f"{InWhich}: the radius [{InFootprint.B}] is the cube's footprint [{Get_CubeFootprint()}]");
        Assert_True(Gap < 0.3, f"{InWhich}: the footprint [{InFootprint}] is the piece's pan-local XY [{Local}] in art cm (gap {Gap})");
    }

    // The bridge's job done by hand: a release at the feed's release node (over the pan's centre, above the rim); the feed
    // itself is not asked.
    private void Release(const FMars_CookingFeed_PieceId& InPieceId)
    {
        const auto ReleaseWorld = utils_transform::Get_EntityCurrentTransform(_Feed.Get_ReleaseNode());
        _Searing.Request_AddPiece(FMars_Request_Searing_AddPiece(
            FMars_CookingFeed_Release(InPieceId, ReleaseWorld, FVector::ZeroVector, 0)));
    }

    // InLocal in the pan body's frame, the pan's rotation kept.
    private void Teleport(const FMars_CookingFeed_PieceId& InPieceId, FVector InLocal)
    {
        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        utils_jolt_body::Request_Teleport(_Searing.Get_PieceBody(InPieceId),
            FCk_Request_JoltBody_Teleport(PanBaseWorld.TransformPosition(InLocal), PanBaseWorld.Rotator()));
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
