// Disengaging mid-strike lets the pestle go: the strike in flight (a hit, pressed on the marker) is dropped, not paused.
// Re-engaged, no landing comes in a window longer than the whole strike, the batch is untouched, and the next press on
// the marker starts and lands a strike of its own.
class UMars_AutoTest_Mortar_DisengageDropsTheStrikeInFlight : UMars_AutoTestRig_Mortar
{
    default _TimeoutSeconds = 15.0f;

    // Longer than the strike and its recover (2 x StrikeSeconds).
    private const float32 k_LandingWindowSeconds = 1.2f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_Spec(3);
        Spec.StrikeSeconds = 0.5f;
        BuildMortar(InHandle, Spec);

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the mortar is engaged", n"Check_Engaged");
        Add_Step_WaitUntil("the window is on the marker", n"Check_WindowDeepOnMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press on the marker", n"Step_Press");
        Add_Step_WaitUntil("the strike is in flight", n"Check_Striking");
        Add_Step("disengage mid-strike", n"Step_Disengage");
        Add_Step_WaitUntil("the mortar is disengaged", n"Check_Disengaged");
        Add_Step("the pestle was let go", n"Step_AssertDropped");
        Add_Step("engage again", n"Step_Engage");
        Add_Step_WaitUntil("the mortar is engaged again", n"Check_Engaged");
        Add_Step_WaitSeconds("a strike kept through the leave would land in this window", k_LandingWindowSeconds);
        Add_Step("the dropped strike never landed", n"Step_AssertNeverLanded");
        Add_Step_WaitUntil("the window is on the marker again", n"Check_WindowDeepOnMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press on the marker again", n"Step_Press");
        Add_Step("release", n"Step_Release");
        Add_Step_WaitUntil("the new strike landed and the pestle is back up", n"Check_NewStrikeDone");
        Add_Step("only the new strike landed", n"Step_AssertNewStrike");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Striking(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Striking);
    }

    UFUNCTION()
    private void Step_AssertDropped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_StrikesStarted, 1, "the strike had started");
        Assert_Equals_Int(Get_StrikesLanded(), 0, "it had not landed");
        Assert_True(_Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Idle, "the disengage put the pestle back up");
        Assert_True(_Mortar.Get_Pestle() == EMars_Mortar_Pestle::Resting, "the pestle rests");
    }

    UFUNCTION()
    private void Step_AssertNeverLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_StrikesLanded(), 0, "the dropped strike never landed");
        Assert_Equals_Int(_Mortar.Get_Batch().CrushHits, 0, "the batch took no crush");
        Assert_Equals_Int(_BatchChanges, 0, "the batch never changed");
        Assert_True(_Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Idle, "the pestle is still up");
    }

    UFUNCTION()
    private void Check_NewStrikeDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_StrikesLanded() >= 1 && _Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Idle);
    }

    UFUNCTION()
    private void Step_AssertNewStrike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_StrikesStarted, 2, "the new press started a second strike");
        Assert_Equals_Int(_HitsLanded, 1, "one Hit landed in all");
        Assert_Equals_Int(_MissesLanded, 0, "no Miss");
        Assert_Equals_Int(_Mortar.Get_Batch().CrushHits, 1, "the batch took exactly one crush");
    }
}
