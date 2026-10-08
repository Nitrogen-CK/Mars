// A PitchAndYaw tilt that relaxes only while Idle, with no lift: 20 degrees of look right and 10 down steer the yaw to
// 24 and the pitch to -12 (TiltPerLookDegree 1.2) and the roll nowhere. Driven, the targets hold exactly, the tilt tracks
// them and the node's world rotation shows the yaw; Idle, every target and tilt parks at level within 0.6 s
// (LevelReturnDegreesPerSecond 90). The lift never moves.
class UMars_AutoTest_Implement_PitchAndYawHoldsWhileDrivenAndParksWhenIdle : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 6.0f;

    private const FVector k_Look = FVector(20.0, 10.0, 0.0);
    private const float32 k_HoldSeconds = 0.5f;
    private const float32 k_ParkTolerance = 0.5f;

    private float32 _HoldStart = 0.0f;
    private float32 _LargestLift = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Implement_Spec();
        Spec.Tilt.Axes = EMars_Implement_TiltAxes::PitchAndYaw;
        Spec.Tilt.Relax = EMars_Implement_Relax::WhileIdle;
        Spec.Tilt.LevelReturnDegreesPerSecond = 90.0f;
        Spec.Lift.Mode = EMars_Implement_LiftMode::None;
        BuildImplement(InHandle, Spec);

        Add_Step("drive the implement and look right and down", n"Step_DriveAndLook");
        Add_Step_WaitUntil("the look steered the targets", n"Check_TargetsSteered", 0, 0.3f);
        Add_Step("yaw and pitch took the look and roll none of it", n"Step_AssertTargetsThenHold");
        Add_Step_WaitUntil("the implement is held Driven for 0.5 s", n"Check_HoldElapsed", 0, 1.0f);
        Add_Step("the targets held, the tilt tracked them and the node shows the yaw; idle it", n"Step_AssertHeldThenIdle");
        Add_Step_WaitUntil("the implement parked within 0.6 s", n"Check_Parked", 0, 0.6f);
        Add_Step("the implement is level and never lifted", n"Step_AssertParked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DriveAndLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement), "the feature composed");
        Drive();
        Look(k_Look);
    }

    UFUNCTION()
    private void Check_TargetsSteered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_Lift();
        auto Res = OutResult;
        Res.Set(_Implement.Get_TargetTilt().Yaw > 1.0);
    }

    UFUNCTION()
    private void Step_AssertTargetsThenHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_TargetsSteered("at once:");
        _HoldStart = float32(System::GetGameTimeInSeconds());
    }

    UFUNCTION()
    private void Check_HoldElapsed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_Lift();
        auto Res = OutResult;
        Res.Set(float32(System::GetGameTimeInSeconds()) - _HoldStart >= k_HoldSeconds);
    }

    UFUNCTION()
    private void Step_AssertHeldThenIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_TargetsSteered("0.5 s Driven, the targets did not relax:");

        const auto Target = _Implement.Get_TargetTilt();
        const auto Tilt = _Implement.Get_Tilt();
        Assert_Equals_Float(Tilt.Yaw, Target.Yaw, 0.5, "the yaw tracked its target");
        Assert_Equals_Float(Tilt.Pitch, Target.Pitch, 0.5, "the pitch tracked its target");
        Assert_Equals_Float(Tilt.Roll, 0.0, 0.001, "the roll stayed level");

        // The rest rotation is identity, so the node's world rotation is the tilt.
        const auto NodeRotation = _Implement.Get_NodeWorld().Rotator();
        Assert_Equals_Float(NodeRotation.Yaw, Tilt.Yaw, 1.0, f"the node's world rotation shows the yaw (node {NodeRotation})");
        ck::Trace(f"[Implement] pitch-and-yaw: tilt {Tilt}, node world {NodeRotation}");

        _Implement.Request_SetDrive(FMars_Request_Implement_SetDrive(EMars_Implement_Drive::Idle));
    }

    UFUNCTION()
    private void Check_Parked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_Lift();
        auto Res = OutResult;
        Res.Set(Get_IsParked());
    }

    UFUNCTION()
    private void Step_AssertParked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Implement.Get_IsDriven(), "the implement is Idle");
        Assert_True(Get_IsParked(), f"targets {_Implement.Get_TargetTilt()} and tilt {_Implement.Get_Tilt()} parked at level");
        Assert_Equals_Float(_LargestLift, 0.0, 0.0001, "a None lift never moved");
        Assert_True(_Drives.Num() == 2 && _Drives[1] == EMars_Implement_Drive::Idle, "OnDriveChanged reported Driven then Idle");
    }

    private void Assert_TargetsSteered(const FString& InWhen)
    {
        const auto TiltPerLookDegree = _Spec.Tilt.TiltPerLookDegree;
        const auto Target = _Implement.Get_TargetTilt();
        Assert_Equals_Float(Target.Yaw, float32(k_Look.X) * TiltPerLookDegree, 0.001, f"{InWhen} 20 degrees of look right yaw the target");
        Assert_Equals_Float(Target.Pitch, -float32(k_Look.Y) * TiltPerLookDegree, 0.001, f"{InWhen} 10 degrees of look down pitch the target");
        Assert_Equals_Float(Target.Roll, 0.0, 0.001, f"{InWhen} a PitchAndYaw tilt never rolls");
    }

    private bool Get_IsParked()
    {
        const auto Target = _Implement.Get_TargetTilt();
        const auto Tilt = _Implement.Get_Tilt();
        return Math::Abs(Target.Yaw) <= k_ParkTolerance && Math::Abs(Target.Pitch) <= k_ParkTolerance
            && Math::Abs(Target.Roll) <= k_ParkTolerance && Math::Abs(Tilt.Yaw) <= k_ParkTolerance
            && Math::Abs(Tilt.Pitch) <= k_ParkTolerance && Math::Abs(Tilt.Roll) <= k_ParkTolerance;
    }

    private void Record_Lift()
    {
        _LargestLift = Math::Max(_LargestLift, Math::Abs(_Implement.Get_Lift()));
    }
}
