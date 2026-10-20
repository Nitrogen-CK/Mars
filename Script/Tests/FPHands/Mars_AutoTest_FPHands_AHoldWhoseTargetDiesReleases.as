// Gloves holding a target that dies let go: the gloves reach for and hold a timed lever's interact target (no resolver
// watches it), then the lever is destroyed under them. The gloves' tick notices the dead target, and they release and come
// back to rest instead of holding nothing forever.
class UMars_AutoTest_FPHands_AHoldWhoseTargetDiesReleases : UMars_AutoTestRig_Hands
{
    private FCk_Handle _LeverRoot;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_InteractTarget _Target;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Hold.ReleaseSeconds = 0.2f;
        Add_Hands(InHandle, Spec);
        const auto Lever = Add_TimedLever(InHandle, FVector(60.0, 0.0, 0.0), 5.0f);
        _LeverRoot = Lever.Root;
        _Interactable = Lever.Interactable;
        _Target = Lever.Target;
        Add_HandsSm();
        Log_Phases();

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 0);
        Add_Step("reach for the lever's target and hold it", n"Step_HoldTheLever");
        Add_Step_WaitUntil("the phase is Hold", n"Check_IsHold", 0, 0);
        Add_Step("destroy the lever under the gloves", n"Step_DestroyTheLever");
        Add_Step_WaitUntil("the gloves let go and rest", n"Check_IsNone", 0, 0);
        Add_Step("the phases ran Hold, Release, None", n"Step_AssertReleased");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_HoldTheLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Subject = FMars_FPHands_ReachSubject(_Target, _Interactable, _LeverRoot);
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Subject, ECk_Interaction_CompletionPolicy::Timed, EMars_FPHands_ReachKind::Hold));
    }

    UFUNCTION()
    private void Step_DestroyTheLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsReachTarget(_Target), "the gloves hold the lever's target");
        utils_entity_lifetime::Request_DestroyEntity(_LeverRoot);
    }

    UFUNCTION()
    private void Check_IsNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hands.Get_ReachInteractTarget().IsSet(), "the dead target is forgotten");

        Assert_Equals_Int(_Phases.Num(), 3, "three phase changes");
        if (_Phases.Num() != 3)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, f"first change is to Hold (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::Release, f"second change is to Release (got {_Phases[1] :n})");
        Assert_True(_Phases[2] == EMars_FPHands_Phase::None, f"third change is back to None (got {_Phases[2] :n})");
    }
}
