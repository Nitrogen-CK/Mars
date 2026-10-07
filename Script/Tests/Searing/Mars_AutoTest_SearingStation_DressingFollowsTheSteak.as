// The real searing station (spawned through its entity script, the only station in this world) dresses the pan, the cube
// and the oil from the kernel every frame. After a second of heat with the steak on the pan: the cube's custom primitive
// data carries the sear of its down face (NegZ at spawn), the pan's material shows the cube's footprint at the steak's
// pan-local XY in the mesh's cm with the cube's footprint radius, the oil trail has caught up with it, and the footprint
// node sits under the steak on the cooking surface. A steak teleported across the pan leaves the trail behind at first
// and the trail catches up within a second. The dressing is read back through the station's tagged pan part, steak part
// and footprint node. The test destroys the station before it finishes: the table's static-world bake is an entity of the
// world, removed only when the table's component tears down.
class UMars_AutoTest_SearingStation_DressingFollowsTheSteak : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(-60000.0, 16000.0, -60000.0);
    // The station's pan and cube scales on the art's cm and the cube's half extent in art cm (cooking_spec.py CUBE_HALF_CM).
    private const float64 k_PanScale = 2.5;
    private const float64 k_CubeScale = 3.0;
    private const float64 k_CubeHalf = 2.0;
    // Where the steak is teleported, in the pan body's frame (the pan mesh's own): over the base, above the surface.
    private const FVector k_TeleportLocal = FVector(10.0, 0.0, 20.0);
    // NegZ, the face down at spawn: cooking_spec.py's CPD index for the sear of -Z.
    private const int32 k_NegZSearIndex = 5;
    // Art cm. The swirl keeps the cube gliding under the 0.25 s lag, so the gap never settles below about 0.5 (0.24-0.46 seen).
    private const float64 k_TrailCaughtUp = 0.75;

    private FCk_Handle_EntityScript _Station;
    private FCk_Handle_Searing _Searing;
    private FCk_Handle_UnrealComponent _PanPart;
    private FCk_Handle_UnrealComponent _SteakPart;
    private FCk_Handle_SceneNode _FootprintNode;

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

        Add_Step_WaitUntil("the station composed its Searing and the first steak spawned", n"Check_SteakSpawned", 0, 5.0f);
        Add_Step("find the tagged pan part, steak part and footprint node; heat the pan", n"Step_FindPartsAndHeat");
        Add_Step_WaitUntil("the pan's and the steak's components exist", n"Check_ComponentsExist", 0, 3.0f);
        Add_Step_WaitUntil("the steak lies on the hot pan", n"Check_OnHotPan", 0, 5.0f);
        Add_Step_WaitUntil("the pan's dynamic instance shows the cube's footprint", n"Check_FootprintShown", 0, 2.0f);
        Add_Step_WaitSeconds("a second of searing", 1.0f);
        Add_Step("the cube, the pan material and the footprint node follow the steak", n"Step_AssertDressing");
        Add_Step("teleport the steak across the pan", n"Step_Teleport");
        Add_Step_WaitUntil("the dressing saw the steak move", n"Check_FootprintMoved", 0, 1.0f);
        Add_Step("the trail lags the footprint", n"Step_AssertTrailLags");
        Add_Step_WaitSeconds("the trail catches up", 1.0f);
        Add_Step("the trail is back on the footprint", n"Step_AssertTrailCaughtUp");
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
    }

    UFUNCTION()
    private void Check_SteakSpawned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Searing) && _Searing.Get_HasSteak());
    }

    UFUNCTION()
    private void Step_FindPartsAndHeat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Pans = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsSearingPan");
        const auto Steaks = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsSearingSteak");
        const auto Footprints = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsSearingFootprint");
        Assert_Equals_Int(Pans.Num(), 1, "one tagged pan part");
        Assert_Equals_Int(Steaks.Num(), 1, "one tagged steak part");
        Assert_Equals_Int(Footprints.Num(), 1, "one tagged footprint node");
        if (Pans.Num() != 1 || Steaks.Num() != 1 || Footprints.Num() != 1)
        { return; }

        _PanPart = Pans[0].As_UnrealComponent();
        _SteakPart = Steaks[0].As_UnrealComponent();
        _FootprintNode = Footprints[0].As_SceneNode();

        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
    }

    UFUNCTION()
    private void Check_ComponentsExist(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_PanMesh()) && ck::IsValid(Get_Component(_SteakPart)));
    }

    UFUNCTION()
    private void Check_OnHotPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_IsHot() && _Searing.Get_IsOnPan());
    }

    UFUNCTION()
    private void Check_FootprintShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto Material = Get_PanMaterial();
        Res.Set(ck::IsValid(Material)
            && Math::Abs(float64(Material.GetVectorParameterValue(n"Meat Footprint").B) - Get_CubeFootprint()) < 0.01);
    }

    UFUNCTION()
    private void Step_AssertDressing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Searing.Get_IsOnPan(), f"the steak still lies on the pan (phase {_Searing.Get_Phase() :n})");
        Assert_True(_Searing.Get_DownFace() == EMars_Searing_Face::NegZ, f"NegZ is still down (got {_Searing.Get_DownFace() :n})");

        const auto Sear = utils_unreal_component::Get_CustomPrimitiveDataFloat(_SteakPart, k_NegZSearIndex);
        Assert_True(Sear > 0.05f, f"the cube's NegZ sear reached its custom primitive data (got {Sear})");

        auto Material = Get_PanMaterial();
        Assert_True(ck::IsValid(Material), "the pan part's slot 0 is a dynamic instance");
        if (ck::Is_NOT_Valid(Material))
        { return; }

        const auto Local = _Searing.Get_SteakPanLocal();
        const auto Footprint = Material.GetVectorParameterValue(n"Meat Footprint");
        const auto Trail = Material.GetVectorParameterValue(n"Oil Trail");
        ck::Trace(f"[SearingStation] steak pan-local {Local}, Meat Footprint {Footprint}, Oil Trail {Trail}");

        Assert_True(Math::Abs(float64(Footprint.R) - Local.X / k_PanScale) < 0.3,
            f"Meat Footprint x [{Footprint.R}] is the steak's pan-local x in art cm [{Local.X / k_PanScale}]");
        Assert_True(Math::Abs(float64(Footprint.G) - Local.Y / k_PanScale) < 0.3,
            f"Meat Footprint y [{Footprint.G}] is the steak's pan-local y in art cm [{Local.Y / k_PanScale}]");
        Assert_True(Math::Abs(float64(Footprint.B) - Get_CubeFootprint()) < 0.01,
            f"Meat Footprint radius [{Footprint.B}] is the cube's footprint [{Get_CubeFootprint()}]");
        Assert_True(Get_TrailGap(Material) < k_TrailCaughtUp, f"the oil trail [{Trail}] has caught up with the footprint (gap {Get_TrailGap(Material)})");

        const auto Offset = utils_scene_node::Get_Offset(_FootprintNode).GetLocation();
        Assert_True(Offset.Distance(FVector(Local.X, Local.Y, 0.0)) < 0.5,
            f"the footprint node [{Offset}] sits under the steak on the cooking surface [{FVector(Local.X, Local.Y, 0.0)}]");
    }

    UFUNCTION()
    private void Step_Teleport(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Body = _Searing.Get_SteakBody();
        Assert_True(utils_jolt_body::Get_IsBodyAdded(Body), "the steak's body is in the simulation");

        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        utils_jolt_body::Request_Teleport(Body,
            FCk_Request_JoltBody_Teleport(PanBaseWorld.TransformPosition(k_TeleportLocal), PanBaseWorld.Rotator()));
    }

    // The first frame the dressing shows the steak near the teleport point (the swirl moves the pan under it by a few uu).
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
        ck::Trace(f"[SearingStation] after the teleport: steak pan-local {_Searing.Get_SteakPanLocal()}, Meat Footprint {Footprint}, Oil Trail {Trail}");

        const auto Gap = Get_TrailGap(Material);
        Assert_True(Gap < k_TrailCaughtUp, f"the oil trail caught up with the footprint (gap {Gap})");
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
