// The look steers the tilt (TiltPerLookDegree 1.2: 10 degrees of look right steer the roll to 12, 10 down steer the pitch
// to -12) only while Driven; an Idle implement drops the look. The tilt gets there at MaxTiltRateDegreesPerSecond (300:
// about 5 degrees a frame at 60 Hz) while relaxing back to level at LevelReturnDegreesPerSecond (45: well within a
// second); a large look clamps at MaxTiltDegrees, and the node's offset shows the tilt. (An upward look in one frame is
// mostly a lift kick; FastUpwardLookKicksTheLiftAndItSettles pins that split.)
class UMars_AutoTest_Implement_LookSteersTheTiltAndItLevelsOut : UMars_AutoTestRig_Implement
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, FMars_Implement_Spec());

        Add_Step("look right on an idle implement", n"Step_IdleLook");
        Add_Step_WaitFrames("the idle look drained", 4);
        Add_Step("the idle implement stayed level; drive it and look right", n"Step_AssertLevelThenDriveAndLookRight");
        Add_Step_WaitUntil("the look tilted the implement", n"Check_RolledPast5", 0, 0.3f);
        Add_Step("the implement rolled right; look down", n"Step_AssertRolledThenLookDown");
        Add_Step_WaitUntil("the look tilted the implement", n"Check_PitchedPastMinus5", 0, 0.3f);
        Add_Step("the implement pitched toward the operator", n"Step_AssertPitched");
        Add_Step_WaitSeconds("the tilt relaxes", 1.0f);
        Add_Step("the implement is level again; a large look right", n"Step_AssertLevelThenLargeLook");
        Add_Step_WaitUntil("the large look tilted the implement near its clamp", n"Check_RolledPast25", 0, 0.3f);
        Add_Step("the roll clamped and the node shows it", n"Step_AssertClampedOnTheNode");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_IdleLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement), "the feature composed");
        Assert_False(_Implement.Get_IsDriven(), "the implement starts Idle");
        Look(FVector(10.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Step_AssertLevelThenDriveAndLookRight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tilt = _Implement.Get_Tilt();
        Assert_Equals_Float(Tilt.Roll, 0.0, 0.001, "an idle look leaves the roll at 0");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "an idle look leaves the pitch at 0");
        Assert_Equals_Float(_Implement.Get_TargetTilt().Roll, 0.0, 0.001, "an idle look does not steer the target");

        Drive();
        Look(FVector(10.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_RolledPast5(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_Tilt().Roll > 5.0);
    }

    UFUNCTION()
    private void Step_AssertRolledThenLookDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Implement.Get_IsDriven(), "the implement is Driven");
        Assert_True(_Drives.Num() == 1 && _Drives[0] == EMars_Implement_Drive::Driven, "OnDriveChanged reported Driven once");

        const auto Tilt = _Implement.Get_Tilt();
        Assert_True(Tilt.Roll > 5.0 && Tilt.Roll <= 12.0, f"10 degrees of look right rolled the implement toward 12, relaxing since (got {Tilt.Roll})");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "a sideways look does not pitch the implement");

        Look(FVector(0.0, 10.0, 0.0));
    }

    UFUNCTION()
    private void Check_PitchedPastMinus5(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_Tilt().Pitch < -5.0);
    }

    UFUNCTION()
    private void Step_AssertPitched(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Pitch = _Implement.Get_Tilt().Pitch;
        Assert_True(Pitch < -5.0 && Pitch >= -12.0, f"10 degrees of look down pitched the implement toward -12, relaxing since (got {Pitch})");
        Assert_Equals_Float(_Implement.Get_Lift(), 0.0, 0.001, "a downward look never lifts");
    }

    UFUNCTION()
    private void Step_AssertLevelThenLargeLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tilt = _Implement.Get_Tilt();
        Assert_True(Math::Abs(Tilt.Roll) < 0.5, f"the roll relaxed to level within a second (got {Tilt.Roll})");
        Assert_True(Math::Abs(Tilt.Pitch) < 0.5, f"the pitch relaxed to level within a second (got {Tilt.Pitch})");

        Look(FVector(100.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_RolledPast25(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_Tilt().Roll > 25.0);
    }

    UFUNCTION()
    private void Step_AssertClampedOnTheNode(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Roll = _Implement.Get_Tilt().Roll;
        Assert_True(Roll <= _Spec.Tilt.MaxTiltDegrees + 0.01,
            f"a 120-degree roll clamps at MaxTiltDegrees {_Spec.Tilt.MaxTiltDegrees} (got {Roll})");

        const auto NodeRoll = utils_scene_node::Get_Offset(_Node).Rotator().Roll;
        Assert_Equals_Float(NodeRoll, Roll, 0.5, "the node's offset rotation shows the roll");
    }
}
