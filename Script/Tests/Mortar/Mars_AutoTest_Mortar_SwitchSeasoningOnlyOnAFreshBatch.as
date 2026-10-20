// SwitchSeasoning swaps a fresh batch (Salt to Pepper, one OnBatchChanged), two switches in one drain cancel (drained
// beside an Engage, which proves the drain ran), and once the batch has taken a hit a switch is ignored (drained beside a
// Disengage, which proves the same).
class UMars_AutoTest_Mortar_SwitchSeasoningOnlyOnAFreshBatch : UMars_AutoTestRig_Mortar
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_Spec(3);
        Spec.StartSeasoning = EMars_Mortar_Seasoning::Salt;
        BuildMortar(InHandle, Spec);

        Add_Step("switch once", n"Step_SwitchOnce");
        Add_Step_WaitUntil("the batch is pepper", n"Check_Pepper");
        Add_Step("one switch swapped the fresh batch", n"Step_AssertSwitched");
        Add_Step("engage and switch twice", n"Step_EngageAndSwitchTwice");
        Add_Step_WaitUntil("the mortar is engaged", n"Check_Engaged");
        Add_Step("two switches cancelled", n"Step_AssertCancelled");
        Add_Step_WaitUntil("the window is on the marker", n"Check_WindowDeepOnMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press on the marker", n"Step_Press");
        Add_Step("release", n"Step_Release");
        Add_Step_WaitUntil("the strike landed and the pestle is back up", n"Check_StrikeDone");
        Add_Step("the batch took a hit", n"Step_AssertHit");
        Add_Step("disengage and switch", n"Step_DisengageAndSwitch");
        Add_Step_WaitUntil("the mortar is disengaged", n"Check_Disengaged");
        Add_Step("the switch after a hit was ignored", n"Step_AssertIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SwitchOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mortar.Get_Batch().Seasoning == EMars_Mortar_Seasoning::Salt, "the batch starts as salt");
        _Mortar.Request_SwitchSeasoning(FMars_Request_Mortar_SwitchSeasoning());
    }

    UFUNCTION()
    private void Check_Pepper(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mortar.Get_Batch().Seasoning == EMars_Mortar_Seasoning::Pepper);
    }

    UFUNCTION()
    private void Step_AssertSwitched(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_BatchChanges, 1, "the switch broadcast OnBatchChanged once");
        Assert_True(_LastBroadcastBatch.Seasoning == EMars_Mortar_Seasoning::Pepper, "the broadcast carried pepper");
    }

    UFUNCTION()
    private void Step_EngageAndSwitchTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
        _Mortar.Request_SwitchSeasoning(FMars_Request_Mortar_SwitchSeasoning());
        _Mortar.Request_SwitchSeasoning(FMars_Request_Mortar_SwitchSeasoning());
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mortar.Get_Batch().Seasoning == EMars_Mortar_Seasoning::Pepper, "two switches in one drain left pepper");
        Assert_Equals_Int(_BatchChanges, 1, "the cancelled pair broadcast no OnBatchChanged");
    }

    UFUNCTION()
    private void Step_AssertHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HitsLanded, 1, "the strike landed a Hit");
        Assert_Equals_Int(_Mortar.Get_Batch().CrushHits, 1, "the batch took one crush");
        Assert_Equals_Int(_BatchChanges, 2, "the hit broadcast OnBatchChanged");
    }

    UFUNCTION()
    private void Step_DisengageAndSwitch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mortar.Request_Disengage(FMars_Request_Mortar_Disengage());
        _Mortar.Request_SwitchSeasoning(FMars_Request_Mortar_SwitchSeasoning());
    }

    UFUNCTION()
    private void Step_AssertIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Batch = _Mortar.Get_Batch();
        Assert_True(Batch.Seasoning == EMars_Mortar_Seasoning::Pepper, f"a crushed batch keeps its seasoning ({Batch.Seasoning :n})");
        Assert_Equals_Int(Batch.CrushHits, 1, "the crush is kept");
        Assert_Equals_Int(_BatchChanges, 2, "the ignored switch broadcast no OnBatchChanged");
    }
}
