// The grind fills only while the pestle is held with no strike in flight: the last hit lands with the press still held,
// and through its recover the grind does not start; once the pestle is up it circles and the grind fills. Released, the
// pestle rests and the grind holds its value; held again, the grind finishes, the batch is Ground and Done, and a press in
// the Grind phase never started a strike.
class UMars_AutoTest_Mortar_GrindFillsOnlyWhileHeldAndIdle : UMars_AutoTestRig_Mortar
{
    default _TimeoutSeconds = 15.0f;

    // Long enough for the grind to fill visibly in the released window if it were still running.
    private const float32 k_ReleasedWindowSeconds = 0.5f;

    private int32 _RecoveringPolls = 0;
    private int32 _GrindWhileRecovering = 0;
    private float32 _ProgressAtRelease = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_Spec(1);
        Spec.GrindSeconds = 1.0f;
        Spec.StrikeSeconds = 0.3f;
        BuildMortar(InHandle, Spec);

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the mortar is engaged", n"Check_Engaged");
        Add_Step_WaitUntil("the window is on the marker", n"Check_WindowDeepOnMarker", 0, k_MarkerWaitSeconds);
        Add_Step("press on the marker and keep holding", n"Step_Press");
        Add_Step_WaitUntil("the pestle circles after the recover", n"Check_GrindingAfterRecover");
        Add_Step("the recover held the grind back", n"Step_AssertRecoverHeldTheGrind");
        Add_Step("release", n"Step_Release");
        Add_Step_WaitUntil("the pestle rests", n"Check_Resting");
        Add_Step("the grind stopped part way", n"Step_RecordProgress");
        Add_Step_WaitSeconds("a running grind would move in this window", k_ReleasedWindowSeconds);
        Add_Step("the released grind held its value", n"Step_AssertFrozen");
        Add_Step("hold again", n"Step_Press");
        Add_Step_WaitUntil("the batch is done", n"Check_Done");
        Add_Step("the grind finished the batch", n"Step_AssertGround");
        Run_Steps(InHandle);
    }

    // Counts the polls that saw the recover, and any of them that saw the grind run.
    UFUNCTION()
    private void Check_GrindingAfterRecover(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsGrinding = _Mortar.Get_Pestle() == EMars_Mortar_Pestle::Grinding;
        if (_Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Recovering)
        {
            ++_RecoveringPolls;
            if (IsGrinding || _Mortar.Get_Batch().GrindProgress != 0.0f)
            { ++_GrindWhileRecovering; }
        }

        auto Res = OutResult;
        Res.Set(IsGrinding);
    }

    UFUNCTION()
    private void Step_AssertRecoverHeldTheGrind(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HitsLanded, 1, "the strike landed a Hit");
        Assert_True(_RecoveringPolls > 0, f"the wait saw the recover ({_RecoveringPolls} polls)");
        Assert_Equals_Int(_GrindWhileRecovering, 0, "no poll during the recover saw the pestle circle or the grind move");

        const auto Batch = _Mortar.Get_Batch();
        Assert_True(Batch.Phase == EMars_Mortar_Phase::Grind, f"the hit opened the Grind phase (phase {Batch.Phase :n})");
        Assert_True(Batch.GrindProgress > 0.0f && Batch.GrindProgress < 1.0f, f"the grind has started and not finished ({Batch.GrindProgress})");
        Assert_True(_Mortar.Get_StrikePhase() == EMars_Mortar_StrikePhase::Idle, "the pestle is up while it circles");
    }

    UFUNCTION()
    private void Check_Resting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mortar.Get_Pestle() == EMars_Mortar_Pestle::Resting);
    }

    UFUNCTION()
    private void Step_RecordProgress(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Batch = _Mortar.Get_Batch();
        _ProgressAtRelease = Batch.GrindProgress;
        Assert_True(Batch.Phase == EMars_Mortar_Phase::Grind, f"still grinding when released (phase {Batch.Phase :n})");
        Assert_True(_ProgressAtRelease > 0.0f && _ProgressAtRelease < 1.0f, f"the grind stopped part way ({_ProgressAtRelease})");
    }

    UFUNCTION()
    private void Step_AssertFrozen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Mortar.Get_Batch().GrindProgress, _ProgressAtRelease, 0.0f, "the released grind did not move");
        Assert_True(_Mortar.Get_Pestle() == EMars_Mortar_Pestle::Resting, "the released pestle still rests");
        Assert_True(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Grind, "the batch is still in the Grind phase");
    }

    UFUNCTION()
    private void Step_AssertGround(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Batch = _Mortar.Get_Batch();
        Assert_True(Batch.Stage == EMars_Mortar_Stage::Ground, f"the batch is Ground (stage {Batch.Stage :n})");
        Assert_Equals_Float(Batch.GrindProgress, 1.0f, 0.0f, "the grind is full");
        Assert_Equals_Float(_Mortar.Get_Progress(), 1.0f, 0.0f, "the batch is wholly done");
        Assert_True(_Mortar.Get_Pestle() == EMars_Mortar_Pestle::Resting, "a done batch stops the pestle");
        Assert_Equals_Int(_StrikesStarted, 1, "the press in the Grind phase started no strike");
        Assert_True(_LastBroadcastBatch.Phase == EMars_Mortar_Phase::Done, "the last OnBatchChanged carried Done");
    }
}
