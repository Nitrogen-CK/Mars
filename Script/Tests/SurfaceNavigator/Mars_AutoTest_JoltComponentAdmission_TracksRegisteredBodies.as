// Component admission counts the exact component bake, including collision toggles and replacement, independent of
// an overlapping first-hit result from another component.
class UMars_AutoTest_JoltComponentAdmission_TracksRegisteredBodies : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 20.0f;

    private FVector _LowerCenter = FVector(140000.0, 84000.0, 3000.0);
    private FVector _LowerMovedCenter = FVector(140500.0, 84000.0, 3000.0);
    private FVector _UpperCenter = FVector(140000.0, 84000.0, 3300.0);
    private int32 _BaselineBodyCount = 0;
    private FCk_Handle_UnrealComponent _LowerHandle;
    private FCk_Handle_UnrealComponent _UpperHandle;
    private FCk_Handle_Transform _LowerTransform;
    private UPrimitiveComponent _LowerComponent;
    private UPrimitiveComponent _UpperComponent;
    private UPrimitiveComponent _UnregisteredComponent;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _BaselineBodyCount = utils_jolt_static_world::Get_NumStaticBodies();

        _UnregisteredComponent = NewObject(this, UStaticMeshComponent);
        Cast<UStaticMeshComponent>(_UnregisteredComponent).SetStaticMesh(engine::load::Cube());
        Assert_Equals_Int(utils_jolt_static_world::Get_NumComponentBodiesInScene(nullptr), 0,
            "a null primitive has no component-bake bodies");
        Assert_Equals_Int(utils_jolt_static_world::Get_NumComponentBodiesInScene(_UnregisteredComponent), 0,
            "an unregistered primitive has no component-bake bodies");

        _LowerHandle = Build_Component(InHandle, _LowerCenter, n"JoltAdmission_Lower");
        _UpperHandle = Build_Component(InHandle, _UpperCenter, n"JoltAdmission_Upper");
        const auto LowerBeforeSetup = utils_unreal_component::Get_Component(_LowerHandle);
        if (ck::Is_NOT_Valid(LowerBeforeSetup))
        {
            Assert_Equals_Int(utils_jolt_static_world::Get_NumComponentBodiesInScene(
                Cast<UPrimitiveComponent>(LowerBeforeSetup)), 0,
                "the pending component has no admitted bodies before setup");
        }
        _LowerTransform = utils_transform::DoCastChecked(utils_unreal_component::Get_OwningEntity(_LowerHandle));

        Add_Step_WaitUntil("both automatic component bakes are admitted", n"Check_InitiallyAdmitted", 900, 0);
        Add_Step("the upper component occludes the lower ray while each registration counts independently", n"Step_AssertOcclusion");
        Add_Step("disable collision on the lower component", n"Step_DisableLower");
        Add_Step_WaitUntil("the lower body leaves the scene", n"Check_LowerDisabled", 900, 0);
        Add_Step("move the lower component through its ECS transform while collision is disabled", n"Step_MoveLowerWhileDisabled");
        Add_Step_WaitUntil("the component reaches its moved transform", n"Check_LowerMovedWhileDisabled", 900, 0);
        Add_Step("re-enable collision on the lower component", n"Step_EnableLower");
        Add_Step_WaitUntil("the lower component is automatically rebaked", n"Check_LowerReenabled", 900, 0);
        Add_Step("replace the lower component bake", n"Step_RebakeLower");
        Add_Step("remove both component registrations", n"Step_RemoveComponents");
        Add_Step_WaitUntil("all component bodies are removed and the static-body baseline is restored", n"Check_Removed", 900, 0);
        Run_Steps(InHandle);
    }

    private FCk_Handle_UnrealComponent Build_Component(FCk_Handle InOwner, FVector InCenter, FName InName)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        auto Root = utils_transform::Add(Entity,
            FTransform(FRotator::ZeroRotator, InCenter), ECk_Replication::DoesNotReplicate);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(engine::load::Cube());
        Archetype.SetCollisionProfileName(n"BlockAll");
        Archetype.SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);

        auto Params = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InName);
        FCk_Handle RootHandle = Root;
        return utils_unreal_component::Add(RootHandle, Params);
    }

    UFUNCTION()
    private void Check_InitiallyAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_LowerComponent))
        { _LowerComponent = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(_LowerHandle)); }
        if (ck::Is_NOT_Valid(_UpperComponent))
        { _UpperComponent = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(_UpperHandle)); }

        if (ck::Is_NOT_Valid(_LowerComponent) || ck::Is_NOT_Valid(_UpperComponent))
        {
            Result.Set(false);
            return;
        }

        Result.Set(ck::IsValid(_LowerComponent) && ck::IsValid(_UpperComponent)
            && utils_jolt_static_world::Get_NumComponentBodiesInScene(_LowerComponent) == 1
            && utils_jolt_static_world::Get_NumComponentBodiesInScene(_UpperComponent) == 1
            && utils_jolt_static_world::Get_NumStaticBodies() == _BaselineBodyCount + 2);
    }

    UFUNCTION()
    private void Step_AssertOcclusion(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hit = utils_jolt_static_world::Get_RayCastStaticWorld(
            FVector(_LowerCenter.X, _LowerCenter.Y, 3500.0), FVector(_LowerCenter.X, _LowerCenter.Y, 2900.0));
        Assert_True(Hit.Get_HasHit(), "the overlapping upper component is hit before the lower component");
        const auto HitSource = utils_jolt_static_actor::DoCastChecked(Hit.Get_Entity());
        Assert_True(utils_jolt_static_actor::Get_SourceActorName(HitSource) == _UpperComponent.GetName(),
            "the ray's first hit belongs to the upper component");
        Assert_Equals_Int(utils_jolt_static_world::Get_NumComponentBodiesInScene(_LowerComponent), 1,
            "the lower component's admission count is independent of the first ray hit");
    }

    UFUNCTION()
    private void Step_DisableLower(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _LowerComponent.SetCollisionEnabled(ECollisionEnabled::NoCollision); }

    UFUNCTION()
    private void Check_LowerDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_jolt_static_world::Get_NumComponentBodiesInScene(_LowerComponent) == 0
            && utils_jolt_static_world::Get_NumComponentBodiesInScene(_UpperComponent) == 1
            && utils_jolt_static_world::Get_NumStaticBodies() == _BaselineBodyCount + 1);
    }

    UFUNCTION()
    private void Step_EnableLower(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _LowerComponent.SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics); }

    UFUNCTION()
    private void Step_MoveLowerWhileDisabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_LowerTransform, FCk_Request_Transform_SetLocation(_LowerMovedCenter));
    }

    UFUNCTION()
    private void Check_LowerMovedWhileDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_LowerTransform.Get_EntityCurrentLocation().Equals(_LowerMovedCenter)
            && _LowerComponent.GetWorldLocation().Equals(_LowerMovedCenter)
            && utils_jolt_static_world::Get_NumComponentBodiesInScene(_LowerComponent) == 0);
    }

    UFUNCTION()
    private void Check_LowerReenabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto NewHit = utils_jolt_static_world::Get_RayCastStaticWorld(
            FVector(_LowerMovedCenter.X, _LowerMovedCenter.Y, 3500.0), FVector(_LowerMovedCenter.X, _LowerMovedCenter.Y, 2900.0));
        const auto OldLowerOnlyHit = utils_jolt_static_world::Get_RayCastStaticWorld(
            FVector(_LowerCenter.X, _LowerCenter.Y, 3100.0), FVector(_LowerCenter.X, _LowerCenter.Y, 2900.0));
        if (NewHit.Get_HasHit() == false)
        {
            Result.Set(false);
            return;
        }

        const auto NewHitSource = utils_jolt_static_actor::DoCastChecked(NewHit.Get_Entity());
        Result.Set(utils_jolt_static_actor::Get_SourceActorName(NewHitSource) == _LowerComponent.GetName()
            && OldLowerOnlyHit.Get_HasHit() == false
            && utils_jolt_static_world::Get_NumComponentBodiesInScene(_LowerComponent) == 1
            && utils_jolt_static_world::Get_NumComponentBodiesInScene(_UpperComponent) == 1
            && utils_jolt_static_world::Get_NumStaticBodies() == _BaselineBodyCount + 2);
    }

    UFUNCTION()
    private void Step_RebakeLower(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto NumRebaked = utils_jolt_static_world::Request_BakeComponent(_LowerComponent);
        Assert_Equals_Int(NumRebaked, 1, "the component rebake extracts one body");
        Assert_Equals_Int(utils_jolt_static_world::Get_NumComponentBodiesInScene(_LowerComponent), 1,
            "the replacement body is in the scene");
        Assert_Equals_Int(utils_jolt_static_world::Get_NumStaticBodies(), _BaselineBodyCount + 2,
            "replacement does not orphan the previous body");
    }

    UFUNCTION()
    private void Step_RemoveComponents(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_jolt_static_world::Request_RemoveComponent(_LowerComponent);
        utils_jolt_static_world::Request_RemoveComponent(_UpperComponent);
    }

    UFUNCTION()
    private void Check_Removed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_jolt_static_world::Get_NumComponentBodiesInScene(_LowerComponent) == 0
            && utils_jolt_static_world::Get_NumComponentBodiesInScene(_UpperComponent) == 0
            && utils_jolt_static_world::Get_NumStaticBodies() == _BaselineBodyCount);
    }
}
