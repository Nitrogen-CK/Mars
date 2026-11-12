// The server cuts a whole meat slab that replicates through its centre. On the client both piece scripts become Ready
// FoodPieces that wear a display, carry a one-cut recipe and the ids the server reported, are not whole, match the
// authority's geometry and have no Jolt body; rebuilding them cost one slice and built two entities, with no failure.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_AClientBuildsBothHalvesOfACut
class UCk_AutoTest_Net_FoodPiece_AClientBuildsBothHalvesOfACut : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 170000.0;
    // Long enough for the client to build and check both halves.
    private const float32 k_ServerWatchSeconds = 6.0f;

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
        const auto Outcome = _Cuts[0].Outcome;
        Assert_True(Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the cut resolved Cut (got {Outcome :n})");
        if (Outcome == EMars_FoodPiece_CutOutcome::Cut)
        { Publish_PieceReport(Make_CutReport(_CutSources[0], _Cuts[0])); }

        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"outcome={Outcome :n} {Describe_Tally()}");
        WaitSeconds(k_ServerWatchSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientHalvesBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        auto Result = OutResult;
        Result.Set(Get_PieceReport().Serial >= 1 && Pieces.Num() == 2 && Get_AreChecked(Pieces));
    }

    UFUNCTION()
    private void OnClientHalvesBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        Assert_Half(Find_ById(Pieces, Report.PositiveId), "positive", Report);
        Assert_Half(Find_ById(Pieces, Report.NegativeId), "negative", Report);

        const auto Tally = Get_Tally();
        Assert_Equals_Int(Tally.Slices, 1, "one replay slice");
        Assert_Equals_Int(Tally.Built, 2, "two entities built");
        Assert_Equals_Int(Tally.Failed, 0, "no replay failed");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Pieces.Num()} matches={Get_CheckCount(Pieces, EMars_FoodPiece_CheckResult::Matches)} {Describe_Tally()}");
        End_Client();
    }

    private void Assert_Half(FCk_Handle_FoodPiece InPiece, FString InName, FMars_Fragment_TESTONLY_NetFoodPieceReport InReport)
    {
        FCk_Handle Entity = InPiece;
        Assert_True(ck::IsValid(Entity), f"the client's {InName} half is a Ready FoodPiece with the reported id");
        if (ck::Is_NOT_Valid(Entity))
        { return; }

        Assert_True(Entity.Is_RuntimeMeshDisplay(), f"the {InName} half wears a display");
        Assert_Equals_Int(InPiece.Get_Recipe().Cuts.Num(), 1, f"the {InName} half has a one-cut recipe");
        Assert_True(InPiece.Get_ParentId() == InReport.SourceId, f"the {InName} half names the source");
        Assert_True(InPiece.Get_Lineage() == InReport.Lineage, f"the {InName} half keeps the lineage");
        Assert_False(InPiece.Get_IsWhole(), f"the {InName} half is not whole");
        Assert_True(InPiece.Get_CheckResult() == EMars_FoodPiece_CheckResult::Matches, f"the {InName} half matches the authority (got {InPiece.Get_CheckResult() :n})");
        Assert_False(Entity.Is_JoltBody(), f"the {InName} half has no Jolt body");
    }
}
