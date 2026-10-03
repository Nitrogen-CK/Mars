// With a GroundNav field over the floor, a MoveTo takes the provider's route around a wall: a 600 uu wide, 200 uu tall
// static wall stands across the straight line 200 uu ahead (a 2000 uu field leaves the gap round either end); the
// navigator goes Moving with PathMode Provider and at least 3 waypoints, the body passes the wall's end (|Y| > 300) and
// arrives within AcceptanceRadius of the goal, OnArrived once, OnFailed never.
//
// A field over runtime static Jolt bodies bakes them, but only once they are in the Jolt world: the field
// (utils_surface_navigator::Make_NavFieldSpec) has AutoBuildOnSetup disabled and an explicit Request_Build follows the
// floor and wall being added, so the bake waited on is the one that sees them.
// The body is a plain SurfaceMotion body (no legs, so it rides its rays).
// Isolated origin (140000, 92000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_SurfaceNavigator_ProviderPathRoutesAroundWall : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    private FVector _Origin = FVector(140000.0, 92000.0, 600.0);
    private FVector _Goal;
    private FCk_Handle_JoltBody _FloorBody;
    private FCk_Handle_JoltBody _WallBody;
    private FCk_Handle_GroundNavVolume _Volume;
    private FCk_Handle_SurfaceMotion _Motion;
    private FCk_Handle_SurfaceNavigator _Nav;

    private int32 _ArrivedCount = 0;
    private int32 _FailedCount = 0;
    private float64 _MaxAbsY = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _FloorBody = SpawnStaticBox(InHandle, _Origin - FVector(0.0, 0.0, 10.0), FVector(1500.0, 1500.0, 10.0));
        _WallBody = SpawnStaticBox(InHandle, _Origin + FVector(200.0, 0.0, 100.0), FVector(10.0, 300.0, 100.0));
        SpawnVolume(InHandle);
        SpawnBody(InHandle);
        _Goal = _Origin + FVector(500.0, 0.0, 65.0);

        Add_Step_WaitUntil("the floor and wall are in the Jolt world and the body's surface motion is Ready", n"Check_WorldReady", 0, 5.0f);
        Add_Step("bake the field", n"Step_Build");
        Add_Step_WaitUntil("the field is built", n"Check_Built", 0, 5.0f);
        Add_Step("bind OnArrived/OnFailed; request a move to the far side of the wall", n"Step_MoveTo");
        Add_Step_WaitUntil("the navigator is Moving", n"Check_Moving", 0, 2.0f);
        Add_Step("the move follows the provider's route", n"Step_AssertProviderRoute");
        Add_Step_WaitUntil("the navigator arrives", n"Check_Arrived", 0, 15.0f);
        Add_Step("the body went round the wall and is at the goal", n"Step_AssertArrived");
        Run_Steps(InHandle);
    }

    private FCk_SurfaceMotion_Spec Make_MotionSpec()
    {
        auto Contact = FCk_SurfaceMotion_Contact();
        Contact.Set_Clearance(65.0f);
        Contact.Set_ProbeReach(180.0f);
        Contact.Set_HeightSource(ECk_SurfaceMotion_HeightSource::Rays);
        Contact.Set_WallPolicy(ECk_SurfaceMotion_WallPolicy::Slide);
        Contact.Set_MaxStepHeight(85.0f);

        auto Movement = FCk_SurfaceMotion_Movement();
        Movement.Set_MaxSpeed(180.0f);
        Movement.Set_SurfaceTurnRate(180.0f);

        auto Spec = FCk_SurfaceMotion_Spec();
        Spec.Set_Contact(Contact);
        Spec.Set_Movement(Movement);
        return Spec;
    }

    private FCk_Handle_JoltBody SpawnStaticBox(FCk_Handle InHandle, FVector InCentre, FVector InHalfExtents)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InCentre), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        return utils_jolt_body::Add(Entity, BoxSpec);
    }

    // 2000 x 2000 uu over the 3000 uu floor, from 100 below its top to 400 above.
    private void SpawnVolume(FCk_Handle InHandle)
    {
        auto VolumeEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        VolumeEntity.Request_OverrideToSelf();
        const auto Half = FVector(1000.0, 1000.0, 0.0);
        auto Spec = utils_surface_navigator::Make_NavFieldSpec(
            FBox(_Origin - Half - FVector(0.0, 0.0, 100.0), _Origin + Half + FVector(0.0, 0.0, 400.0)));
        Spec.Set_AutoBuildOnSetup(ECk_EnableDisable::Disable);
        _Volume = utils_ground_nav_volume::Add(VolumeEntity, Spec);
    }

    private void SpawnBody(FCk_Handle InHandle)
    {
        auto BodyEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Body = utils_transform::Add(BodyEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0)), ECk_Replication::DoesNotReplicate);
        _Motion = utils_surface_motion::Add(Body, Make_MotionSpec());
        _Nav = utils_surface_navigator::Add(_Motion, FMars_SurfaceNavigator_Spec());
    }

    private FVector Get_BodyLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(_Motion.As_Transform());
    }

    UFUNCTION()
    private void Check_WorldReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_IsBodyAdded(_FloorBody) && utils_jolt_body::Get_IsBodyAdded(_WallBody) &&
            ck::IsValid(_Motion) && utils_surface_motion::Get_Status(_Motion) == ECk_ProceduralAnimation_Status::Ready);
    }

    UFUNCTION()
    private void OnArrived(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal)
    {
        ++_ArrivedCount;
    }

    UFUNCTION()
    private void OnFailed(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal, EMars_SurfaceNavigator_FailReason InReason)
    {
        ++_FailedCount;
    }

    UFUNCTION()
    private void Step_Build(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Volume, "utils_ground_nav_volume::Add composed the field");
        utils_ground_nav_volume::Request_Build(_Volume, FCk_Request_GroundNavVolume_Build());
    }

    UFUNCTION()
    private void Check_Built(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_ground_nav_volume::Get_IsBuilt(_Volume));
    }

    UFUNCTION()
    private void Step_MoveTo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Nav.BindTo_OnArrived(FMars_Delegate_SurfaceNavigator_OnArrived(this, n"OnArrived"));
        _Nav.BindTo_OnFailed(FMars_Delegate_SurfaceNavigator_OnFailed(this, n"OnFailed"));
        _Nav.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(_Goal));
    }

    UFUNCTION()
    private void Check_Moving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Failed)
        {
            FinishFailure(f"the navigator failed: {_Nav.Get_FailReason() :n}");
            return;
        }

        Res.Set(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Moving);
    }

    UFUNCTION()
    private void Step_AssertProviderRoute(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Nav.Get_PathMode() == EMars_SurfaceNavigator_PathMode::Provider,
            f"the field answered: the move follows the provider's route (got [{_Nav.Get_PathMode() :n}])");
        Assert_True(_Nav.Get_Waypoints().Num() >= 3, f"the route bends round the wall ({_Nav.Get_Waypoints().Num()} waypoints)");
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _MaxAbsY = Math::Max(_MaxAbsY, Math::Abs(Get_BodyLocation().Y - _Origin.Y));

        auto Res = OutResult;
        if (_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Failed)
        {
            FinishFailure(f"the navigator failed: {_Nav.Get_FailReason() :n}");
            return;
        }

        Res.Set(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Arrived);
    }

    UFUNCTION()
    private void Step_AssertArrived(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Location = Get_BodyLocation();
        const auto Acceptance = _Nav.Get_Spec().AcceptanceRadius;

        Assert_Equals_Int(_ArrivedCount, 1, "OnArrived fired once");
        Assert_Equals_Int(_FailedCount, 0, "OnFailed never fired");
        Assert_True(_MaxAbsY > 300.0, f"the body went round the wall's end (max |Y| {_MaxAbsY})");
        Assert_True((Location - _Goal).Size2D() <= Acceptance + 10.0,
            f"the body is within AcceptanceRadius + 10 of the goal in XY ({(Location - _Goal).Size2D()})");
    }
}
