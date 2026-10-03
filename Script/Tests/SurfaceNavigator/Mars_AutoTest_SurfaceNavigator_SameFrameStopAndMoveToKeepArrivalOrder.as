// A Stop and a MoveTo queued in the same frame apply in arrival order. MoveTo then Stop: the navigator stays Idle with no
// waypoints and the body does not move for a second, with no signal. Stop then MoveTo: the move runs.
//
// The body is a plain SurfaceMotion body on a runtime static Jolt floor (no legs, so it rides its rays).
// Isolated origin (140000, 96000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_SurfaceNavigator_SameFrameStopAndMoveToKeepArrivalOrder : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FVector _Origin = FVector(140000.0, 96000.0, 600.0);
    private FVector _Start;
    private FCk_Handle_SurfaceMotion _Motion;
    private FCk_Handle_SurfaceNavigator _Nav;

    private int32 _ArrivedCount = 0;
    private int32 _FailedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndBody(InHandle);

        Add_Step_WaitUntil("the body's surface motion is Ready", n"Check_MotionReady", 0, 5.0f);
        Add_Step("bind OnArrived/OnFailed; request a move 1200 uu along +X, then a Stop, in one frame", n"Step_MoveToThenStop");
        Add_Step_WaitSeconds("a surviving move would show in a second", 1.0f);
        Add_Step("the navigator stayed Idle and the body did not move", n"Step_AssertStayedStopped");
        Add_Step("request a Stop, then a move 1200 uu along +X, in one frame", n"Step_StopThenMoveTo");
        Add_Step_WaitUntil("the navigator is Moving and the body moved 50 uu", n"Check_Underway", 0, 3.0f);
        Add_Step("the move toward the goal is running and no move failed", n"Step_AssertMoving");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Rig
    //----------------------------------------------------------------------------------------------------------------------

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

    private FVector Get_BodyLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(_Motion.As_Transform());
    }

    private FVector Get_Goal() const
    {
        return _Origin + FVector(1200.0, 0.0, 65.0);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

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

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_MoveToThenStop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Start = Get_BodyLocation();
        _Nav.BindTo_OnArrived(FMars_Delegate_SurfaceNavigator_OnArrived(this, n"OnArrived"));
        _Nav.BindTo_OnFailed(FMars_Delegate_SurfaceNavigator_OnFailed(this, n"OnFailed"));
        _Nav.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(Get_Goal()));
        _Nav.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
    }

    UFUNCTION()
    private void Step_AssertStayedStopped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Moved = (Get_BodyLocation() - _Start).Size2D();
        const auto Speed = utils_surface_motion::Get_Velocity(_Motion).Size();
        Assert_True(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Idle, f"the later Stop won: the navigator is Idle, not {_Nav.Get_Status() :n}");
        Assert_Equals_Int(_Nav.Get_Waypoints().Num(), 0, "a stopped navigator has no waypoints");
        Assert_True(Moved < 10.0, f"the body did not move ({Moved} uu)");
        Assert_True(Speed < 5.0, f"the body is still ({Speed} uu/s)");
        Assert_Equals_Int(_ArrivedCount, 0, "OnArrived never fired");
        Assert_Equals_Int(_FailedCount, 0, "OnFailed never fired");
    }

    UFUNCTION()
    private void Step_StopThenMoveTo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Start = Get_BodyLocation();
        _Nav.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
        _Nav.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(Get_Goal()));
    }

    UFUNCTION()
    private void Check_Underway(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Moving && (Get_BodyLocation() - _Start).Size2D() > 50.0);
    }

    UFUNCTION()
    private void Step_AssertMoving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Nav.Get_Goal().Equals(Get_Goal()), "the navigator follows the MoveTo queued after the Stop");
        Assert_True(Get_BodyLocation().X > _Start.X, "the body moves toward +X");
        Assert_Equals_Int(_FailedCount, 0, "OnFailed never fired");
    }
}
