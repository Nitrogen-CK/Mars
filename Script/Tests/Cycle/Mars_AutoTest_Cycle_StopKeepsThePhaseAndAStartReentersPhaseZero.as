// SetRunning on a looping cycle: Stopped in Telegraph keeps Telegraph as the current phase and enters no further phase;
// Running again re-enters phase 0 (Idle) afresh rather than resuming Telegraph.
class UMars_AutoTest_Cycle_StopKeepsThePhaseAndAStartReentersPhaseZero : UMars_AutoTestRig_Cycle
{
    private int32 _PhasesAtStop = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddCycle(InHandle, Make_Spec(true));

        Add_Step_WaitUntil("the cycle reaches Telegraph, and is told to stop there", n"Check_InTelegraph", k_SlowPolls, 0);
        Add_Step_WaitUntil("the cycle stops", n"Check_Stopped", 0, 0);
        Add_Step_WaitSeconds("give a wrongful advance time to land", k_PhaseSeconds * 2.0f);
        Add_Step("stopped in Telegraph, no further phase", n"Step_AssertHeld");
        Add_Step("start it again", n"Step_Start");
        Add_Step_WaitUntil("the start re-enters a phase", n"Check_Reentered", 0, 0);
        Add_Step("the start re-entered Idle at index 0", n"Step_AssertReentered");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_InTelegraph(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        // Stopped from the poll that sees Telegraph, so a 0.15 s phase cannot advance between the two.
        const auto InTelegraph = _Cycle.Get_IsRunning() && _Cycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Telegraph;
        if (InTelegraph)
        { _Cycle.Request_SetRunning(FMars_Request_Cycle_SetRunning(EMars_Cycle_RunState::Stopped)); }

        auto Res = OutResult;
        Res.Set(InTelegraph);
    }

    UFUNCTION()
    private void Check_Stopped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cycle.Get_IsRunning() == false);
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhasesAtStop = _Phases.Num();
        Assert_True(_Cycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Telegraph, "a stop keeps the current phase");
        Assert_True(_Phases.Num() >= 2 && _Phases.Last() == GameplayTags::Mechanism_Phase_Telegraph, "no phase was entered after the stop");
        Assert_Equals_Int(_RunChanges.Num(), 2, "Running at the start, Stopped now");
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Cycle.Request_SetRunning(FMars_Request_Cycle_SetRunning(EMars_Cycle_RunState::Running));
    }

    UFUNCTION()
    private void Check_Reentered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Phases.Num() > _PhasesAtStop);
    }

    UFUNCTION()
    private void Step_AssertReentered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Phases[_PhasesAtStop] == GameplayTags::Mechanism_Phase_Idle, "the start entered Idle");
        Assert_Equals_Int(_PhaseIndices[_PhasesAtStop], 0, "at index 0");
        Assert_True(_RunChanges.Num() == 3 && _RunChanges[2] == EMars_Cycle_RunState::Running, "a third edge, Running");
    }
}
