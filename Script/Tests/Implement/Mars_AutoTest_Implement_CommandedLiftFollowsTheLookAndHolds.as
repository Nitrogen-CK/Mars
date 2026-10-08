// A Commanded lift (LiftPerLookDegree 1, MinLift -30, MaxLift 20) on a RollOnly tilt: the look's Y moves only the lift
// target (10 degrees down -> -10, exactly: the drain is additive), and the spring carries the node there within 0.8 s
// and holds it instead of returning to rest; 60 degrees up clamps the target at MaxLift and the lift follows; an Idle
// implement drops the look and keeps its target. The overshoot past -10 is traced for tuning, not asserted.
class UMars_AutoTest_Implement_CommandedLiftFollowsTheLookAndHolds : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 6.0f;

    private const float32 k_DownTarget = -10.0f;
    private const float32 k_LiftTolerance = 0.5f;
    private const float32 k_HoldSeconds = 0.5f;

    // The lowest lift since the downward look (the overshoot) and the highest during the hold (a return toward rest).
    private float32 _LowestLift = 0.0f;
    private float32 _HighestHeldLift = 0.0f;
    private float32 _HoldStart = 0.0f;
    private float32 _TargetBeforeIdleLook = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Implement_Spec();
        Spec.Tilt.Axes = EMars_Implement_TiltAxes::RollOnly;
        Spec.Lift.Mode = EMars_Implement_LiftMode::Commanded;
        Spec.Lift.LiftPerLookDegree = 1.0f;
        Spec.Lift.MinLift = -30.0f;
        Spec.Lift.MaxLift = 20.0f;
        BuildImplement(InHandle, Spec);

        Add_Step("drive the implement and look down", n"Step_DriveAndLookDown");
        Add_Step_WaitUntil("the look moved the lift target", n"Check_TargetLowered", 0, 0.3f);
        Add_Step("the lift target took the whole look and the tilt none of it", n"Step_AssertDownTarget");
        Add_Step_WaitUntil("the lift reached its target within 0.8 s", n"Check_LiftAtDownTarget", 0, 0.8f);
        Add_Step("start the hold", n"Step_StartHold");
        Add_Step_WaitUntil("the lift is held for 0.5 s", n"Check_HoldElapsed", 0, 1.0f);
        Add_Step("the lift held at its target; look up past the ceiling", n"Step_AssertHeldThenLookUp");
        Add_Step_WaitUntil("the look raised the lift target", n"Check_TargetRaised", 0, 0.3f);
        Add_Step("the lift target clamped at MaxLift", n"Step_AssertClampedTarget");
        Add_Step_WaitUntil("the lift reached the ceiling", n"Check_LiftAtCeiling", 0, 0.8f);
        Add_Step("idle the implement and look down", n"Step_IdleAndLookDown");
        Add_Step_WaitSeconds("the idle look would have drained", 0.3f);
        Add_Step("the idle look moved nothing", n"Step_AssertIdleLookDropped");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DriveAndLookDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement), "the feature composed");
        Assert_Equals_Float(_Implement.Get_TargetLift(), 0.0, 0.001, "the lift target starts at rest");

        Drive();
        Look(FVector(0.0, 10.0, 0.0));
    }

    UFUNCTION()
    private void Check_TargetLowered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_LowestLift();
        auto Res = OutResult;
        Res.Set(_Implement.Get_TargetLift() < -1.0f);
    }

    UFUNCTION()
    private void Step_AssertDownTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Implement.Get_TargetLift(), k_DownTarget, 0.001, "10 degrees of look down lower the lift target to -10");

        const auto Target = _Implement.Get_TargetTilt();
        Assert_Equals_Float(Target.Pitch, 0.0, 0.001, "a RollOnly tilt leaves the look's Y to the lift");
        Assert_Equals_Float(Target.Roll, 0.0, 0.001, "a downward look does not roll");
        Assert_Equals_Float(Target.Yaw, 0.0, 0.001, "a RollOnly tilt never yaws");
        Record_LowestLift();
    }

    UFUNCTION()
    private void Check_LiftAtDownTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_LowestLift();
        auto Res = OutResult;
        Res.Set(Math::Abs(_Implement.Get_Lift() - k_DownTarget) <= k_LiftTolerance);
    }

    UFUNCTION()
    private void Step_StartHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _HoldStart = float32(System::GetGameTimeInSeconds());
        _HighestHeldLift = _Implement.Get_Lift();
        Record_LowestLift();
    }

    UFUNCTION()
    private void Check_HoldElapsed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_LowestLift();
        _HighestHeldLift = Math::Max(_HighestHeldLift, _Implement.Get_Lift());
        auto Res = OutResult;
        Res.Set(float32(System::GetGameTimeInSeconds()) - _HoldStart >= k_HoldSeconds);
    }

    UFUNCTION()
    private void Step_AssertHeldThenLookUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lift = _Implement.Get_Lift();
        Assert_True(Math::Abs(Lift - k_DownTarget) <= k_LiftTolerance, f"the lift holds at its target after 0.5 s (got {Lift})");
        Assert_True(_HighestHeldLift <= k_DownTarget * 0.5f, f"the held lift never returned toward rest (highest {_HighestHeldLift})");
        Assert_Equals_Float(_Implement.Get_TargetLift(), k_DownTarget, 0.001, "a still look keeps the lift target");

        ck::Trace(f"[Implement] commanded lift: overshoot {k_DownTarget - _LowestLift :.2} uu past {k_DownTarget} (lowest {_LowestLift :.2}), held at {Lift :.2}");

        Look(FVector(0.0, -60.0, 0.0));
    }

    UFUNCTION()
    private void Check_TargetRaised(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_TargetLift() > 0.0f);
    }

    UFUNCTION()
    private void Step_AssertClampedTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Implement.Get_TargetLift(), _Spec.Lift.MaxLift, 0.001,
            "60 degrees of look up from -10 clamp the lift target at MaxLift");
    }

    UFUNCTION()
    private void Check_LiftAtCeiling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Implement.Get_Lift() - _Spec.Lift.MaxLift) <= k_LiftTolerance);
    }

    UFUNCTION()
    private void Step_IdleAndLookDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _TargetBeforeIdleLook = _Implement.Get_TargetLift();
        _Implement.Request_SetDrive(FMars_Request_Implement_SetDrive(EMars_Implement_Drive::Idle));
        Look(FVector(0.0, 10.0, 0.0));
    }

    UFUNCTION()
    private void Step_AssertIdleLookDropped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Implement.Get_IsDriven(), "the implement is Idle");
        Assert_Equals_Float(_Implement.Get_TargetLift(), _TargetBeforeIdleLook, 0.001, "an idle look does not move the lift target");

        const auto Lift = _Implement.Get_Lift();
        Assert_True(Math::Abs(Lift - _Spec.Lift.MaxLift) <= k_LiftTolerance, f"the idle lift stays at its target (got {Lift})");
    }

    private void Record_LowestLift()
    {
        _LowestLift = Math::Min(_LowestLift, _Implement.Get_Lift());
    }
}
