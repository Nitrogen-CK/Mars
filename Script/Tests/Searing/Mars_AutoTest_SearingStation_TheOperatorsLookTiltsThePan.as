// The operator's look tilts the pan through the station's input reader. The operator rig's carrier takes the real searing
// station through its Use interaction (the pan heats) and its intents receive a look delta to the right every frame until
// the pan's target roll moves: the reader forwards each drained delta to the kernel, whose implement steers the roll by the
// look's yaw. The roll is positive (to the right), within the implement's clamp, and the pitch stays level (no vertical
// look was given). Isolated origin (201000, -82000, -30000).
class UMars_AutoTest_SearingStation_TheOperatorsLookTiltsThePan : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(201000.0, -82000.0, -30000.0);
    // Behind the stand, facing the table.
    private const FVector k_CarrierLocal = FVector(-100.0, 0.0, 0.0);
    private const float64 k_LookYawDegrees = 2.0;
    // A poll budget, not a ceiling: the station composes over a few frames.
    private const int32 k_SlowPolls = 900;
    // The look reaches the kernel a frame after it drains; a handful of frames is plenty.
    private const int32 k_LookPolls = 60;

    private int32 _LooksSent = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_HeatOperator(InHandle, EMars_AutoTest_HeatStation::Searing, k_Origin, k_CarrierLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Searing, feed and docks", n"Check_HeatStationReady", k_SlowPolls, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station's state machine is Operated and the pan is hot", n"Check_OperatedAndHot", 0, 0);
        Add_Step("the pan is level before any look", n"Step_AssertLevel");
        Add_Step_WaitUntil("a look to the right rolls the pan's target", n"Check_RolledByTheLook", k_LookPolls, 0);
        Add_Step("the roll follows the look's yaw and stays inside the clamp", n"Step_AssertRoll");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_OperatedAndHot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationOperated() && _Searing.Get_IsHot());
    }

    UFUNCTION()
    private void Step_AssertLevel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Searing.Get_Pan().Get_TargetTilt();
        Assert_True(Math::Abs(Target.Roll) < 0.0001 && Math::Abs(Target.Pitch) < 0.0001, f"the pan's target is level ({Target})");
    }

    UFUNCTION()
    private void Check_RolledByTheLook(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Searing.Get_Pan().Get_TargetTilt().Roll > 0.0001)
        {
            Res.Set(true);
            return;
        }

        Add_LookDelta(FVector(k_LookYawDegrees, 0.0, 0.0));
        _LooksSent += 1;
        Res.Set(false);
    }

    UFUNCTION()
    private void Step_AssertRoll(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto TiltSpec = _Searing.Get_Pan().Get_Spec().Tilt;
        const auto Target = _Searing.Get_Pan().Get_TargetTilt();
        const auto MaxSteer = float64(_LooksSent) * k_LookYawDegrees * float64(TiltSpec.TiltPerLookDegree);
        Assert_True(_LooksSent >= 1, "at least one look was sent");
        Assert_True(Target.Roll > 0.0 && Target.Roll <= MaxSteer + 0.0001, f"the roll ({Target.Roll}) is to the right and no more than the looks steered ({MaxSteer})");
        Assert_True(Target.Roll <= float64(TiltSpec.MaxTiltDegrees) + 0.0001, f"the roll ({Target.Roll}) is inside the clamp ({TiltSpec.MaxTiltDegrees})");
        Assert_True(Math::Abs(Target.Pitch) < 0.0001, f"the pitch stays level ({Target.Pitch})");
    }
}

class AMars_AutoTest_SearingStation_TheOperatorsLookTiltsThePan_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 60.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_TheOperatorsLookTiltsThePan;
}
