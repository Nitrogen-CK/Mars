// Despite the name, exiting the Hands state machine resets nothing: stopping it mid-Hold leaves the phase at Hold (no
// state is entered, so nothing requests a phase). It is re-entering it that resets: starting it again re-enters Rest,
// whose enter task puts the phase back to None - what re-entering Alive does to the gloves.
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
        Add_HandsSm();
        Log_Phases();

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request a timed reach", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the phase is Hold", n"Check_IsHold", 0, 5.0f);
        Add_Step("stop the Hands state machine", n"Step_StopSm");
        Add_Step_WaitUntil("the Hands state machine is stopped", n"Check_SmStopped", 0, 5.0f);
        Add_Step("the phase is still Hold: exiting requests no phase", n"Step_AssertStillHold");
        Add_Step("start the Hands state machine again", n"Step_StartSm");
        Add_Step_WaitUntil("the phase is None", n"Check_IsNone", 0, 5.0f);
        Add_Step("the phases ran Hold, None", n"Step_AssertSequence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_StopSm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_state_machine::Request_Stop(_Sm);
    }

    UFUNCTION()
    private void Check_SmStopped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_RunStatus(_Sm) == ECk_SmRunStatus::Stopped);
    }

    UFUNCTION()
    private void Step_AssertStillHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold, f"the phase is still Hold once the state machine stopped (got {_Hands.Get_Phase() :n})");
    }

    UFUNCTION()
    private void Step_StartSm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_state_machine::Request_Start(_Sm);
    }

    UFUNCTION()
    private void Check_IsNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest, "the restarted state machine is in Rest");

        Assert_Equals_Int(_Phases.Num(), 2, "two phase changes");
        if (_Phases.Num() != 2)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, f"first change is to Hold (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::None, f"second change is back to None (got {_Phases[1] :n})");
    }
}
