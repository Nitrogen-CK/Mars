// OnLiftKicked is broadcast once the frame applied: a handler reads the integrated lift and the pose the node was written
// with, never the state before the lift spring ran. A driven implement at rest is flicked up (40 degrees in one frame):
// as the kick fires, the lift has already risen off rest (the spring integrated the kicked velocity) and the node's last
// written lift is that same lift.
class UMars_AutoTest_Implement_LiftKickFiresAfterThePoseWrite : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 6.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, FMars_Implement_Spec());

        Add_Step("drive the implement", n"Step_Drive");
        Add_Step_WaitUntil("the implement is Driven", n"Check_Driven", 0, 0);
        Add_Step("flick the look up", n"Step_Flick");
        Add_Step_WaitUntil("the lift was kicked", n"Check_Kicked", 0, 0);
        Add_Step("the kick's handler read the integrated, written lift", n"Step_AssertKickReadTheFrame");
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
        Assert_Equals_Float(_Implement.Get_Lift(), 0.0, 0.0, "the implement rests before the flick");
        Look(FVector(0.0, -40.0, 0.0));
    }

    UFUNCTION()
    private void Check_Kicked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_KickExcess.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertKickReadTheFrame(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_KickExcess.Num(), 1, "OnLiftKicked fired once");
        if (_KickLift.Num() == 0)
        { return; }

        const auto Lift = _KickLift[0];
        Assert_True(Lift > 0.0f && Lift <= _Spec.Lift.MaxLift, f"the lift had risen off rest within its clamp as the kick fired (got {Lift})");
        Assert_Equals_Float(_KickWrittenLift[0], Lift, 0.0001, "the node had been written with that lift as the kick fired");
    }
}
