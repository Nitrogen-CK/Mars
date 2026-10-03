// A Stop halts a move in progress: once the body has covered 50 uu of a 1200 uu move, Request_Stop returns the navigator
// to Idle with no waypoints, and half a second later the body is still (SurfaceMotion keeps the last steering, so the
// stop must clear it). Neither OnArrived nor OnFailed fires.
//
// The body is a plain SurfaceMotion body on a runtime static Jolt floor (D-T1; no legs, so it rides its rays).
// Isolated origin (140000, 88000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_SurfaceNavigator_StopHaltsMovement : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FVector _Origin = FVector(140000.0, 88000.0, 600.0);
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
        Add_Step("bind OnArrived/OnFailed; request a move 1200 uu along +X", n"Step_MoveTo");
        Add_Step_WaitUntil("the navigator is Moving and the body moved 50 uu", n"Check_Underway", 0, 3.0f);
        Add_Step("request a Stop", n"Step_Stop");
        Add_Step_WaitUntil("the navigator is Idle", n"Check_Idle", 0, 1.0f);
        Add_Step_WaitSeconds("the cleared steering settles", 0.5f);
        Add_Step("the body is still and no move signal fired", n"Step_AssertStopped");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared rig (one scenario per file: copied, not shared)
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
        return utils_transform::Get_EntityCurrentLocation(utils_transform::DoCastChecked(FCk_Handle(_Motion)));
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
    private void Step_MoveTo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Start = Get_BodyLocation();
        _Nav.BindTo_OnArrived(FMars_Delegate_SurfaceNavigator_OnArrived(this, n"OnArrived"));
        _Nav.BindTo_OnFailed(FMars_Delegate_SurfaceNavigator_OnFailed(this, n"OnFailed"));
        _Nav.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(_Origin + FVector(1200.0, 0.0, 65.0)));
    }

    UFUNCTION()
    private void Check_Underway(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Moving && (Get_BodyLocation() - _Start).Size2D() > 50.0);
    }

    UFUNCTION()
    private void Step_Stop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Nav.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
    }

    UFUNCTION()
    private void Check_Idle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Idle);
    }

    UFUNCTION()
    private void Step_AssertStopped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Speed = utils_surface_motion::Get_Velocity(_Motion).Size();
        Assert_True(Speed < 5.0, f"the stop cleared the steering: the body is still ({Speed} uu/s)");
        Assert_True(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Idle, "the navigator stays Idle");
        Assert_Equals_Int(_Nav.Get_Waypoints().Num(), 0, "a stopped navigator has no waypoints");
        Assert_True((Get_BodyLocation() - _Start).Size2D() < 600.0, "the body stopped well short of the goal");
        Assert_Equals_Int(_ArrivedCount, 0, "OnArrived never fired");
        Assert_Equals_Int(_FailedCount, 0, "OnFailed never fired");
    }
}
