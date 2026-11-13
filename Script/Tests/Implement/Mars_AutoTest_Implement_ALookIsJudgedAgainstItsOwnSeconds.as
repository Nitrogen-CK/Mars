// A look that carries the seconds it took is judged against them, not against the frame it arrived in. 12 degrees up that
// took 0.1 s is slower than FlickSpeedDegreesPerSecond: it only pitches the implement, kicks nothing and leaves the lift at
// rest. The same 12 degrees carrying no seconds took this frame: far above the flick speed, it kicks the lift once.
class UMars_AutoTest_Implement_ALookIsJudgedAgainstItsOwnSeconds : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 6.0f;

    private const float64 k_LookDegrees = 12.0;
    private const float32 k_LookSeconds = 0.1f;
    // Frames the slow look is watched for.
    private const int32 k_WatchFrames = 20;

    private int32 _WatchedFrames = 0;
    private float32 _PeakLift = 0.0f;
    private float32 _PeakTargetPitch = 0.0f;
    private float32 _FrameSeconds = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, FMars_Implement_Spec());

        Add_Step("drive the implement", n"Step_Drive");
        Add_Step_WaitUntil("the implement is Driven", n"Check_Driven", 0, 0);
        Add_Step("a 12-degree upward look that took 0.1 s", n"Step_SlowLook");
        Add_Step_WaitUntil("the slow look is watched", n"Check_Watched", 0, 0);
        Add_Step("the slow look pitched the implement and kicked nothing", n"Step_AssertNoKick");
        Add_Step("reset and drive again", n"Step_ResetAndDrive");
        Add_Step_WaitUntil("the implement is Driven and at rest", n"Check_DrivenAtRest", 0, 0);
        Add_Step("the same look carrying no seconds", n"Step_FrameLook");
        Add_Step_WaitUntil("the implement lifted", n"Check_Lifted", 0, 0);
        Add_Step("the look kicked the lift once", n"Step_AssertKick");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Drive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement), "the feature composed");
        Assert_True(_Spec.Lift.Mode == EMars_Implement_LiftMode::Kick, "the default lift is a Kick lift");
        Drive();
    }

    UFUNCTION()
    private void Step_SlowLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Implement.Get_Lift(), 0.0, 0.001, "the implement rests before the look");
        _Implement.Request_Look(FMars_Request_Implement_Look(FVector(0.0, -k_LookDegrees, 0.0), TOptional<float32>(k_LookSeconds)));
    }

    UFUNCTION()
    private void Check_Watched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_WatchedFrames;
        _PeakLift = Math::Max(_PeakLift, _Implement.Get_Lift());
        _PeakTargetPitch = Math::Max(_PeakTargetPitch, float32(Math::Abs(_Implement.Get_TargetTilt().Pitch)));
        auto Res = OutResult;
        Res.Set(_WatchedFrames >= k_WatchFrames);
    }

    UFUNCTION()
    private void Step_AssertNoKick(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto KickTotal = _Implement.Get_Fragment(FMars_Fragment_Implement).KickTotal;
        Log(f"[ImplementTest] slow look: peak lift {_PeakLift}, kick total {KickTotal}, kicks {_KickExcess.Num()}, peak target pitch {_PeakTargetPitch}");
        Assert_True(_PeakLift < 0.1f, f"the lift stayed under 0.1 (peak {_PeakLift})");
        Assert_True(KickTotal == 0.0f, f"the kick total is 0 (got {KickTotal})");
        Assert_Equals_Int(_KickExcess.Num(), 0, "OnLiftKicked never fired");
        Assert_True(_PeakTargetPitch > 1.0f, f"the pitch target moved (peak {_PeakTargetPitch})");
    }

    UFUNCTION()
    private void Step_ResetAndDrive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Implement.Request_Reset(FMars_Request_Implement_Reset());
        Drive();
    }

    UFUNCTION()
    private void Check_DrivenAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_IsDriven() && Math::Abs(_Implement.Get_Lift()) < 0.001f);
    }

    UFUNCTION()
    private void Step_FrameLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FrameSeconds = float32(Gameplay::GetWorldDeltaSeconds());
        Look(FVector(0.0, -k_LookDegrees, 0.0));
    }

    UFUNCTION()
    private void Check_Lifted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_Lift() > 0.5f);
    }

    UFUNCTION()
    private void Step_AssertKick(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[ImplementTest] frame look: lift {_Implement.Get_Lift()}, kicks {_KickExcess.Num()}, frame seconds {_FrameSeconds}");
        Assert_True(_Implement.Get_Lift() > 0.5f, f"the lift rose (got {_Implement.Get_Lift()})");
        Assert_Equals_Int(_KickExcess.Num(), 1, "OnLiftKicked fired once");
    }
}
