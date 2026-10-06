// A timed reach requested while the gloves are releasing interrupts the release: the phase goes Release -> Hold with no
// stop at rest, and the new hold reach starts from the alpha the release had reached (no snap back to zero), then
// completes. The first hold reaches fully before it is released, so the release starts from 1 and the alpha it is
// interrupted at is well clear of zero.
class UMars_AutoTest_FPHands_ReachDuringReleaseContinuesFromReleaseAlpha : UMars_AutoTestRig_Hands
{
    private float32 _AlphaBefore = 0.0f;
    private TOptional<float32> _SecondHoldStartAlpha;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.2f;
        Spec.Reach.Grab.GripSeconds = 0.2f;
        Spec.Reach.Grab.BackSeconds = 0.2f;
        Spec.Reach.Hold.ReleaseSeconds = 0.4f;
        Add_Hands(InHandle, Spec);
        Add_HandsSm();
        Log_Phases();

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request a timed reach", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the hold reaches fully and listens for a lost target", n"Check_HoldFullyReached", 0, 5.0f);
        Add_Step("request a release", n"Step_RequestRelease");
        Add_Step_WaitUntil("the release is under way", n"Check_ReleaseUnderWay", 0, 5.0f);
        Add_Step("record the release alpha and request a timed reach again", n"Step_RecordAlphaAndReach");
        Add_Step_WaitUntil("the phase is Hold again", n"Check_SecondHold", 0, 5.0f);
        Add_Step("the new hold starts from the release alpha", n"Step_AssertNoSnap");
        Add_Step_WaitUntil("the new hold reaches fully", n"Check_FullyReached", 0, 5.0f);
        Add_Step("the phases ran Hold, Release, Hold", n"Step_AssertSequence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_HoldFullyReached(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold
            && _Hands.Get_ReachAlpha() >= 0.999f
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost._Inner.IsBound());
    }

    UFUNCTION()
    private void Check_ReleaseUnderWay(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Release && _Hands.Get_PhaseTime() > 0.08f);
    }

    UFUNCTION()
    private void Step_RecordAlphaAndReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _AlphaBefore = _Hands.Get_ReachAlpha();
        Assert_True(_AlphaBefore > 0.0f && _AlphaBefore < 1.0f, f"the release is part way back (alpha {_AlphaBefore})");
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(ECk_Interaction_CompletionPolicy::Timed));
    }

    // Captures the alpha on the first frame the second Hold is observed.
    UFUNCTION()
    private void Check_SecondHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_SecondHoldStartAlpha.IsSet() == false && _Hands.Get_Phase() == EMars_FPHands_Phase::Hold)
        { _SecondHoldStartAlpha = TOptional<float32>(_Hands.Get_ReachAlpha()); }

        auto Res = OutResult;
        Res.Set(_SecondHoldStartAlpha.IsSet());
    }

    UFUNCTION()
    private void Step_AssertNoSnap(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto StartAlpha = _SecondHoldStartAlpha.GetValue();
        Assert_True(StartAlpha >= _AlphaBefore - 0.05f,
            f"the new hold starts from the release alpha, no snap to zero (first hold alpha {StartAlpha}, release alpha {_AlphaBefore})");
    }

    UFUNCTION()
    private void Check_FullyReached(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold && _Hands.Get_ReachAlpha() >= 0.999f);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Phases.Num(), 3, "three phase changes");
        if (_Phases.Num() != 3)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, f"first change is to Hold (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::Release, f"second change is to Release (got {_Phases[1] :n})");
        Assert_True(_Phases[2] == EMars_FPHands_Phase::Hold, f"third change is back to Hold, with no stop at rest (got {_Phases[2] :n})");
    }
}
