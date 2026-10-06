// A fast upward look (40 degrees in one frame, far above FlickSpeedDegreesPerSecond) is split: the degrees beyond what
// the flick speed covers that frame (40 - 250 * dt) kick the lift, once, and only the rest steers the pitch target. The
// lift rises past 2 uu and the damped spring brings it back to rest.
class UMars_AutoTest_Implement_FastUpwardLookKicksTheLiftAndItSettles : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 6.0f;

    private float32 _PeakLift = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, FMars_Implement_Spec());

        Add_Step("drive the implement", n"Step_Drive");
        Add_Step_WaitUntil("the implement is Driven", n"Check_Driven", 0, 0.5f);
        Add_Step("flick the look up", n"Step_Flick");
        Add_Step_WaitUntil("the implement lifted", n"Check_Lifted", 0, 0.2f);
        Add_Step("one kick, and the pitch target took only the slow part", n"Step_AssertKick");
        Add_Step_WaitSeconds("the lift spring settles", 0.8f);
        Add_Step("the implement is back at rest", n"Step_AssertSettled");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Drive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement), "the feature composed");
        Drive();
    }

    UFUNCTION()
    private void Step_Flick(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Implement.Get_Lift(), 0.0, 0.001, "the implement rests before the flick");
        Look(FVector(0.0, -40.0, 0.0));
    }

    UFUNCTION()
    private void Check_Lifted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _PeakLift = Math::Max(_PeakLift, _Implement.Get_Lift());
        auto Res = OutResult;
        Res.Set(_Implement.Get_Lift() > 2.0f);
    }

    UFUNCTION()
    private void Step_AssertKick(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_KickExcess.Num(), 1, "OnLiftKicked fired once");
        if (_KickExcess.Num() == 0)
        { return; }

        const auto Excess = _KickExcess[0];
        // The frame time the excess implies: 40 - Excess degrees were covered by the flick speed that frame.
        const auto ImpliedDeltaSeconds = (40.0f - Excess) / _Spec.Lift.FlickSpeedDegreesPerSecond;
        Assert_True(Excess > 0.0f && Excess < 40.0f, f"the excess is the look beyond the flick speed (got {Excess})");
        Assert_True(ImpliedDeltaSeconds > 0.0f && ImpliedDeltaSeconds <= 0.1f, f"the excess is 40 - 250 * dt for a frame time (implied dt {ImpliedDeltaSeconds})");

        const auto SlowPart = (40.0f - Excess) * _Spec.Tilt.TiltPerLookDegree;
        const auto TargetPitch = _KickTargetPitch[0];
        Assert_True(Math::Abs(TargetPitch) <= SlowPart + 0.01,
            f"the pitch target took at most the slow part {SlowPart} (got {TargetPitch}), not the {Excess}-degree excess");

        ck::Trace(f"[Implement] kick: excess {Excess :.2} deg (implied dt {ImpliedDeltaSeconds :.4} s), target pitch {TargetPitch :.2}, lift {_Implement.Get_Lift() :.2} uu");
    }

    UFUNCTION()
    private void Step_AssertSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lift = _Implement.Get_Lift();
        Assert_True(Math::Abs(Lift) <= 0.5f, f"the lift spring brought the implement back to rest (got {Lift})");
        Assert_Equals_Int(_KickExcess.Num(), 1, "no second kick");
    }
}
