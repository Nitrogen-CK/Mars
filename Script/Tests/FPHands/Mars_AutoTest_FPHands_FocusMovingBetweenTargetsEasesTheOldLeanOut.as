// Focus moving straight from one interactable to another eases the old lean out instead of popping it: focus A (to the
// right, the right glove leans), then B (to the left) in the next drain. The right glove's applied lean (the alpha the
// anim instance blends its reach grip by, Get_HandTargets) falls over several frames while the left glove leans in;
// before the fix it dropped to zero in the drain that moved the focus.
class UMars_AutoTest_FPHands_FocusMovingBetweenTargetsEasesTheOldLeanOut : UMars_AutoTestRig_Hands
{
    private FCk_Handle _OwnerA;
    private FCk_Handle _OwnerB;
    private FCk_Handle_Interactable _A;
    private FCk_Handle_Interactable _B;
    private float32 _RightAtRefocus = 0.0f;
    private float32 _LastRight = 0.0f;
    private int32 _EasingFrames = 0;
    private int32 _RisingFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hands(InHandle, FMars_FPHands_Spec());
        _A = Add_PlainInteractable(InHandle, FVector(80.0, 30.0, 0.0), _OwnerA);
        _B = Add_PlainInteractable(InHandle, FVector(80.0, -30.0, 0.0), _OwnerB);

        Add_Step("focus A, on the right", n"Step_FocusA");
        Add_Step_WaitUntil("the right glove leans in toward A", n"Check_RightLeanedIn", k_SlowPolls, 0);
        Add_Step("focus B, on the left", n"Step_FocusB");
        Add_Step_WaitUntil("the left glove leans in toward B and A's lean is gone", n"Check_LeftLeanedInRightOut", k_SlowPolls, 0);
        Add_Step("the right glove's lean fell over several frames, never all at once", n"Step_AssertEasedOut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_FocusA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus(_A, _OwnerA));
    }

    UFUNCTION()
    private void Check_RightLeanedIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AppliedLean(EMars_Hand::Right) > _Hands.Get_Spec().Reach.Focus.Lean * 0.9f
            && Get_AppliedLean(EMars_Hand::Left) < 0.001f);
    }

    UFUNCTION()
    private void Step_FocusB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RightAtRefocus = Get_AppliedLean(EMars_Hand::Right);
        _LastRight = _RightAtRefocus;
        _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus(_B, _OwnerB));
    }

    UFUNCTION()
    private void Check_LeftLeanedInRightOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Right = Get_AppliedLean(EMars_Hand::Right);
        if (Right > 0.001f && Right < _LastRight - 0.0001f)
        { _EasingFrames += 1; }

        if (Right > _LastRight + 0.0001f)
        { _RisingFrames += 1; }

        _LastRight = Right;
        Res.Set(Get_AppliedLean(EMars_Hand::Left) > _Hands.Get_Spec().Reach.Focus.Lean * 0.9f && Right < 0.001f
            && _Hands.Get_OutgoingFocusTarget().IsSet() == false);
    }

    UFUNCTION()
    private void Step_AssertEasedOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RightAtRefocus > _Hands.Get_Spec().Reach.Focus.Lean * 0.9f, f"the right glove leaned in before the refocus (lean {_RightAtRefocus})");
        Assert_True(_EasingFrames >= 3, f"the right glove's lean fell over [{_EasingFrames}] frames (at least 3: no pop)");
        Assert_Equals_Int(_RisingFrames, 0, "the right glove's lean never rose again after the refocus");
        Assert_True(Get_AppliedLean(EMars_Hand::Right) < 0.001f, "the old lean is fully out");
    }
}
