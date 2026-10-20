namespace constants_station_autotest
{
    // Where UMars_TESTONLY_GripStation_EntityScript puts its two grip nodes, in the station frame.
    const FVector k_ToolLocal = FVector(10.0, 20.0, 90.0);
    const FVector k_SurfaceLocal = FVector(10.0, -20.0, 90.0);
}

// A bare placeable station for the station tests: the base's composition (the Station, its grip table and its View node)
// and nothing of its own.
class UMars_TESTONLY_Station_EntityScript : UMars_Station_EntityScript
{
}

// A test station with two nodes on its root, published for the spec's grips: Station.Node.Tool at k_ToolLocal and
// Station.Node.Surface at k_SurfaceLocal.
class UMars_TESTONLY_GripStation_EntityScript : UMars_TESTONLY_Station_EntityScript
{
    protected FCk_Handle_Transform _ToolNode;
    protected FCk_Handle_Transform _SurfaceNode;

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _ToolNode = utils_scene_node::Create(InRoot, FTransform(constants_station_autotest::k_ToolLocal)).As_Transform();
        _SurfaceNode = utils_scene_node::Create(InRoot, FTransform(constants_station_autotest::k_SurfaceLocal)).As_Transform();
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _ToolNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _SurfaceNode));
    }
}

// The grip station with only its surface node published: a grip on the tool names a tag nothing registers.
class UMars_TESTONLY_SurfaceOnlyStation_EntityScript : UMars_TESTONLY_GripStation_EntityScript
{
    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _SurfaceNode));
    }
}

// What a test station is spawned with; injection matches by property name.
struct FMars_TESTONLY_StationSpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Station_Spec Station;

    FMars_TESTONLY_StationSpawnParams() {}

    FMars_TESTONLY_StationSpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
    }
}

// The station rig: stations on transform-only roots (no probe, no grip nodes) and operator child entities, and test
// stations spawned through the placeable station's entity script. The handlers record a station's reserves and releases.
UCLASS(Abstract)
class UMars_AutoTestRig_Station : UCk_AutoTest_Base
{
    protected TArray<FCk_Handle> _Reserved;
    protected TArray<FCk_Handle> _Released;
    protected TArray<EMars_Station_ReleaseReason> _ReleaseReasons;

    // Each station on its own child entity: composing two on one entity would alias them.
    protected FCk_Handle_Station AddStation(FCk_Handle InHandle, FMars_Station_Spec InSpec)
    {
        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        return utils_station::Add(Root, InSpec);
    }

    // InClass (a UMars_TESTONLY_*Station_EntityScript) spawned with InParams; the test binds its construction and hands the
    // constructed entity to Track_ForCleanup (a spawned entity script is outside the test's own lifetime subtree).
    protected FCk_Handle_PendingEntityScript Spawn_TestStation(FCk_Handle InHandle, TSubclassOf<UCk_EntityScript_UE> InClass,
        const FMars_TESTONLY_StationSpawnParams& InParams)
    {
        return utils_entity_script::Request_SpawnEntity(InHandle, InClass, InParams);
    }

    protected FCk_Handle_Operator AddOperator(FCk_Handle InHandle)
    {
        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        return utils_operator::Add(OperatorEntity);
    }

    UFUNCTION()
    protected void OnReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        _Reserved.Add(InOperator);
    }

    UFUNCTION()
    protected void OnReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        _Released.Add(InOperator);
        _ReleaseReasons.Add(InReason);
    }

    UFUNCTION()
    protected void Check_Reserved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Reserved.Num() > 0);
    }

    UFUNCTION()
    protected void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() > 0);
    }
}
