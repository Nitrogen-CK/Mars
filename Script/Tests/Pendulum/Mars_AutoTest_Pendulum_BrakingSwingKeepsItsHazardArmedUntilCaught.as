// A stop is not a rest: a running pendulum braked toward its catch angle (-30, the far edge from where it is stopped) keeps
// swinging, and its hazard stays armed until the catch; the catch reports OnCameToRest once and disarms the hazard.
class UMars_AutoTest_Pendulum_BrakingSwingKeepsItsHazardArmedUntilCaught : UMars_AutoTestRig_Pendulum
{
    private bool _SawArmedWhileBraking = false;
    private bool _SawDisarmWhileBraking = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Swing = Make_SwingSpec();
        Swing.CatchAngleDegrees = TOptional<float32>(-30.0f);
        AddPendulum(InHandle, FVector(44000.0, 330000.0, -41000.0), Swing, EMars_PoweredBehavior::SuppressWhilePowered);

        Add_Step("the pendulum composed", n"Step_AssertComposed");
        Add_Step_WaitUntil("the running swing armed its hazard and nears the far edge", n"Check_ArmedNearFarEdge", k_SlowPolls, 0);
        Add_Step("brake the swing", n"Step_Stop");
        Add_Step_WaitUntil("the swing is caught", n"Check_Caught", k_SlowPolls, 0);
        Add_Step("the hazard stayed armed while braking", n"Step_AssertArmedWhileBraking");
        Add_Step_WaitUntil("the catch disarms the hazard", n"Check_Disarmed", 0, 0);
        Add_Step("one rest, one disarm", n"Step_AssertRest");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Pendulum, "utils_pendulum::Add accepted a spec with its parts");
        Assert_True(_Oscillator.Get_IsRunning(), "the swing starts running");
    }

    UFUNCTION()
    private void Check_ArmedNearFarEdge(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hazard.Get_IsArmed() && _Oscillator.Get_Angle() > 20.0f);
    }

    UFUNCTION()
    private void Step_Stop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Oscillator.Request_SetRunning(FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState::Stopped));
    }

    // Latches the braking window: stopped, not yet caught, and the hazard still armed.
    UFUNCTION()
    private void Check_Caught(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsBraking = _Oscillator.Get_IsRunning() == false && _Oscillator.Get_IsCaught() == false
            && _Oscillator.Has_Fragment(FMars_Fragment_Oscillator_Requests) == false;
        if (IsBraking && _Hazard.Get_IsArmed())
        { _SawArmedWhileBraking = true; }

        if (IsBraking && _DisarmedEdges > 0)
        { _SawDisarmWhileBraking = true; }

        auto Res = OutResult;
        Res.Set(_Oscillator.Get_IsCaught());
    }

    UFUNCTION()
    private void Step_AssertArmedWhileBraking(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawArmedWhileBraking, "the hazard was armed while the stopped swing braked toward its catch angle");
        Assert_False(_SawDisarmWhileBraking, "the stop itself disarmed nothing: no Disarmed edge before the catch");
    }

    UFUNCTION()
    private void Check_Disarmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hazard.Get_IsArmed() == false);
    }

    UFUNCTION()
    private void Step_AssertRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_RestCount, 1, "the catch broadcast OnCameToRest once");
        Assert_Equals_Int(_DisarmedEdges, 1, "the hazard disarmed once");
        Assert_Equals_Float(_Oscillator.Get_Angle(), -30.0f, 0.5, "held at the catch angle");
    }
}
