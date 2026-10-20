// A strike is judged as it is pressed and applied as it lands: pressed with the window on the marker it lands a Hit and
// the batch takes one crush (OnBatchChanged); pressed with the window off the marker it still strikes and lands, as a
// Miss, and the batch is unchanged.
class UMars_AutoTest_Mortar_AHitOnTheMarkerCrushesAndAMissDoesNot : UMars_AutoTestRig_Mortar
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildMortar(InHandle, Make_Spec(3));

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the mortar is engaged", n"Check_Engaged");
        Add_Step_WaitUntil("the window is on the marker", n"Check_WindowDeepOnMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press on the marker", n"Step_Press");
        Add_Step_WaitUntil("the strike landed and the pestle is back up", n"Check_StrikeDone");
        Add_Step("the hit crushed once", n"Step_AssertHit");
        Add_Step_WaitUntil("the window is off the marker", n"Check_WindowWellOffMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press off the marker", n"Step_Press");
        Add_Step_WaitUntil("the second strike landed and the pestle is back up", n"Check_StrikeDone");
        Add_Step("the miss struck and crushed nothing", n"Step_AssertMiss");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_mortar::Get_IsOnMarker(_WindowAtPress), f"the press saw the window on the marker (centre {_WindowAtPress.Centre})");
        Assert_Equals_Int(_StrikesStarted, 1, "one strike started");
        Assert_Equals_Int(_HitsLanded, 1, "it landed a Hit");
        Assert_Equals_Int(_MissesLanded, 0, "no Miss landed");

        const auto Batch = _Mortar.Get_Batch();
        Assert_Equals_Int(Batch.CrushHits, 1, "the batch took one crush");
        Assert_True(Batch.Phase == EMars_Mortar_Phase::Crush, f"one of three crushes keeps the Crush phase (phase {Batch.Phase :n})");
        Assert_True(Batch.Stage == EMars_Mortar_Stage::Coarse, f"the batch is still Coarse (stage {Batch.Stage :n})");
        Assert_Equals_Int(_BatchChanges, 1, "the hit broadcast OnBatchChanged once");
        Assert_Equals_Int(_LastBroadcastBatch.CrushHits, 1, "the broadcast carried the crush");
    }

    UFUNCTION()
    private void Step_AssertMiss(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_mortar::Get_IsOnMarker(_WindowAtPress), f"the press saw the window off the marker (centre {_WindowAtPress.Centre})");
        Assert_Equals_Int(_StrikesStarted, 2, "a second strike started");
        Assert_Equals_Int(_MissesLanded, 1, "it landed a Miss");
        Assert_Equals_Int(_HitsLanded, 1, "no further Hit landed");
        Assert_Equals_Int(_Mortar.Get_Batch().CrushHits, 1, "the miss crushed nothing");
        Assert_Equals_Int(_BatchChanges, 1, "the miss broadcast no OnBatchChanged");
    }
}
