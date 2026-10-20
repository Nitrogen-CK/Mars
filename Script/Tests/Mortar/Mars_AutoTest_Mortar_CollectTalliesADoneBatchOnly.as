// Collect is ignored on a batch that is not Done (drained beside an Engage, which proves the drain ran), and a Done batch
// is not tallied until it is collected. Two Collects in one drain empty the Done batch once: the tally counts one batch of
// its seasoning (Pepper, the spec's start) and a fresh batch of the same seasoning takes its place.
class UMars_AutoTest_Mortar_CollectTalliesADoneBatchOnly : UMars_AutoTestRig_Mortar
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_Spec(1);
        Spec.GrindSeconds = 0.25f;
        Spec.StartSeasoning = EMars_Mortar_Seasoning::Pepper;
        BuildMortar(InHandle, Spec);

        Add_Step("engage and collect a fresh batch", n"Step_EngageAndCollect");
        Add_Step_WaitUntil("the mortar is engaged", n"Check_Engaged");
        Add_Step("the fresh batch was not collected", n"Step_AssertFreshNotCollected");
        Add_Step_WaitUntil("the window is on the marker", n"Check_WindowDeepOnMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press on the marker and keep holding", n"Step_Press");
        Add_Step_WaitUntil("the batch is done", n"Check_Done");
        Add_Step("a done batch is not tallied before it is collected", n"Step_AssertDoneNotTallied");
        Add_Step("collect twice and release", n"Step_CollectTwiceAndRelease");
        Add_Step_WaitUntil("a fresh batch is in the bowl", n"Check_FreshBatch");
        Add_Step("the tally counts one pepper batch", n"Step_AssertTallied");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_EngageAndCollect(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
        _Mortar.Request_Collect(FMars_Request_Mortar_Collect());
    }

    UFUNCTION()
    private void Step_AssertFreshNotCollected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_Tallied(EMars_Mortar_Seasoning::Salt), 0, "no salt tallied");
        Assert_Equals_Int(Get_Tallied(EMars_Mortar_Seasoning::Pepper), 0, "no pepper tallied");
        Assert_True(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Crush, "the batch is still in the Crush phase");
        Assert_True(_Mortar.Get_Batch().Seasoning == EMars_Mortar_Seasoning::Pepper, "the batch is the start seasoning");
        Assert_Equals_Int(_BatchChanges, 0, "the ignored Collect broadcast no OnBatchChanged");
    }

    UFUNCTION()
    private void Step_AssertDoneNotTallied(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mortar.Get_Batch().Stage == EMars_Mortar_Stage::Ground, "the done batch is Ground");
        Assert_Equals_Int(Get_Tallied(EMars_Mortar_Seasoning::Salt), 0, "no salt tallied before the collect");
        Assert_Equals_Int(Get_Tallied(EMars_Mortar_Seasoning::Pepper), 0, "no pepper tallied before the collect");
        Assert_Equals_Int(_BatchChanges, 2, "the hit and the finished grind each broadcast OnBatchChanged");
    }

    UFUNCTION()
    private void Step_CollectTwiceAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mortar.Request_Collect(FMars_Request_Mortar_Collect());
        _Mortar.Request_Collect(FMars_Request_Mortar_Collect());
        _Mortar.Request_Release(FMars_Request_Mortar_Release());
    }

    UFUNCTION()
    private void Check_FreshBatch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Crush);
    }

    UFUNCTION()
    private void Step_AssertTallied(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_Tallied(EMars_Mortar_Seasoning::Pepper), 1, "two Collects in one drain tallied one pepper batch");
        Assert_Equals_Int(Get_Tallied(EMars_Mortar_Seasoning::Salt), 0, "no salt tallied");
        Assert_Equals_Int(_Mortar.Get_Tally().Counts.Num(), constants_mortar::k_SeasoningCount, "the tally holds one count per seasoning");

        const auto Batch = _Mortar.Get_Batch();
        Assert_True(Batch.Seasoning == EMars_Mortar_Seasoning::Pepper, f"the fresh batch keeps the seasoning ({Batch.Seasoning :n})");
        Assert_True(Batch.Stage == EMars_Mortar_Stage::Coarse, f"the fresh batch is Coarse ({Batch.Stage :n})");
        Assert_Equals_Int(Batch.CrushHits, 0, "the fresh batch has no crush");
        Assert_Equals_Float(Batch.GrindProgress, 0.0f, 0.0f, "the fresh batch has no grind");
        Assert_Equals_Int(_BatchChanges, 3, "the collect broadcast OnBatchChanged once");
        Assert_Equals_Int(_StrikesStarted, 1, "one strike in all");
    }
}
