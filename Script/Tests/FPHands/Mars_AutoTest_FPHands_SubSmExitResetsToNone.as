// The state the player's Alive is to the gloves here: a root state running the Hands sub-SM task.
class UMars_AutoTestState_HandsSubSmRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

// Leaving the Hands sub-SM puts the gloves back to rest, as leaving Alive (Downed) does: the gloves hold a timed reach
// under a state that runs the Hands sub-SM task, and stopping that state machine resets the phase to None and forgets the
// reach target, so nothing is left stretched toward a device.
class UMars_AutoTest_FPHands_SubSmExitResetsToNone : UMars_AutoTestRig_Hands
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.2f;
        Spec.Reach.Grab.GripSeconds = 0.2f;
        Spec.Reach.Grab.BackSeconds = 0.2f;
        Spec.Reach.Hold.ReleaseSeconds = 0.2f;
        Add_Hands(InHandle, Spec);
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_HandsSubSmRig));
        Log_Phases();

        Add_Step_WaitUntil("the Hands sub-SM rests, listening for a reach", n"Check_SubSmRestListening", 0, 0);
        Add_Step("request a timed reach", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the phase is Hold", n"Check_IsHold", 0, 0);
        Add_Step("stop the state machine that runs the Hands sub-SM", n"Step_StopSm");
        Add_Step_WaitUntil("the phase is None", n"Check_IsNone", 0, 0);
        Add_Step("the phases ran Hold, None, and the reach is forgotten", n"Step_AssertResetToNone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SubSmRestListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_StopSm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_state_machine::Request_Stop(_Sm);
    }

    UFUNCTION()
    private void Check_IsNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertResetToNone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_state_machine::Get_RunStatus(_Sm) == ECk_SmRunStatus::Stopped, "the state machine is stopped");
        Assert_False(_Hands.Get_Target().IsSet(), "the reach target is forgotten");
        Assert_False(_Hands.Get_ReachInteractTarget().IsSet(), "the reach's interact target is forgotten");

        Assert_Equals_Int(_Phases.Num(), 2, "two phase changes");
        if (_Phases.Num() != 2)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, f"first change is to Hold (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::None, f"second change is back to None (got {_Phases[1] :n})");
    }
}
