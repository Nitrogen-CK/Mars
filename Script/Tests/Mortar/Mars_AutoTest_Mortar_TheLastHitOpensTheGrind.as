// With two crushes needed, the first hit counts and keeps the Crush phase; the second cracks the batch and opens the Grind
// phase, with the grind not yet started (the pestle was released) and the batch half done.
class UMars_AutoTest_Mortar_TheLastHitOpensTheGrind : UMars_AutoTestRig_Mortar
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildMortar(InHandle, Make_Spec(2));

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the mortar is engaged", n"Check_Engaged");
        Add_Step_WaitUntil("the window is on the marker", n"Check_WindowDeepOnMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press on the marker", n"Step_Press");
        Add_Step("release", n"Step_Release");
        Add_Step_WaitUntil("the first strike landed and the pestle is back up", n"Check_StrikeDone");
        Add_Step("the first hit kept the Crush phase", n"Step_AssertFirstHit");
        Add_Step_WaitUntil("the window is on the marker again", n"Check_WindowDeepOnMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press on the marker again", n"Step_Press");
        Add_Step("release again", n"Step_Release");
        Add_Step_WaitUntil("the second strike landed and the pestle is back up", n"Check_StrikeDone");
        Add_Step("the last hit cracked the batch and opened the grind", n"Step_AssertGrindOpen");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertFirstHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HitsLanded, 1, "the first strike was a Hit");
        const auto Batch = _Mortar.Get_Batch();
        Assert_Equals_Int(Batch.CrushHits, 1, "one crush");
        Assert_True(Batch.Phase == EMars_Mortar_Phase::Crush, f"one of two crushes keeps the Crush phase (phase {Batch.Phase :n})");
        Assert_True(Batch.Stage == EMars_Mortar_Stage::Coarse, f"still Coarse (stage {Batch.Stage :n})");
        Assert_Equals_Float(_Mortar.Get_Progress(), 0.25f, 0.0001f, "one of two crushes is a quarter of the batch");
    }

    UFUNCTION()
    private void Step_AssertGrindOpen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HitsLanded, 2, "both strikes were Hits");
        Assert_Equals_Int(_MissesLanded, 0, "no Miss");

        const auto Batch = _Mortar.Get_Batch();
        Assert_Equals_Int(Batch.CrushHits, 2, "two crushes");
        Assert_True(Batch.Phase == EMars_Mortar_Phase::Grind, f"the last hit opened the Grind phase (phase {Batch.Phase :n})");
        Assert_True(Batch.Stage == EMars_Mortar_Stage::Cracked, f"the last hit cracked the batch (stage {Batch.Stage :n})");
        Assert_Equals_Float(Batch.GrindProgress, 0.0f, 0.0f, "a released pestle has not ground");
        Assert_True(_Mortar.Get_Pestle() == EMars_Mortar_Pestle::Resting, "the released pestle rests");
        Assert_Equals_Float(_Mortar.Get_Progress(), 0.5f, 0.0001f, "a cracked batch is half done");
        Assert_Equals_Int(_BatchChanges, 2, "each hit broadcast OnBatchChanged once");
        Assert_True(_LastBroadcastBatch.Phase == EMars_Mortar_Phase::Grind, "the last broadcast carried the Grind phase");
    }
}
