// The server cuts a whole meat slab through its centre and, 3 s later, cuts the negative half at position (-9, 0, 0),
// normal +X. On the client the second cut's two pieces become Ready FoodPieces that match the authority's geometry; the
// whole rebuild cost two slices and built four entities (the first cut's two halves and the second's).
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ACutOfACutCostsOneMoreSlice
class UCk_AutoTest_Net_FoodPiece_ACutOfACutCostsOneMoreSlice : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 171000.0;
    private const float32 k_BetweenCutsSeconds = 3.0f;
    private const float32 k_ServerWatchSeconds = 6.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientSecondCutBuilt", n"OnClientSecondCutBuilt", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    protected void On_ServerSlabStill() override
    {
        Cut(_Rock.As_FoodPiece(), Make_CentrePlane());
        WaitUntil(n"Is_ServerFirstCutResolved", n"OnServerFirstCutResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFirstCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerFirstCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the first cut resolved Cut (got {_Cuts[0].Outcome :n})");
        if (_Cuts[0].Outcome != EMars_FoodPiece_CutOutcome::Cut)
        {
            WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
            return;
        }

        WaitSeconds(k_BetweenCutsSeconds, n"OnServerSecondCutDue");
    }

    UFUNCTION()
    private void OnServerSecondCutDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cut(_Cuts[0].Negative, Make_Plane(FVector(-9.0, 0.0, 0.0), FVector::ForwardVector, FVector::RightVector));
        WaitUntil(n"Is_ServerSecondCutResolved", n"OnServerSecondCutResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSecondCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() >= 2);
    }

    UFUNCTION()
    private void OnServerSecondCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Outcome = _Cuts[1].Outcome;
        Assert_True(Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the second cut resolved Cut (got {Outcome :n})");
        if (Outcome == EMars_FoodPiece_CutOutcome::Cut)
        { Publish_PieceReport(Make_CutReport(_CutSources[1], _Cuts[1])); }

        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"cuts={_Cuts.Num()} second={Outcome :n} {Describe_Tally()}");
        WaitSeconds(k_ServerWatchSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientSecondCutBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Report = Get_PieceReport();
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        const auto Positive = Find_ById(Pieces, Report.PositiveId);
        const auto Negative = Find_ById(Pieces, Report.NegativeId);
        auto Result = OutResult;
        Result.Set(Report.Serial >= 1 && ck::IsValid(Positive) && ck::IsValid(Negative) && Get_AreChecked(Pieces));
    }

    UFUNCTION()
    private void OnClientSecondCutBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_PieceReport();
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        const auto Positive = Find_ById(Pieces, Report.PositiveId);
        const auto Negative = Find_ById(Pieces, Report.NegativeId);
        Assert_True(Positive.Get_CheckResult() == EMars_FoodPiece_CheckResult::Matches, f"the second cut's positive piece matches (got {Positive.Get_CheckResult() :n})");
        Assert_True(Negative.Get_CheckResult() == EMars_FoodPiece_CheckResult::Matches, f"the second cut's negative piece matches (got {Negative.Get_CheckResult() :n})");
        Assert_Equals_Int(Positive.Get_Recipe().Cuts.Num(), 2, "the second cut's pieces carry two-cut recipes");

        const auto Tally = Get_Tally();
        Assert_Equals_Int(Tally.Slices, 2, "two replay slices");
        Assert_Equals_Int(Tally.Built, 4, "four entities built");
        Assert_Equals_Int(Tally.Failed, 0, "no replay failed");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Pieces.Num()} {Describe_Tally()}");
        End_Client();
    }
}
