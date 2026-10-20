// A cycle that does not loop starts running, enters Idle, Telegraph and Fire in order (each entry from the previous
// phase's timer, an Advance), and after Fire's timer stops itself: OnRunningChanged Running then Stopped, and no fourth
// phase entry.
class UMars_AutoTest_Cycle_RunsItsPhasesInOrderAndStopsAtTheEnd : UMars_AutoTestRig_Cycle
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddCycle(InHandle, Make_Spec(false));

        Add_Step("the cycle composed", n"Step_AssertComposed");
        Add_Step_WaitUntil("the cycle ran to its end and stopped", n"Check_Stopped", k_SlowPolls, 0);
        Add_Step("three phases in order, Running then Stopped", n"Step_AssertRun");
        Add_Step_WaitSeconds("give a wrongful loop time to land", k_PhaseSeconds * 3.0f);
        Add_Step("still stopped, still three phase entries", n"Step_AssertNoLoop");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Cycle, "utils_cycle::Add accepted the spec");
    }

    UFUNCTION()
    private void Check_Stopped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RunChanges.Num() == 2);
    }

    UFUNCTION()
    private void Step_AssertRun(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RunChanges[0] == EMars_Cycle_RunState::Running, "the first edge is Running");
        Assert_True(_RunChanges[1] == EMars_Cycle_RunState::Stopped, "the second edge is Stopped");
        Assert_False(_Cycle.Get_IsRunning(), "the cycle is stopped");

        Assert_Equals_Int(_Phases.Num(), 3, "three phase entries");
        if (_Phases.Num() != 3)
        { return; }

        Assert_True(_Phases[0] == GameplayTags::Mechanism_Phase_Idle && _PhaseIndices[0] == 0, "Idle at index 0 first");
        Assert_True(_Phases[1] == GameplayTags::Mechanism_Phase_Telegraph && _PhaseIndices[1] == 1, "Telegraph at index 1 second");
        Assert_True(_Phases[2] == GameplayTags::Mechanism_Phase_Fire && _PhaseIndices[2] == 2, "Fire at index 2 third");
        Assert_True(_Cycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Fire, "a stopped cycle keeps its last phase");
    }

    UFUNCTION()
    private void Step_AssertNoLoop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Cycle.Get_IsRunning(), "still stopped");
        Assert_Equals_Int(_Phases.Num(), 3, "no phase entered after the end");
    }
}
