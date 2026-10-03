// With no nav provider over the test world (the Mars autotest map has no field there), a MoveTo runs straight to the
// goal: the navigator goes Moving with PathMode StraightLine and the goal as its one waypoint, then arrives within
// AcceptanceRadius of the goal, OnArrived firing once. The spec rejects a zero Speed and a zero AcceptanceRadius.
//
// The body is a plain SurfaceMotion body on a runtime static Jolt floor (no legs, so it rides its rays).
// Isolated origin (140000, 80000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_SurfaceNavigator_StraightLineArrives : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FVector _Origin = FVector(140000.0, 80000.0, 600.0);
    private FVector _Goal;
    private FCk_Handle_SurfaceMotion _Motion;
    private FCk_Handle_SurfaceNavigator _Nav;

    private int32 _ArrivedCount = 0;
    private FVector _ArrivedGoal;
    private int32 _FailedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndBody(InHandle);
        _Goal = _Origin + FVector(400.0, 0.0, 65.0);

        Add_Step("the spec rules hold", n"Step_AssertValidation");
        Add_Step_WaitUntil("the body's surface motion is Ready", n"Check_MotionReady", 0, 5.0f);
        Add_Step("bind OnArrived/OnFailed; request a move 400 uu along +X", n"Step_MoveTo");
        Add_Step_WaitUntil("the navigator is Moving", n"Check_Moving", 0, 2.0f);
        Add_Step("the move runs straight to the goal", n"Step_AssertStraightLine");
        Add_Step_WaitUntil("the navigator arrives", n"Check_Arrived", 0, 8.0f);
        Add_Step("the body is at the goal and OnArrived fired once", n"Step_AssertArrived");
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

    private void SpawnFloorAndBody(FCk_Handle InHandle)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(1500.0, 1500.0, 10.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        auto BodyEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Body = utils_transform::Add(BodyEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0)), ECk_Replication::DoesNotReplicate);
        _Motion = utils_surface_motion::Add(Body, Make_MotionSpec());
        _Nav = utils_surface_navigator::Add(_Motion, FMars_SurfaceNavigator_Spec());
    }

    UFUNCTION()
    private void Check_MotionReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Motion) && utils_surface_motion::Get_Status(_Motion) == ECk_ProceduralAnimation_Status::Ready);
    }

    UFUNCTION()
    private void OnArrived(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal)
    {
        ++_ArrivedCount;
        _ArrivedGoal = InGoal;
    }

    UFUNCTION()
    private void OnFailed(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal, EMars_SurfaceNavigator_FailReason InReason)
    {
        ++_FailedCount;
    }

    UFUNCTION()
    private void Step_AssertValidation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(FMars_SurfaceNavigator_Spec().Validate().IsValid(), "the default spec is valid");
        Assert_False(FMars_SurfaceNavigator_Spec(0.0f, 40.0f).Validate().IsValid(), "Speed 0 is rejected");
        Assert_False(FMars_SurfaceNavigator_Spec(120.0f, 0.0f).Validate().IsValid(), "AcceptanceRadius 0 is rejected");
        Assert_Valid(_Nav, "utils_surface_navigator::Add composed the navigator on the body");
        Assert_True(_Nav.Get_Motion() == _Motion, "the navigator steers the body's motion");
        Assert_True(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Idle, f"a new navigator is Idle (got [{_Nav.Get_Status() :n}])");
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
        Res.Set(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Moving);
    }

    UFUNCTION()
    private void Step_AssertStraightLine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Nav.Get_PathMode() == EMars_SurfaceNavigator_PathMode::StraightLine,
            f"no provider covers the test world: straight line (got [{_Nav.Get_PathMode() :n}])");

        const auto Waypoints = _Nav.Get_Waypoints();
        Assert_Equals_Int(Waypoints.Num(), 1, "a straight-line move has one waypoint");
        if (Waypoints.Num() == 1)
        { Assert_True(Waypoints[0].Equals(_Goal), f"the waypoint is the goal (got [{Waypoints[0].ToString()}])"); }

        Assert_True(_Nav.Get_Goal().Equals(_Goal), f"the navigator records the goal (got [{_Nav.Get_Goal().ToString()}])");
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
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
        const auto Location = utils_transform::Get_EntityCurrentLocation(_Motion.As_Transform());
        const auto Acceptance = _Nav.Get_Spec().AcceptanceRadius;

        Assert_Equals_Int(_ArrivedCount, 1, "OnArrived fired once");
        Assert_True(_ArrivedGoal.Equals(_Goal), f"OnArrived carries the goal (got [{_ArrivedGoal.ToString()}])");
        Assert_Equals_Int(_FailedCount, 0, "OnFailed never fired");
        Assert_True((Location - _Goal).Size2D() <= Acceptance + 10.0,
            f"the body is within AcceptanceRadius + 10 of the goal in XY ({(Location - _Goal).Size2D()})");
    }
}
