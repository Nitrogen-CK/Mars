// The server slices the meat slab's geometry by hand through its centre, slices the positive result again at height 6 cm
// (normal +Z), and spawns only the two pieces of that second slice, each with a two-cut recipe; their parent never exists
// on any machine. On the client both become Ready FoodPieces that match the authority's geometry, rebuilt with two slices.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_APieceWhoseAncestorsNeverArrivedIsRebuilt
class UCk_AutoTest_Net_FoodPiece_APieceWhoseAncestorsNeverArrivedIsRebuilt : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 172000.0;
    private const float32 k_ServerWatchSeconds = 6.0f;

    private FMars_FoodPiece_Spec _SlabSpec;
    private FCk_Handle _Positive;
    private FCk_Handle _Negative;
    private int32 _ServerSettleFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientPiecesBuilt", n"OnClientPiecesBuilt", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    private FCk_RuntimeMesh_PlaneLocal Make_SecondPlane()
    {
        return Make_Plane(FVector(0.0, 0.0, 6.0), FVector::UpVector, FVector::ForwardVector);
    }

    protected void On_ServerSlabStill() override
    {
        auto Slab = _Rock.As_FoodPiece();
        _SlabSpec = Make_SourceSpec(Slab);
        Slice_ByHand(Slab.Get_Geometry(), Make_CentrePlane(), Slab.Get_Cap());
        WaitUntil(n"Is_ServerFirstSliced", n"OnServerFirstSliced", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFirstSliced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ByHandSlices.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerFirstSliced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto First = _ByHandSlices[0];
        Assert_True(First.Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded, f"the first slice succeeded (got {First.Get_Outcome() :n})");
        if (First.Get_Outcome() != ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
            return;
        }

        Slice_ByHand(First.Get_Positive(), Make_SecondPlane(), _SlabSpec.Cap);
        WaitUntil(n"Is_ServerSecondSliced", n"OnServerSecondSliced", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSecondSliced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ByHandSlices.Num() >= 2);
    }

    UFUNCTION()
    private void OnServerSecondSliced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto First = _ByHandSlices[0];
        const auto Second = _ByHandSlices[1];
        Assert_True(Second.Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded, f"the second slice succeeded (got {Second.Get_Outcome() :n})");
        if (Second.Get_Outcome() != ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
            return;
        }

        // The never-spawned parent: the first slice's positive side.
        const auto Parent = Make_ByHandBirth(_SlabSpec, First, FMars_FoodPiece_RecipeCut(Make_CentrePlane(), EMars_FoodPiece_CutSide::Positive)).Spec;
        _Positive = Spawn_ByHand(Make_ByHandBirth(Parent, Second, FMars_FoodPiece_RecipeCut(Make_SecondPlane(), EMars_FoodPiece_CutSide::Positive)));
        _Negative = Spawn_ByHand(Make_ByHandBirth(Parent, Second, FMars_FoodPiece_RecipeCut(Make_SecondPlane(), EMars_FoodPiece_CutSide::Negative)));

        utils_entity_lifetime::Request_DestroyEntity(First.Get_Positive());
        utils_entity_lifetime::Request_DestroyEntity(First.Get_Negative());
        WaitUntil(n"Is_ServerPiecesReady", n"OnServerPiecesReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPiecesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_ReadyPieceCountNear(_FloorTop) == 2);
    }

    UFUNCTION()
    private void OnServerPiecesReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Report = Get_PieceReport();
        Report.PositiveId = _Positive.As_FoodPiece().Get_Id();
        Report.NegativeId = _Negative.As_FoodPiece().Get_Id();
        Publish_PieceReport(Report);

        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Get_ReadyPieceCountNear(_FloorTop)} cuts={_Positive.As_FoodPiece().Get_Recipe().Cuts.Num()} {Describe_Tally()}");
        WaitSeconds(k_ServerWatchSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientPiecesBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Report = Get_PieceReport();
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        auto Result = OutResult;
        Result.Set(Report.Serial >= 1 && ck::IsValid(Find_ById(Pieces, Report.PositiveId)) && ck::IsValid(Find_ById(Pieces, Report.NegativeId))
            && Get_AreChecked(Pieces));
    }

    UFUNCTION()
    private void OnClientPiecesBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Pieces = Get_ReadyPiecesNear(_FloorTop);
        Assert_Equals_Int(Pieces.Num(), 2, "two Ready pieces on the client");
        Assert_Equals_Int(Get_CheckCount(Pieces, EMars_FoodPiece_CheckResult::Matches), 2, "both match the authority");
        for (const auto& Piece : Pieces)
        { Assert_Equals_Int(Piece.Get_Recipe().Cuts.Num(), 2, "each carries a two-cut recipe"); }

        const auto Tally = Get_Tally();
        Assert_Equals_Int(Tally.Slices, 2, "two replay slices");
        Assert_Equals_Int(Tally.Failed, 0, "no replay failed");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Pieces.Num()} matches={Get_CheckCount(Pieces, EMars_FoodPiece_CheckResult::Matches)} {Describe_Tally()}");
        End_Client();
    }
}
