// A move into a wall fails as Stuck: a 200 uu tall static wall stands across the straight line 200 uu ahead; under the
// Slide wall policy the body presses into it and stops making progress, so the watchdog fails the move (Failed, Stuck,
// OnFailed once with the goal and Stuck, OnArrived never) and clears the steering: one second later the body is still.
//
// The body is a plain SurfaceMotion body on a runtime static Jolt floor (no legs, so it rides its rays).
// Isolated origin (140000, 84000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_SurfaceNavigator_StuckBehindWallFails : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 20.0f;

    private FVector _Origin = FVector(140000.0, 84000.0, 600.0);
    private FVector _Goal;
    private FCk_Handle_SurfaceMotion _Motion;
    private FCk_Handle_SurfaceNavigator _Nav;

    private int32 _ArrivedCount = 0;
    private int32 _FailedCount = 0;
    private FVector _FailedGoal;
    // The latest OnFailed's reason; unset until it fires.
    private TOptional<EMars_SurfaceNavigator_FailReason> _FailedReason;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndBody(InHandle);
        SpawnWall(InHandle);
        _Goal = _Origin + FVector(500.0, 0.0, 65.0);

        Add_Step_WaitUntil("the body's surface motion is Ready", n"Check_MotionReady", 0, 5.0f);
        Add_Step("bind OnArrived/OnFailed; request a move through the wall", n"Step_MoveTo");
        Add_Step_WaitUntil("the navigator fails", n"Check_Failed", 0, 10.0f);
        Add_Step("the move failed as Stuck in front of the wall", n"Step_AssertStuck");
        Add_Step_WaitSeconds("the cleared steering settles", 1.0f);
        Add_Step("the body is still", n"Step_AssertStill");
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

    private void SpawnStaticBox(FCk_Handle InHandle, FVector InCentre, FVector InHalfExtents)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InCentre), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Entity, BoxSpec);
    }

    private void SpawnFloorAndBody(FCk_Handle InHandle)
    {
        SpawnStaticBox(InHandle, _Origin - FVector(0.0, 0.0, 10.0), FVector(1500.0, 1500.0, 10.0));

        auto BodyEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Body = utils_transform::Add(BodyEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0)), ECk_Replication::DoesNotReplicate);
        _Motion = utils_surface_motion::Add(Body, Make_MotionSpec());
        _Nav = utils_surface_navigator::Add(_Motion, FMars_SurfaceNavigator_Spec());
    }

    // 20 uu thick, 600 uu wide, 200 uu tall (well above MaxStepHeight 85), across +X at 200 uu.
    private void SpawnWall(FCk_Handle InHandle)
    {
        SpawnStaticBox(InHandle, _Origin + FVector(200.0, 0.0, 100.0), FVector(10.0, 300.0, 100.0));
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
    }

    UFUNCTION()
    private void OnFailed(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal, EMars_SurfaceNavigator_FailReason InReason)
    {
        ++_FailedCount;
        _FailedGoal = InGoal;
        _FailedReason = TOptional<EMars_SurfaceNavigator_FailReason>(InReason);
    }

    UFUNCTION()
    private void Step_MoveTo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Nav.BindTo_OnArrived(FMars_Delegate_SurfaceNavigator_OnArrived(this, n"OnArrived"));
        _Nav.BindTo_OnFailed(FMars_Delegate_SurfaceNavigator_OnFailed(this, n"OnFailed"));
        _Nav.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(_Goal));
    }

    UFUNCTION()
    private void Check_Failed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Arrived)
        {
            FinishFailure("the navigator arrived through the wall");
            return;
        }

        Res.Set(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Failed);
    }

    UFUNCTION()
    private void Step_AssertStuck(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Location = utils_transform::Get_EntityCurrentLocation(_Motion.As_Transform());

        Assert_True(_Nav.Get_FailReason() == EMars_SurfaceNavigator_FailReason::Stuck, f"the move failed as Stuck (got [{_Nav.Get_FailReason() :n}])");
        Assert_True(_Nav.Get_PathMode() == EMars_SurfaceNavigator_PathMode::StraightLine,
            f"no provider: the move ran straight into the wall (got [{_Nav.Get_PathMode() :n}])");
        Assert_Equals_Int(_FailedCount, 1, "OnFailed fired once");
        if (_FailedReason.IsSet())
        {
            const auto FailedReason = _FailedReason.GetValue();
            Assert_True(FailedReason == EMars_SurfaceNavigator_FailReason::Stuck, f"OnFailed carries Stuck (got [{FailedReason :n}])");
        }

        Assert_True(_FailedGoal.Equals(_Goal), f"OnFailed carries the goal (got [{_FailedGoal.ToString()}])");
        Assert_Equals_Int(_ArrivedCount, 0, "OnArrived never fired");
        Assert_True(Location.X < _Origin.X + 190.0, f"the body stopped in front of the wall (X offset {Location.X - _Origin.X})");
    }

    UFUNCTION()
    private void Step_AssertStill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Speed = utils_surface_motion::Get_Velocity(_Motion).Size();
        Assert_True(Speed < 5.0, f"the steering was cleared: the body is still ({Speed} uu/s)");
        Assert_True(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Failed, f"the navigator stays Failed (got [{_Nav.Get_Status() :n}])");
        Assert_Equals_Int(_FailedCount, 1, "OnFailed did not fire again");
    }
}
