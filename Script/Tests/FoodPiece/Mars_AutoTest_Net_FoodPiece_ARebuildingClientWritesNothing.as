// The server cuts the meat slab through its centre. Every frame the client samples its pieces at the test's X: none reads
// cutting and none has a Jolt body. Once both halves are built the client asks one for a cut: RefusedNoAuthority, the
// half is still Ready and the client's replay still counts one slice. For the whole test the server's replay memo reads
// all zero and its two halves stay Ready, not cutting, with the masses it reported.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ARebuildingClientWritesNothing
class UCk_AutoTest_Net_FoodPiece_ARebuildingClientWritesNothing : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 178000.0;
    // Past the client's build, its cut and its settle.
    private const float64 k_ServerWatchSeconds = 6.0;
    private const float32 k_ClientSettleSeconds = 1.0f;

    private float64 _WatchStart = 0.0;
    private int32 _Frames = 0;
    private int32 _Violations = 0;
    private FString _FirstViolation;
    private FCk_Handle_FoodPiece _ClientHalf;

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

    private void Record_Violation(FString InText)
    {
        if (_Violations == 0)
        { _FirstViolation = InText; }

        ++_Violations;
    }

    protected void On_ServerSlabStill() override
    {
        Cut(_Rock.As_FoodPiece(), Make_CentrePlane());
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Server();
        auto Result = OutResult;
        Result.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void OnServerCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the cut resolved Cut (got {_Cuts[0].Outcome :n})");
        if (_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut)
        { Publish_PieceReport(Make_CutReport(_CutSources[0], _Cuts[0])); }

        _WatchStart = Get_Now();
        WaitUntil(n"Is_ServerWatched", n"OnServerWatched", k_SlowPolls);
    }

    // The server's memo is empty; once the cut is reported, both halves are Ready, not cutting and of the reported masses.
    private void Sample_Server()
    {
        ++_Frames;
        const auto Tally = Get_Tally();
        if (Tally.Slices != 0 || Tally.Built != 0 || Tally.Failed != 0 || Tally.Lineages != 0 || Tally.Geometries != 0)
        { Record_Violation(f"the server's replay memo is not empty ({Describe_Tally()})"); }

        const auto Report = Get_PieceReport();
        if (Report.Serial < 1)
        { return; }

        Sample_ServerHalf(_Cuts[0].Positive, Report.PositiveMassKg);
        Sample_ServerHalf(_Cuts[0].Negative, Report.NegativeMassKg);
    }

    private void Sample_ServerHalf(FCk_Handle_FoodPiece InHalf, float InMassKg)
    {
        if (InHalf.Get_IsGone())
        {
            Record_Violation("a server half is gone");
            return;
        }

        if (InHalf.Get_Status() != EMars_FoodPiece_Status::Ready || InHalf.Get_IsCutting() || InHalf.Get_MassKg() != InMassKg)
        { Record_Violation(f"a server half reads {InHalf.Get_Status() :n} cutting={InHalf.Get_IsCutting()} mass={InHalf.Get_MassKg()} vs {InMassKg}"); }
    }

    UFUNCTION()
    private void Is_ServerWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Server();
        auto Result = OutResult;
        Result.Set(Get_Now() - _WatchStart >= k_ServerWatchSeconds);
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Violations, 0, f"the server wrote nothing it should not have (first: {_FirstViolation})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"frames={_Frames} violations={_Violations} {Describe_Tally()}");
        End_Server();
    }

    // No piece at the test's X reads cutting or has a Jolt body.
    private void Sample_Client()
    {
        ++_Frames;
        for (auto Entity : Get_PieceEntitiesNear(_FloorTop))
        {
            if (Entity.Is_JoltBody())
            { Record_Violation(f"[{Entity.ToString()}] has a Jolt body on the client"); }

            if (Entity.Is_FoodPiece() && Entity.As_FoodPiece().Get_IsCutting())
            { Record_Violation(f"[{Entity.ToString()}] is cutting on the client"); }
        }
    }

    UFUNCTION()
    private void Is_ClientHalvesBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Client();
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        auto Result = OutResult;
        Result.Set(Pieces.Num() == 2 && Get_AreChecked(Pieces));
    }

    UFUNCTION()
    private void OnClientHalvesBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientHalf = Get_ReadyPiecesNear(_FloorTop)[0];
        Cut(_ClientHalf, Make_CentrePlane());
        _WatchStart = Get_Now();
        WaitUntil(n"Is_ClientSettled", n"OnClientSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Client();
        auto Result = OutResult;
        Result.Set(Get_Now() - _WatchStart >= k_ClientSettleSeconds);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Cuts.Num(), 1, "the client's OnCutResolved fired once");
        const auto Outcome = _Cuts.Num() > 0 ? _Cuts[0].Outcome : EMars_FoodPiece_CutOutcome::Failed;
        Assert_True(Outcome == EMars_FoodPiece_CutOutcome::RefusedNoAuthority, f"the client's cut is RefusedNoAuthority (got {Outcome :n})");
        Assert_True(_ClientHalf.Get_Status() == EMars_FoodPiece_Status::Ready, "the client's half is still Ready");
        Assert_Equals_Int(Get_Tally().Slices, 1, "the client's replay still counts one slice");
        Assert_Equals_Int(_Violations, 0, f"the client wrote nothing (first: {_FirstViolation})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"frames={_Frames} violations={_Violations} outcome={Outcome :n} {Describe_Tally()}");
        End_Client();
    }
}
