// A Stop halts a move in progress: once the body has covered 50 uu of a 1200 uu move, Request_Stop returns the navigator
// to Idle with no waypoints, and half a second later the body is still (SurfaceMotion keeps the last steering, so the
// stop must clear it). Neither OnArrived nor OnFailed fires.
class UMars_AutoTest_SurfaceNavigator_StopHaltsMovement : UMars_AutoTestRig_SurfaceNavigator
{
    default _TimeoutSeconds = 15.0f;
    default _Origin = FVector(140000.0, 88000.0, 600.0);

    private FVector _Start;

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

    UFUNCTION()
    private void Step_MoveTo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Start = Get_BodyLocation();
        BindNavigatorSignals();
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
        Assert_True(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Idle, f"the navigator stays Idle (got [{_Nav.Get_Status() :n}])");
        Assert_Equals_Int(_Nav.Get_Waypoints().Num(), 0, "a stopped navigator has no waypoints");
        const auto Travelled = (Get_BodyLocation() - _Start).Size2D();
        Assert_True(Travelled < 600.0, f"the body stopped well short of the goal (travelled {Travelled} of 1200 uu)");
        Assert_Equals_Int(_ArrivedCount, 0, "OnArrived never fired");
        Assert_Equals_Int(_FailedCount, 0, "OnFailed never fired");
    }
}
