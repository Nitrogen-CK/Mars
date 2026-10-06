// A move into a wall fails as Stuck: a 200 uu tall static wall stands across the straight line 200 uu ahead; under the
// Slide wall policy the body presses into it and stops making progress, so the watchdog fails the move (Failed, Stuck,
// OnFailed once with the goal and Stuck, OnArrived never) and clears the steering: one second later the body is still.
class UMars_AutoTest_SurfaceNavigator_StuckBehindWallFails : UMars_AutoTestRig_SurfaceNavigator
{
    default _TimeoutSeconds = 20.0f;
    default _Origin = FVector(140000.0, 84000.0, 600.0);

    private FVector _Goal;

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

    // 20 uu thick, 600 uu wide, 200 uu tall (well above MaxStepHeight 85), across +X at 200 uu.
    private void SpawnWall(FCk_Handle InHandle)
    {
        SpawnStaticBox(InHandle, _Origin + FVector(200.0, 0.0, 100.0), FVector(10.0, 300.0, 100.0));
    }

    UFUNCTION()
    private void Step_MoveTo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        BindNavigatorSignals();
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
        const auto Location = Get_BodyLocation();

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
