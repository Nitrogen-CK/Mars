// With a GroundNav field over the floor, a MoveTo takes the provider's route around a wall: a 600 uu wide, 200 uu tall
// static wall stands across the straight line 200 uu ahead (a 2000 uu field leaves the gap round either end); the
// navigator goes Moving with PathMode Provider and at least 3 waypoints, the body passes the wall's end (|Y| > 300) and
// arrives within AcceptanceRadius of the goal, OnArrived once, OnFailed never.
//
// A field over runtime static Jolt bodies bakes them, but only once they are in the Jolt world: the field
// (utils_surface_navigator::Make_NavFieldSpec) has AutoBuildOnSetup disabled and an explicit Request_Build follows the
// floor and wall being added, so the bake waited on is the one that sees them.
class UMars_AutoTest_SurfaceNavigator_ProviderPathRoutesAroundWall : UMars_AutoTestRig_SurfaceNavigator
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(140000.0, 92000.0, 600.0);

    private FVector _Goal;
    private FCk_Handle_JoltBody _FloorBody;
    private FCk_Handle_JoltBody _WallBody;
    private FCk_Handle_GroundNavVolume _Volume;

    private float64 _MaxAbsY = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _FloorBody = SpawnFloor(InHandle);
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

    UFUNCTION()
    private void Check_WorldReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_IsBodyAdded(_FloorBody) && utils_jolt_body::Get_IsBodyAdded(_WallBody) &&
            ck::IsValid(_Motion) && utils_surface_motion::Get_Status(_Motion) == ECk_ProceduralAnimation_Status::Ready);
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
        BindNavigatorSignals();
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
