// The server cuts the meat slab through its centre. Once the client built both halves its replay memo holds one lineage for
// 3 s. The server then destroys both halves, and inside 5 s of their destruction reaching the client its memo holds no
// lineage and no geometry.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheMemoIsDroppedWhenItsPiecesAreGone
class UCk_AutoTest_Net_FoodPiece_TheMemoIsDroppedWhenItsPiecesAreGone : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 175000.0;
    // Past the client's build and its 3 s watch.
    private const float32 k_ServerKeepSeconds = 6.0f;
    private const float64 k_ClientWatchSeconds = 3.0;
    private const float64 k_DropSeconds = 5.0;

    private float64 _ClientMark = 0.0;
    private int32 _WatchFrames = 0;
    private int32 _FramesNotOneLineage = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientHalvesBuilt", n"OnClientHalvesBuilt", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    protected void On_ServerSlabStill() override
    {
        Cut(_Rock.As_FoodPiece(), Make_CentrePlane());
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void OnServerCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the cut resolved Cut (got {_Cuts[0].Outcome :n})");
        WaitSeconds(k_ServerKeepSeconds, n"OnServerKept");
    }

    UFUNCTION()
    private void OnServerKept(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Result = _Cuts[0];
        if (Result.Outcome == EMars_FoodPiece_CutOutcome::Cut)
        {
            FCk_Handle Positive = Result.Positive;
            FCk_Handle Negative = Result.Negative;
            utils_entity_lifetime::Request_DestroyEntity(Positive);
            utils_entity_lifetime::Request_DestroyEntity(Negative);
        }

        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"outcome={Result.Outcome :n} destroyed both halves {Describe_Tally()}");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientHalvesBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_ReadyPieceCountNear(_FloorTop) == 2);
    }

    UFUNCTION()
    private void OnClientHalvesBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientMark = Get_Now();
        WaitUntil(n"Is_ClientWatched", n"OnClientWatched", k_SlowPolls);
    }

    // Once per frame for 3 s: counts the frames whose memo does not hold exactly one lineage.
    UFUNCTION()
    private void Is_ClientWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_WatchFrames;
        if (Get_Tally().Lineages != 1)
        { ++_FramesNotOneLineage; }

        auto Result = OutResult;
        Result.Set(Get_Now() - _ClientMark >= k_ClientWatchSeconds);
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WatchFrames > 0, "the client watched its memo");
        Assert_Equals_Int(_FramesNotOneLineage, 0, f"the memo held one lineage for {k_ClientWatchSeconds} s ({_WatchFrames} frames)");
        WaitUntil(n"Is_ClientHalvesGone", n"OnClientHalvesGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHalvesGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_PieceEntitiesNear(_FloorTop).Num() == 0);
    }

    UFUNCTION()
    private void OnClientHalvesGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientMark = Get_Now();
        WaitUntil(n"Is_ClientMemoDroppedOrLate", n"OnClientMemoDroppedOrLate", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientMemoDroppedOrLate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Tally = Get_Tally();
        auto Result = OutResult;
        Result.Set((Tally.Lineages == 0 && Tally.Geometries == 0) || Get_Now() - _ClientMark > k_DropSeconds);
    }

    UFUNCTION()
    private void OnClientMemoDroppedOrLate(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Tally = Get_Tally();
        const auto Seconds = Get_Now() - _ClientMark;
        Assert_Equals_Int(Tally.Lineages, 0, f"no lineage inside {k_DropSeconds} s (after {Seconds} s)");
        Assert_Equals_Int(Tally.Geometries, 0, f"no geometry inside {k_DropSeconds} s (after {Seconds} s)");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"watchFrames={_WatchFrames} notOne={_FramesNotOneLineage} droppedAfter={Seconds}s {Describe_Tally()}");
        End_Client();
    }
}
