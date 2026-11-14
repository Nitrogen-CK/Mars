// The client pulls its copy of a replicated turnip bed past the break: its own stretch rises while no engagement has
// come back, its interaction ends Succeeded, the authority engages the bed's Control once and releases one Plucked root;
// both machines read the bed exhausted with one release, one root lies near the bed, and the client's target is claimed.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_AClientsPullReleasesOneRootOnBothMachines
class UCk_AutoTest_Net_ScreamingTurnip_AClientsPullReleasesOneRootOnBothMachines : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(400000.0, 0.0, 5000.0);
    private const float32 k_PullTo = 1.25f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BedFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_Pull();
        WaitUntil(n"Is_Manipulating", n"OnClientGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Walk_To(k_PullTo);
        WaitUntil(n"Is_PulledUntilItEnds", n"OnClientPullEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientPullEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_HarvestedWithARoot", n"OnClientHarvested", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_HarvestedWithARoot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Forage.Get_IsExhausted() && Count_RootsNearBed() >= 1);
    }

    UFUNCTION()
    private void OnClientHarvested(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Frames = _ThresholdFrame >= 0 && _ReleasedFrame >= 0 ? _ReleasedFrame - _ThresholdFrame : int64(-1);
        const auto Result = _FinishedResults.Num() > 0 ? _FinishedResults[0] : ECk_SucceededFailed::Failed;
        Log(f"[TurnipNetTest] AClientsPullReleasesOneRootOnBothMachines client: maxStretchBeforeEngage {_MaxStretchBeforeEngage :.3}, finished {Result :n}, thresholdToReleasedFrames {Frames}, {Get_BedText()}");
        Assert_True(_MaxStretchBeforeEngage > 0.9f, f"the client's own stretch rose while no engagement had come back (got {_MaxStretchBeforeEngage})");
        Assert_True(_FinishedResults.Num() == 1 && Result == ECk_SucceededFailed::Succeeded,
            f"the client's interaction ended Succeeded once (got {_FinishedResults.Num()}, {Result :n})");
        Assert_True(_Forage.Get_IsExhausted() && _Forage.Get_ReleasedCount() == 1, f"the client reads the bed exhausted after one release (got {_Forage.Get_ReleasedCount()})");
        Assert_True(_ReleaseReasons.Num() == 1, f"the client raised OnReleased once (got {_ReleaseReasons.Num()})");
        Assert_True(_ExhaustedCount == 1, f"the client raised OnExhausted once (got {_ExhaustedCount})");
        Assert_True(_Interactable.Get_IsDisabledFor(EMars_Interactable_DisableReason::Exhausted), "the client's target is claimed for Exhausted");
        Assert_True(Count_RootsNearBed() == 1, f"one root lies near the client's bed (got {Count_RootsNearBed()})");
        Assert_False(_Control.Get_IsManipulating(), "the client is not manipulating");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBed();
        WaitUntil(n"Is_BedFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Harvested", n"OnServerHarvested", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHarvested(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] AClientsPullReleasesOneRootOnBothMachines server: {Get_BedText()}");
        Assert_True(_Forage.Get_ReleasedCount() == 1, f"the server released one root (got {_Forage.Get_ReleasedCount()})");
        Assert_True(_ReleaseReasons.Num() == 1 && _ReleaseReasons[0] == EMars_Forage_ReleaseReason::Plucked,
            f"the server raised OnReleased once, Plucked (got [{Get_ReleaseReasonsText()}])");
        Assert_True(Get_Engagements() == 1, f"the bed's Control engaged once (got {Get_Engagements()})");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::Crossed,
            f"the grip was released Crossed (got {_Control.Get_LastGripRelease() :n})");
        Assert_True(Count_RootsNearBed() == 1, f"one root lies near the server's bed (got {Count_RootsNearBed()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
