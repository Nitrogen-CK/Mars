// The server cuts a whole meat slab that replicates. Inside its OnCutResolved: the outcome is Cut, both halves are Ready
// FoodPieces with a Ready RuntimeMesh, a transform and a replication driver, owned by the replicated spawn owner, of the
// source's lineage with the source as parent, their masses summing to the source's; the source is still live. A frame
// later the source is gone and both halves wear a display. The client gets two piece scripts near the test's X, neither a
// FoodPiece, and no world item is left there.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ACutMakesTwoReplicatedPieces
class UCk_AutoTest_Net_FoodPiece_ACutMakesTwoReplicatedPieces : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 150000.0;

    private FCk_Handle_FoodPiece _Source;
    private FGuid _SourceId;
    private FGuid _SourceLineage;
    private float _SourceMassKg = 0.0;
    private FMars_FoodPiece_CutResult _Result;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientHalvesThere", n"OnClientHalvesThere", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSlab();
        WaitUntil(n"Is_ServerSlabStill", n"OnServerSlabStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Tick_SlabReadyAndStill());
    }

    UFUNCTION()
    private void OnServerSlabStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Source = _Rock.As_FoodPiece();
        _SourceId = _Source.Get_Id();
        _SourceLineage = _Source.Get_Lineage();
        _SourceMassKg = _Source.Get_MassKg();
        Cut(_Source, Make_CentrePlane());
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
    }

    protected void On_CutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult) override
    {
        _Result = InResult;
        Assert_True(InResult.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the cut resolved Cut (got {InResult.Outcome :n})");
        if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        Assert_False(InSource.Get_IsGone(), "the source is still live inside the broadcast");
        Assert_Half(InResult.Positive, "positive");
        Assert_Half(InResult.Negative, "negative");
        Assert_True(Math::Abs(InResult.Positive.Get_MassKg() + InResult.Negative.Get_MassKg() - _SourceMassKg) <= 0.000000001,
            f"the halves' masses sum to the source's ({InResult.Positive.Get_MassKg()} + {InResult.Negative.Get_MassKg()} vs {_SourceMassKg})");
    }

    private void Assert_Half(FCk_Handle_FoodPiece InHalf, FString InName)
    {
        FCk_Handle Entity = InHalf;
        Assert_True(ck::IsValid(Entity) && Entity.Is_FoodPiece(), f"the {InName} half is a FoodPiece");
        if (ck::Is_NOT_Valid(Entity) || Entity.Is_FoodPiece() == false)
        { return; }

        Assert_True(InHalf.Get_Status() == EMars_FoodPiece_Status::Ready, f"the {InName} half is Ready");
        Assert_True(utils_runtime_mesh::Get_SetupState(InHalf.Get_Geometry()) == ECk_RuntimeMesh_SetupState::Ready, f"the {InName} half's geometry is Ready");
        Assert_True(Entity.Is_Transform(), f"the {InName} half has a transform");
        Assert_True(utils_entity_replication_driver::Has(Entity), f"the {InName} half has a replication driver");
        Assert_True(InHalf.Get_ParentId() == _SourceId, f"the {InName} half was cut from the source");
        Assert_True(InHalf.Get_Lineage() == _SourceLineage, f"the {InName} half keeps the source's lineage");
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(Entity);
        Assert_True(Owner == utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()), f"the {InName} half's lifetime owner is the replicated spawn owner");
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
        WaitFrames(1, n"OnServerFrameAfterCut");
    }

    UFUNCTION()
    private void OnServerFrameAfterCut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Cuts.Num(), 1, "one OnCutResolved");
        Assert_True(_Source.Get_IsGone(), "the source is gone a frame after the cut");
        FCk_Handle Positive = _Result.Positive;
        FCk_Handle Negative = _Result.Negative;
        const auto PositiveShown = ck::IsValid(Positive) && Positive.Is_RuntimeMeshDisplay();
        const auto NegativeShown = ck::IsValid(Negative) && Negative.Is_RuntimeMeshDisplay();
        Assert_True(PositiveShown && NegativeShown, "both halves wear a display");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"outcome={_Result.Outcome :n} cuts={_Cuts.Num()} sourceGone={_Source.Get_IsGone()} shown={PositiveShown},{NegativeShown}");
        WaitSeconds(3.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientHalvesThere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_PieceEntitiesNear(_FloorTop).Num() == 2 && Get_WorldItemCountNear(_FloorTop) == 0);
    }

    UFUNCTION()
    private void OnClientHalvesThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Pieces = Get_PieceEntitiesNear(_FloorTop);
        auto FoodPieces = 0;
        for (const auto& Piece : Pieces)
        {
            if (Piece.Is_FoodPiece())
            { ++FoodPieces; }
        }

        Assert_Equals_Int(Pieces.Num(), 2, "two piece scripts near the test's X");
        Assert_Equals_Int(FoodPieces, 0, "neither is a FoodPiece on the client");
        Assert_Equals_Int(Get_WorldItemCountNear(_FloorTop), 0, "no world item is left near the test's X");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Pieces.Num()} foodPieces={FoodPieces} worldItems={Get_WorldItemCountNear(_FloorTop)}");
        FinishSuccess();
    }
}
