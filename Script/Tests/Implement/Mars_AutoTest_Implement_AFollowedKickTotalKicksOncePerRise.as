// A Kick lift following commands: the first command (kick total 12) only records the total, so the lift stays at rest; a
// command whose total rose to 30 kicks it by the rise times Gain, so it climbs above 1 uu and the spring settles it; the
// same command again kicks nothing more.
class UMars_AutoTest_Implement_AFollowedKickTotalKicksOncePerRise : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 8.0f;

    private float32 _PeakLift = 0.0f;
    private float64 _WatchStartSeconds = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, FMars_Implement_Spec());

        Add_Step("follow a first command with kick total 12", n"Step_FollowFirst");
        Add_Step_WaitUntil("watch the lift for half a second", n"Check_Watched", 0, 0);
        Add_Step("the lift stayed at rest", n"Step_AssertStill");
        Add_Step("follow a command with kick total 30", n"Step_FollowRise");
        Add_Step_WaitUntil("the lift rose above 1 uu", n"Check_Rose", 0, 0);
        Add_Step_WaitSeconds("the lift spring settles", 1.0f);
        Add_Step("the lift is back at rest", n"Step_AssertSettled");
        Add_Step("follow the same command again", n"Step_FollowRise");
        Add_Step_WaitUntil("watch the lift for half a second", n"Check_Watched", 0, 0);
        Add_Step("no second rise", n"Step_AssertNoSecondRise");
        Run_Steps(InHandle);
    }

    private void Follow(float32 InKickTotal)
    {
        auto Command = FMars_Implement_Command();
        Command.Drive = EMars_Implement_Drive::Driven;
        Command.KickTotal = InKickTotal;
        _Implement.Request_Follow(FMars_Request_Implement_Follow(Command));
        _PeakLift = 0.0f;
        _WatchStartSeconds = -1.0;
    }

    // Half a second of the lift's peak, from the first poll.
    UFUNCTION()
    private void Check_Watched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Now = System::GetGameTimeInSeconds();
        if (_WatchStartSeconds < 0.0)
        { _WatchStartSeconds = Now; }

        _PeakLift = Math::Max(_PeakLift, _Implement.Get_Lift());
        auto Res = OutResult;
        Res.Set(Now - _WatchStartSeconds >= 0.5);
    }

    UFUNCTION()
    private void Step_FollowFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Spec.Lift.Mode == EMars_Implement_LiftMode::Kick, "the implement's lift is Kick");
        Follow(12.0f);
    }

    UFUNCTION()
    private void Step_AssertStill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Implement.Get_Steering() == EMars_Implement_Steering::Followed, "the implement is Followed");
        Assert_True(_PeakLift <= 0.01f && Math::Abs(_Implement.Get_LiftVelocity()) <= 0.01f,
            f"the first command only recorded the total (peak lift {_PeakLift}, velocity {_Implement.Get_LiftVelocity()})");
    }

    UFUNCTION()
    private void Step_FollowRise(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Follow(30.0f);
    }

    UFUNCTION()
    private void Check_Rose(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _PeakLift = Math::Max(_PeakLift, _Implement.Get_Lift());
        auto Res = OutResult;
        Res.Set(_Implement.Get_Lift() > 1.0f);
    }

    UFUNCTION()
    private void Step_AssertSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lift = _Implement.Get_Lift();
        ck::Trace(f"[Implement] followed kick: lift settled at {Lift :.3}");
        Assert_True(Math::Abs(Lift) <= 0.5f, f"the lift spring brought the implement back to rest (got {Lift})");
    }

    UFUNCTION()
    private void Step_AssertNoSecondRise(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        ck::Trace(f"[Implement] followed kick: peak after the repeat {_PeakLift :.3}");
        Assert_True(_PeakLift <= 0.5f, f"the same command kicked nothing more (peak lift {_PeakLift})");
    }
}
