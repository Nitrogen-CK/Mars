// The player's ManipulateControl task begins a lever's manipulation only once the gloves grip it: Use on a
// ManuallyCompleted lever starts the interaction at once, but the Control is not manipulated while the gloves are still
// reaching. The lever's interactable is transform-only, so the reach resolves as a point grip at the lever root.
class UMars_AutoTest_Control_ManipulationWaitsForTheGrip : UMars_AutoTestRig_LeverThroughPlayer
{
    private bool _SawManipulationBeforeGrip = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 5.0f);
        Add_Step("add the lever to the resolver and open Use", n"Step_UseLever");
        Add_Step_WaitUntil("the lever is manipulated", n"Check_IsManipulatingWatchingTheGrip", 0, 5.0f);
        Add_Step("the manipulation began only once the gloves gripped the lever", n"Step_AssertGripFirst");
        Run_Steps(InHandle);
    }

    // Every evaluation also records a manipulation seen while the gloves were not yet on the lever.
    UFUNCTION()
    private void Check_IsManipulatingWatchingTheGrip(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsManipulating = _Control.Get_IsManipulating();
        if (IsManipulating && _Hands.Get_IsGrippingTarget(_Target) == false)
        { _SawManipulationBeforeGrip = true; }

        auto Res = OutResult;
        Res.Set(IsManipulating);
    }

    UFUNCTION()
    private void Step_AssertGripFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_SawManipulationBeforeGrip,
            f"the lever was manipulated while the gloves were not gripping it (phase {_Hands.Get_Phase() :n}, alpha {_Hands.Get_ReachAlpha()})");
        Assert_True(_Hands.Get_IsGrippingTarget(_Target), "the gloves grip the lever while it is manipulated");
        Assert_True(_Control.Get_IsManipulating() && ck::IsValid(_Control.Get_Fragment(FMars_Fragment_Control).Manipulation.GetValue().Interaction),
            "the manipulation carries the started interaction (the threshold ends it)");
    }
}
