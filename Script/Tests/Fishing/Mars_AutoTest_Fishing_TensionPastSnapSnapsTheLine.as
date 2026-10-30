// With the snap at 0.2 and a fast strain, holding the reel through the fight breaks the line (OnSnapped once, Snapped, the
// tension pinned at the snap, no fish landed), a hold on a snapped line does nothing, and a Reset re-rigs the spot Idle
// with no line out.
class UMars_AutoTest_Fishing_TensionPastSnapSnapsTheLine : UMars_AutoTestRig_Fishing
{
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_SpecWithNodes(InHandle);
        Spec.Reel.ReelSpeedCmPerS = 50.0f;
        Spec.Reel.TensionGainPerS = 1.0f;
        Spec.Reel.SnapTension = 0.2f;
        Spec.Reel.HookTension = 0.0f;
        BuildFishing(InHandle, Spec);

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the spot is engaged", n"Check_Engaged");
        Add_Step("cast at full power", n"Step_CastFull");
        Add_Step_WaitUntil("a fish bites", n"Check_Bite");
        Add_Step("strike the hook", n"Step_Hook");
        Add_Step_WaitUntil("the fight is on", n"Check_Reeling");
        Add_Step("hold the reel", n"Step_Hold");
        Add_Step_WaitUntil("the line snaps", n"Check_Snapped");
        Add_Step("the snap broadcast and pinned the tension", n"Step_AssertSnapped");
        Add_Step_WaitSeconds("a beat", 0.2f);
        Add_Step("reset", n"Step_Reset");
        Add_Step_WaitUntil("the spot is re-rigged", n"Check_Idle");
        Add_Step("the reset left no line out", n"Step_AssertRigged");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertSnapped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = _Fishing.Get_Spec();
        Assert_Equals_Int(_Snaps, 1, "one OnSnapped");
        Assert_Equals_Int(_Lands, 0, "no OnLanded");
        Assert_Equals_Float(_Fishing.Get_Tension(), Spec.Reel.SnapTension, 0.001f, "the tension is pinned at the snap");
        Assert_False(_Fishing.Get_HasLineOut(), "a snapped line is not out");
    }

    UFUNCTION()
    private void Step_AssertRigged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Snaps, 1, "still one snap");
        Assert_Equals_Float(_Fishing.Get_Tension(), 0.0f, 0.0f, "no strain");
        Assert_Equals_Float(_Fishing.Get_LineLengthCm(), 0.0f, 0.0f, "no line out");
        Assert_True(_Fishing.Get_Catch().Item.IsNull(), "no fish on");
        Assert_True(_Fishing.Get_IsEngaged(), "the reset kept the operator");
    }
}
