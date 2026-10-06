// Losing the target while the gloves are still reaching into a hold interrupts it: a Release request shortly after Hold
// begins moves Hold -> Release, and the release eases back from the partial hold alpha (strictly between 0 and 1), not
// from a full reach. The hold reach lasts a full second so the request lands inside it on a slow lane.
class UMars_AutoTest_FPHands_TargetLostDuringHoldReleasesFromCurrentAlpha : UMars_AutoTestRig_Hands
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.2f;
        Spec.Reach.Grab.GripSeconds = 0.2f;
        Spec.Reach.Grab.BackSeconds = 0.2f;
        Spec.Reach.Hold.ReachSeconds = 1.0f;
        Spec.Reach.Hold.ReleaseSeconds = 0.2f;
        Add_Hands(InHandle, Spec);
        Add_HandsSm();
        Log_Phases();

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request a timed reach", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the phase is Hold and the Hold state listens for a lost target", n"Check_HoldListening", 0, 5.0f);
        Add_Step_WaitSeconds("let the hold reach get partway out", 0.1f);
        Add_Step("request a release", n"Step_RequestRelease");
        Add_Step_WaitUntil("the phase is Release", n"Check_IsRelease", 0, 5.0f);
        Add_Step("Hold, Release, from the partial hold alpha", n"Step_AssertReleaseFromHold");
        Add_Step_WaitUntil("the phase is back to None", n"Check_IsNone", 0, 5.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_HoldListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold
            && utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Hold
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_AssertReleaseFromHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto FromAlpha = _Hands.Get_ReleaseFromAlpha();
        Assert_True(FromAlpha > 0.0f, f"the release starts above rest (ReleaseFromAlpha {FromAlpha})");
        Assert_True(FromAlpha < 1.0f, f"the release starts short of a full reach (ReleaseFromAlpha {FromAlpha})");

        Assert_Equals_Int(_Phases.Num(), 2, "two phase changes");
        if (_Phases.Num() != 2)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, f"first change is to Hold (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::Release, f"second change is to Release (got {_Phases[1] :n})");
    }

    UFUNCTION()
    private void Check_IsNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }
}
