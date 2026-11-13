// A pan-like implement (its tilt targets relax every frame) told to follow a Driven command rolled 20 degrees holds that
// roll: a second later it shows 20, and a second after that still 20 (a followed implement does not relax its targets).
// Ten looks change nothing (a followed implement drops its looks). A Reset makes it steer itself again, level.
class UMars_AutoTest_Implement_AFollowedTiltHoldsItsTargetAndDropsTheLook : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 8.0f;

    private const float32 k_Roll = 20.0f;
    private const int32 k_LookCount = 10;

    private int32 _LooksSent = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, FMars_Implement_Spec());

        Add_Step("follow a Driven command rolled 20 degrees", n"Step_Follow");
        Add_Step_WaitSeconds("the implement follows for a second", 1.0f);
        Add_Step("it shows the commanded roll", n"Step_AssertHeld");
        Add_Step_WaitSeconds("another second", 1.0f);
        Add_Step("it still shows the commanded roll", n"Step_AssertHeld");
        Add_Step_WaitUntil("ten looks sent, one a frame", n"Check_LooksSent", 0, 0);
        Add_Step_WaitSeconds("the looks would have steered by now", 0.3f);
        Add_Step("the looks changed nothing", n"Step_AssertHeld");
        Add_Step("reset it", n"Step_Reset");
        Add_Step_WaitUntil("it steers itself again", n"Check_Own", 0, 0);
        Add_Step("it is level", n"Step_AssertLevel");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Follow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Spec.Tilt.Relax == EMars_Implement_Relax::Always, "the implement's targets relax every frame");
        auto Command = FMars_Implement_Command();
        Command.Drive = EMars_Implement_Drive::Driven;
        Command.Tilt = FRotator(0.0, 0.0, k_Roll);
        _Implement.Request_Follow(FMars_Request_Implement_Follow(Command));
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Roll = _Implement.Get_Tilt().Roll;
        ck::Trace(f"[Implement] followed: roll {Roll :.3} target {_Implement.Get_TargetTilt().Roll :.3} steering {_Implement.Get_Steering() :n} drive {_Implement.Get_Drive() :n}");
        Assert_True(_Implement.Get_Steering() == EMars_Implement_Steering::Followed, "the implement is Followed");
        Assert_True(_Implement.Get_IsDriven(), "the implement is Driven by the command");
        Assert_Equals_Float(Roll, k_Roll, 0.1, "the implement shows the commanded roll");
    }

    UFUNCTION()
    private void Check_LooksSent(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_LooksSent < k_LookCount)
        {
            Look(FVector(5.0, 5.0, 0.0));
            ++_LooksSent;
        }

        auto Res = OutResult;
        Res.Set(_LooksSent >= k_LookCount);
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Implement.Request_Reset(FMars_Request_Implement_Reset());
    }

    UFUNCTION()
    private void Check_Own(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_Steering() == EMars_Implement_Steering::Own);
    }

    UFUNCTION()
    private void Step_AssertLevel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tilt = _Implement.Get_Tilt();
        const auto Target = _Implement.Get_TargetTilt();
        Assert_True(Tilt.IsNearlyZero(0.001) && Target.IsNearlyZero(0.001), f"the reset implement is level (tilt {Tilt}, target {Target})");
        Assert_False(_Implement.Get_IsDriven(), "the reset implement is Idle");
    }
}
