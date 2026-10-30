// With the wait between 0.5 and 1.0 s, the bite (OnBite once) comes that long after the bait lands, give or take a frame,
// the float dips by Bite.DipCm and the hook window is open; no bite came before the landing.
class UMars_AutoTest_Fishing_ABiteArrivesInsideTheWaitWindow : UMars_AutoTestRig_Fishing
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_MinWait = 0.5f;
    private const float32 k_MaxWait = 1.0f;
    private const float32 k_FrameSlack = 0.25f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_SpecWithNodes(InHandle);
        Spec.Bite.MinWaitSeconds = k_MinWait;
        Spec.Bite.MaxWaitSeconds = k_MaxWait;
        BuildFishing(InHandle, Spec);

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the spot is engaged", n"Check_Engaged");
        Add_Step("cast at full power", n"Step_CastFull");
        Add_Step_WaitUntil("the bait is on the water", n"Check_Waiting");
        Add_Step("no bite yet", n"Step_AssertNoBite");
        Add_Step_WaitUntil("a fish bites", n"Check_Bite");
        Add_Step("the bite came inside the wait window", n"Step_AssertBite");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertNoBite(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Bites, 0, "no OnBite before the wait");
        Assert_Equals_Float(_Fishing.Get_Bait().DipCm, 0.0f, 0.0f, "the float is not dipped");
    }

    UFUNCTION()
    private void Step_AssertBite(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = _Fishing.Get_Spec();
        Assert_Equals_Int(_Bites, 1, "one OnBite");
        const auto Wait = _BiteAtSeconds - _BaitLandedAtSeconds;
        Assert_True(Wait >= k_MinWait - k_FrameSlack && Wait <= k_MaxWait + k_FrameSlack,
            f"the bite came {Wait} s after the landing, inside [{k_MinWait}, {k_MaxWait}]");
        Assert_Equals_Float(_Fishing.Get_Bait().DipCm, Spec.Bite.DipCm, 0.0f, "the float dipped");
        Assert_True(_Fishing.Get_BaitWorld().Z < _Fishing.Get_Bait().Position.Z, "the drawn bait is under its resting height");
        Assert_Equals_Int(_BitesHooked + _BitesMissed, 0, "the bite has not ended");
    }
}
