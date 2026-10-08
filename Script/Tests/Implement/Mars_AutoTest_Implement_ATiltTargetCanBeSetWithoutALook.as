// A tilt-free implement (Axes None, Relax WhileIdle, no lift, MaxTiltDegrees 60), Driven: a set tilt target of roll 55
// is taken as it is and the tilt tracks it within 1 degree in 0.5 s (the node's world rotation shows it); a look (30, 30)
// moves no target, no tilt and no lift; Idle, the target and the tilt relax back to level.
class UMars_AutoTest_Implement_ATiltTargetCanBeSetWithoutALook : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 6.0f;

    private const float32 k_MaxTiltDegrees = 60.0f;
    private const float32 k_TargetRoll = 55.0f;
    private const float32 k_TrackTolerance = 1.0f;
    private const float32 k_TrackSeconds = 0.5f;
    private const FVector k_Look = FVector(30.0, 30.0, 0.0);
    // The look is drained and its frame ticked well within this.
    private const float32 k_LookSettleSeconds = 0.2f;
    private const float32 k_LevelTolerance = 0.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Implement_Spec();
        Spec.Tilt.Axes = EMars_Implement_TiltAxes::None;
        Spec.Tilt.Relax = EMars_Implement_Relax::WhileIdle;
        Spec.Tilt.MaxTiltDegrees = k_MaxTiltDegrees;
        Spec.Lift.Mode = EMars_Implement_LiftMode::None;
        BuildImplement(InHandle, Spec);

        Add_Step("drive the implement and set a roll target of 55", n"Step_DriveAndSetTilt");
        Add_Step_WaitUntil("the roll target is set", n"Check_TargetSet", 0, 0.3f);
        Add_Step("the roll target is 55 and nothing else moved", n"Step_AssertTarget");
        Add_Step_WaitUntil("the tilt tracked the target within 0.5 s", n"Check_Tracked", 0, k_TrackSeconds);
        Add_Step("the node shows the roll; look right and down", n"Step_AssertTrackedThenLook");
        Add_Step_WaitSeconds("the look is drained and ticked", k_LookSettleSeconds);
        Add_Step("the look moved nothing; idle it", n"Step_AssertLookIgnoredThenIdle");
        Add_Step_WaitUntil("the implement relaxed to level", n"Check_Level", 0, 2.0f);
        Add_Step("the implement is level and Idle", n"Step_AssertLevel");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DriveAndSetTilt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement), "the feature composed");
        Drive();
        _Implement.Request_SetTiltTarget(FMars_Request_Implement_SetTiltTarget(FRotator(0.0, 0.0, float64(k_TargetRoll))));
    }

    UFUNCTION()
    private void Check_TargetSet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_TargetTilt().Roll > 1.0);
    }

    UFUNCTION()
    private void Step_AssertTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_TargetIsTheSetOne("set:");
        Assert_True(_Implement.Get_IsDriven(), "the implement is Driven");
    }

    UFUNCTION()
    private void Check_Tracked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Implement.Get_Tilt().Roll - float64(k_TargetRoll)) <= float64(k_TrackTolerance));
    }

    UFUNCTION()
    private void Step_AssertTrackedThenLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tilt = _Implement.Get_Tilt();
        // The rest rotation is identity, so the node's world rotation is the tilt.
        const auto NodeRotation = _Implement.Get_NodeWorld().Rotator();
        ck::Trace(f"[Implement] tilt target: tilt {Tilt}, node world {NodeRotation}");
        Assert_Equals_Float(NodeRotation.Roll, float64(k_TargetRoll), 1.0, f"the node's world rotation shows the roll (node {NodeRotation})");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "no pitch");
        Assert_Equals_Float(Tilt.Yaw, 0.0, 0.001, "no yaw");

        Look(k_Look);
    }

    UFUNCTION()
    private void Step_AssertLookIgnoredThenIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_TargetIsTheSetOne("after the look:");
        Assert_Equals_Float(_Implement.Get_Tilt().Roll, float64(k_TargetRoll), float64(k_TrackTolerance), "the tilt held the set roll");
        Assert_Equals_Float(_Implement.Get_Lift(), 0.0, 0.0001, "a None lift never moved");

        _Implement.Request_SetDrive(FMars_Request_Implement_SetDrive(EMars_Implement_Drive::Idle));
    }

    UFUNCTION()
    private void Check_Level(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsLevel());
    }

    UFUNCTION()
    private void Step_AssertLevel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Implement.Get_IsDriven(), "the implement is Idle");
        Assert_True(Get_IsLevel(), f"target {_Implement.Get_TargetTilt()} and tilt {_Implement.Get_Tilt()} relaxed to level");
        Assert_True(_Drives.Num() == 2 && _Drives[1] == EMars_Implement_Drive::Idle, "OnDriveChanged reported Driven then Idle");
    }

    private void Assert_TargetIsTheSetOne(const FString& InWhen)
    {
        const auto Target = _Implement.Get_TargetTilt();
        Assert_Equals_Float(Target.Roll, float64(k_TargetRoll), 0.001, f"{InWhen} the roll target is the set one");
        Assert_Equals_Float(Target.Pitch, 0.0, 0.001, f"{InWhen} no pitch target");
        Assert_Equals_Float(Target.Yaw, 0.0, 0.001, f"{InWhen} no yaw target");
    }

    private bool Get_IsLevel()
    {
        const auto Target = _Implement.Get_TargetTilt();
        const auto Tilt = _Implement.Get_Tilt();
        return Math::Abs(Target.Roll) <= float64(k_LevelTolerance) && Math::Abs(Tilt.Roll) <= float64(k_LevelTolerance);
    }
}
