// An instant reach runs the Hands sub-SM Rest -> Reach -> Grip -> Return -> Rest: the feature's phase goes Reach, Grip,
// Return, None in that order, and every change resets PhaseTime. The test entity carries FPHands and the Hands state
// machine; the reach is a bare one (no interactable), which the requests processor turns into a hand-node reach.
class UMars_AutoTest_FPHands_InstantReachRunsReachGripReturnToNone : UMars_AutoTestRig_Hands
{
    private TArray<float32> _PhaseTimesAtChange;

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
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChangedRecordingPhaseTime"));

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request an instant reach", n"Step_RequestInstantReach");
        Add_Step_WaitUntil("the phase went through Reach, Grip, Return back to None", n"Check_BackToNone", 0, 5.0f);
        Add_Step("the phases ran in order and each change reset PhaseTime", n"Step_AssertSequence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChangedRecordingPhaseTime(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        _Phases.Add(InNew);
        _PhaseTimesAtChange.Add(InHands.Get_PhaseTime());
    }

    UFUNCTION()
    private void Step_RequestInstantReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(ECk_Interaction_CompletionPolicy::Instant));
    }

    UFUNCTION()
    private void Check_BackToNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Phases.Num() >= 4 && _Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < _PhaseTimesAtChange.Num(); ++Index)
        { Assert_True(_PhaseTimesAtChange[Index] < 0.05f, f"PhaseTime was reset at change {Index}"); }

        Assert_Equals_Int(_Phases.Num(), 4, "four phase changes");
        if (_Phases.Num() != 4)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Reach, f"first change is to Reach (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::Grip, f"second change is to Grip (got {_Phases[1] :n})");
        Assert_True(_Phases[2] == EMars_FPHands_Phase::Return, f"third change is to Return (got {_Phases[2] :n})");
        Assert_True(_Phases[3] == EMars_FPHands_Phase::None, f"fourth change is back to None (got {_Phases[3] :n})");
    }
}
